import os
import nibabel as nib

## ######### ART PARAMETERS (edit to desired values) ############
global_mean=1      # global mean type (1: Standard 2: User-defined Mask)
motion_file_type=0 # motion file type (0: SPM .txt file 1: FSL .par file 2:Siemens .txt file)
use_diff_motion=1  # 1: uses scan-to-scan motion to determine outliers; 0: uses absolute motion
use_diff_global=1  # 1: uses scan-to-scan global signal change to determine outliers; 0: uses absolute global signal values
use_norms=0        # 1: uses composite motion measure (largest voxel movement) to determine outliers; 0: uses raw motion measures (translation/rotation parameters)
#mask_file=[]      # set to user-defined mask file(s) for global signal estimation (if global_mean is set to 2)
##################################################################

subject = snakemake.wildcards.sub
func = snakemake.input.swutFunc
rp = snakemake.input.rpTxt
#SPM = snakemake.input.SPM
cfgPath = snakemake.output.artCfg

if type(func) is str:
    nSes = 1
    imgPath = func
    rpPath = rp
else:
    func = str(func).split(" ")
    nSes = len(func)
    imgPath = func[0]
    rpPath = rp[0]

#write config file
with open(cfgPath,'w') as cfg:
    cfg.write('# Automatic script created through snakemake\n')
    cfg.write('# art config scripts can be edited and ran manually through\n')
    cfg.write('# the art toolbox in matlab with the following syntax:\n')
    cfg.write("# art('sess_file',cfgPath)\n\n")
    cfg.write(f'sessions: {nSes}\n')
    cfg.write(f'global_mean: {global_mean}\n')
    cfg.write(f'motion_file_type: {motion_file_type}\n')
    cfg.write('motion_fname_from_image_fname: 0\n')
    cfg.write(f'use_diff_motion: {use_diff_motion}\n')
    cfg.write(f'use_diff_global: {use_diff_global}\n')
    cfg.write(f'use_norms: {use_norms}\n')
    cfg.write(f'output_dir: {os.path.dirname(imgPath)}\n\n')
    #cfg.write(f'spm_file: {SPM}\n')
    cfg.write('end\n')

    #session specific stuff
    for i in range(nSes):
        if type(func) is str:
            imgPath = func
            rpPath = rp
        else:
            imgPath = func[i]
            rpPath = rp[i]

        img = nib.load(imgPath) #get nVols

        nVols = img.shape[3]
        sess = ''
        for j in range(1,nVols+1): #initialize loop 1-nVols (matlab indices start at 1, not 0)
            sess += f'session {i+1} image {imgPath+","+str(j)+" "}'
        cfg.write(sess+'\n\n')

    for i in range(nSes):
        cfg.write(f'session {i+1} motion {rpPath}\n')

    cfg.write('end\n')
