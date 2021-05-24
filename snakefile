#tell it to not submit rule all to a cluster node

localrules: all, getRawFunc, getRawT1w, getRawFmap, getRawFmapMag, makeArtConfig
configfile: 'config/sm_config.json'

# pseudo rule to tell snakemake what we want the final product to be
rule all:
    input:
        expand(config['bids_dir']+'/sub-{sub}/ses-{ses}/func/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_events.tsv',
            sub=config['sub'],ses=config['ses'],task=config['task'],acq=config['acq'],run=config['run']),
        expand('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/chT1w.nii',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq'],run=config['run']),
        expand('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/swutbold.nii',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq'],run=config['run']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/residuals.nii.gz',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq']),
        expand('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_utboldref.nii.gz',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq'],run=config['run']),
        expand('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_wutboldref.nii.gz',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq'],run=config['run']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/rwholeBrain_wfupickatlas.txt',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/rfrontalLobe.txt',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/GM_PFC_mask.txt',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/rjuly_bilat_vs_duke.txt',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/GM_VS_mask.txt',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq']),
	expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/AAL_BiAmy_PickAtlas.txt',
	    task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq'])


# STEP 1 - COPY INPUT FILES
rule getRawFunc:
    input:
        rawFunc = config['bids_dir']+'/sub-{sub}/ses-{ses}/func/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_bold.nii.gz'
    output:
        func = temp('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/bold.nii')
    shell:
        'gunzip -c {input} > {output}'

ruleorder: getRawT1w > getRawT1wOverlay

rule getRawT1w:
    input:
        RawT1w = config['bids_dir']+'/sub-{sub}/ses-{ses}/anat/sub-{sub}_ses-{ses}_acq-highres_T1w.nii.gz'
    output:
        tmpT1w = temp('tmp/sub-{sub}/ses-{ses}/T1w.nii')
    shell:
        'gunzip -c {input.RawT1w} > {output.tmpT1w}'

# in our study, there are a couple subjects that don't have a high resolution
# T1w image. We've found though that for this pipeline the T1w overlay is
# sufficient for the purposes of normalization
rule getRawT1wOverlay:
    input:
        RawT1wOverlay = config['bids_dir'] + '/sub-{sub}/ses-{ses}/anat/sub-{sub}_ses-{ses}_acq-overlay_T1w.nii.gz'
    output:
        tmpT1w = temp('tmp/sub-{sub}/ses-{ses}/T1w.nii')
    shell:
        'gunzip -c {input.RawT1wOverlay} > {output.tmpT1w}'

rule getRawFmap:
    input:
        RawFmap = config['bids_dir']+'/sub-{sub}/ses-{ses}/fmap/sub-{sub}_ses-{ses}_acq-{task}_run-1_fieldmap.nii.gz'
    output:
        Fmap = temp('data/{task}/preproc/acq-mb/sub-{sub}/ses-{ses}/fmap.nii')
    shell:
        'gunzip -c {input.RawFmap} > {output.Fmap}'

rule getRawFmapMag:
    input:
        RawFmapMag = config['bids_dir']+'/sub-{sub}/ses-{ses}/fmap/sub-{sub}_ses-{ses}_acq-{task}_run-1_magnitude.nii.gz'
    output:
        FmapMag = temp('data/{task}/preproc/acq-mb/sub-{sub}/ses-{ses}/fmapMag.nii')
    shell:
        'gunzip -c {input} > {output}'

################################################################################
########################### PREPROCESSING RULES ################################
################################################################################
#strip skull from fieldmap magnitude image using FSL's BET
rule skullstripFmapMag:
    input:
        FmapMag = 'data/{task}/preproc/acq-mb/sub-{sub}/ses-{ses}/fmapMag.nii'
    output:
        eFmapMag = 'data/{task}/preproc/acq-mb/sub-{sub}/ses-{ses}/eFmapMag.nii'
    shell:
        '''
        FSLOUTPUTTYPE=NIFTI
        bet {input}  {output}
        '''

rule hCorr:
    input:
        t1w = 'tmp/sub-{sub}/ses-{ses}/T1w.nii',
        reoriented = '../../reorientation/sub-{sub}/ses-{ses}/T1w_reorient.mat'
    output:
        hT1w = temp('tmp/sub-{sub}/ses-{ses}/hT1w.nii')
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin/; addpath {config[spm_dir]};
        hCorr('{input.t1w}','{output.hT1w}'); exit;"
        '''.replace('\n','')

#make comments! :)
rule makeVDM:
    input:
        fmap = 'data/{task}/preproc/acq-mb/sub-{sub}/ses-{ses}/fmap.nii',
        eFmapMag = 'data/{task}/preproc/acq-mb/sub-{sub}/ses-{ses}/eFmapMag.nii',
        func = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-1/bold.nii'
    output:
        VDM='data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/vdm5_fmap.nii'
    shell:
        '''
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/preproc_spm_fieldmap.m {input.fmap} {input.eFmapMag} {input.func}
        '''

rule slicetime:
    input:
        func = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/bold.nii',
        json = config['bids_dir']+'/task-{task}_acq-{acq}_bold.json',
        reoriented = '../../reorientation/sub-{sub}/ses-{ses}/T1w_reorient.mat'
    output:
        tFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/tbold.nii'
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        preproc_spm_slicetime('inFunc','{input.func}','outFile','$tmpJob', \
        'bidsConfig', '{input.json}'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        rm $tmpJob
        '''

# in our pipeline, we realign to the 10th volume. SPM has two settings for which image to
# realign to - either a computed mean image, or the first volume specified in the array.
# So we can realign to the 10th volume by just reordering the volumes and making a new file
# Then we can switch back the realign output!
rule prepRealign:
    input:
        refFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/bold.nii',
        tFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/tbold.nii'
    output:
        tmpTFunc = temp('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/tmp_tbold.nii')
    shell:
        '''
        if [ -e {input.tFunc}.gz ]; then rm {input.tFunc}.gz; fi
        FSLOUTPUTTYPE=NIFTI
        funcPath=$(dirname "{input.tFunc}")
        refVol=$funcPath/tmpRefVol_{wildcards.run}
        echo "extracting 10th volume from reference functional..."
        fslroi {input.refFunc} $refVol 9 1 #align to raw 10th volume
        tmpStr=$funcPath/tmp_tFunc_{wildcards.run}_vol_
        echo "appending 10th volume to temporary functional nifti..."
        fslsplit {input.tFunc} $tmpStr -t
        fslmerge -t {output.tmpTFunc} $refVol $tmpStr*
        rm $refVol* $tmpStr*
        '''


# SPM realignment can simultaneously unwarp if a fieldmap is present, which
# reduces acquisition bias. If there is no available fieldmap (which is the case
# for the spiral acquisition subjects of MTwiNS), we'll just realign. Because
# both rules would be producing the same output files, we need the ruleorder
# declaration to tell snakemake to prioritize using the fieldmap version, in
# order to avoid rule ambiguity.

ruleorder: realignUnwarp > realign

rule realignUnwarp:
    input:
        tmpTFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/tmp_tbold.nii',
        VDM = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/vdm5_fmap.nii'
    output:
        tmpUtFunc = temp('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/utmp_tbold.nii'),
        tmpRpTxt = temp('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/rp_tmp_tbold.txt')
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        preproc_spm_realignunwarp('inFunc', '{input.tmpTFunc}', 'inVDM', '{input.VDM}', \
        'outFile', '$tmpJob'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        rm $tmpJob
        '''

rule realign:
    input:
        tmpTFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/tmp_tbold.nii',
    output:
        tmpUtFunc = temp('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/utmp_tbold.nii'),
        tmpRpTxt = temp('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/rp_tmp_tbold.txt')
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        preproc_spm_realign('inFunc', '{input.tmpTFunc}','outFile', '$tmpJob'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        rm $tmpJob
        '''

rule cleanRealign:
    input:
        tmpUtFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/utmp_tbold.nii',
        tmpRpTxt = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/rp_tmp_tbold.txt'
    output:
        utFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/utbold.nii',
        rpTxt = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/rp_tbold.txt'
    shell:
        '''
        FSLOUTPUTTYPE=NIFTI
        fslroi {input.tmpUtFunc} {output.utFunc} 1 -1
        sed -e "1d" {input.tmpRpTxt} > {output.rpTxt}
        '''

rule coregister:
    input:
        utFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/utbold.nii',
        hT1w = 'tmp/sub-{sub}/ses-{ses}/hT1w.nii'
    output:
        chT1w = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/chT1w.nii',
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        cp {input.hT1w} {output.chT1w}
        preTime=$(stat -c %y {output.chT1w})
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        preproc_spm_coregister('refImg', '{input.utFunc},10', 'srcImg', '{output.chT1w}', \
        'outFile', '$tmpJob'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        postTime=$(stat -c %y {output.chT1w})
        if [[ "$preTime" == "$postTime" ]]; then
            rm {output.chT1w}
        fi
        rm $tmpJob
        '''

rule normalize:
    input:
        utFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/utbold.nii',
        chT1w = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/chT1w.nii',
        TPM = 'lib/tpm/SPM_TPM.nii'
    output:
        wutFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/wutbold.nii',
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        preproc_spm_normalize('inFunc', '{input.utFunc}', 'inStruct', '{input.chT1w}', \
        'TPM', '{input.TPM}', 'outFile', '$tmpJob'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        rm $tmpJob
        '''

rule smooth:
    input:
        wutFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/wutbold.nii',
    output:
        swutFunc = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/swutbold.nii',
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        preproc_spm_smooth('inFunc', '{input.wutFunc}', 'outFile', '$tmpJob'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        rm $tmpJob
        '''

# ART (Artifact Detection Tools) - prepare a .cfg file for getting movement outliers
rule makeArtConfig:
    input:
        swutFunc = expand('data/{{task}}/preproc/acq-{{acq}}/sub-{{sub}}/ses-{{ses}}/run-{run}/swutbold.nii',
            run=config['run']),
        rpTxt = expand('data/{{task}}/preproc/acq-{{acq}}/sub-{{sub}}/ses-{{ses}}/run-{run}/rp_tbold.txt',
            run=config['run'])
    output:
        artCfg = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/art.cfg'
    script:
        './bin/preproc_art_mkconfig.py'

rule ART:
    input:
        artCfg = 'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/art.cfg'
    output:
        art = expand('data/{{task}}/preproc/acq-{{acq}}/sub-{{sub}}/ses-{{ses}}/run-{run}/art_regression_outliers_swutbold.mat',
            run=config['run'])
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin/; addpath
        $PWD/lib/art; addpath {config[spm_dir]};
        preproc_art_run('{input.artCfg}'); exit;"
        '''.replace('\n','')

################################################################################
###################### SUBJECT LEVEL (L1) ANALYSIS RULES #######################
################################################################################

#PREPARE EVENTS.TSV

# the MTwiNS projects have some subjects whose source behavioral data was
# conducted in EPRIME, resulting in exported csv's. The project made a switch
# to psychtoolbox, with matlab structure output. The two rules below do that for us.

# It's typical to want to create these events.tsv files while setting up the bids
# structure and before doing any of this processing stuff. However, there are
# some different use cases where we may specify events slightly differently for
# a given pipeline. For example, when regressing out task effects to "turn" task
# data into resting data, we would much more stringently model all events, as
# opposed to doing a standard analysis. In order to keep just one version of the
# bids directory, we have each pipeline create its own bids.tsv file with the
# appropriate events in it.

# These two rules are the only ones that are project specific. As such, the
# extract_events.m and extract_events.py scripts would need to be edited for each
# project.

# If you already have events.tsv in your BIDS data set, then you can simply remove
# these two rules.

ruleorder: mat2tsv > csv2tsv

rule mat2tsv:
    input:
        eventMAT = '../../eventLogs/sub-{sub}/ses-{ses}/sub-{sub}_ses-{ses}_run-{run}_{task}.mat'
    output:
        eventTSV = config['bids_dir']+'/sub-{sub}/ses-{ses}/func/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_events.tsv'
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath ../../bin; addpath {config[spm_dir]};
        extract_events('{input}', '{output.eventTSV}', '{wildcards.task}', 1); exit"
        '''.replace('\n','')

rule csv2tsv:
    input:
        eventCSV = '../../eventLogs/sub-{sub}/ses-{ses}/sub-{sub}_ses-{ses}_run-{run}_{task}.csv'
    output:
        eventTSV = config['bids_dir']+'/sub-{sub}/ses-{ses}/func/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_events.tsv'
    script:
        './bin/mtwins_csv2bids.py'

#Now we begin creating Level 1s. Run wildcard is no longer used bc we created a
#run variable combining our multiple runs.

rule modelspec:
    input:
        swutFunc = expand('data/{{task}}/preproc/acq-{{acq}}/sub-{{sub}}/ses-{{ses}}/run-{run}/swutbold.nii',
            run=config['run']),
        eventTSV = expand(config['bids_dir']+'/sub-{{sub}}/ses-{{ses}}/func/sub-{{sub}}_ses-{{ses}}_task-{{task}}_acq-{{acq}}_run-{run}_events.tsv',
            run=config['run']),
        art = expand('data/{{task}}/preproc/acq-{{acq}}/sub-{{sub}}/ses-{{ses}}/run-{run}/art_regression_outliers_swutbold.mat',
            run=config['run']),
        bidsCfg = config['bids_dir']+'/task-{task}_acq-{acq}_bold.json'
    output:
        SPM = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/SPM.mat'
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        L1_spm_modelspec('inFunc','{input.swutFunc}','inEvent','{input.eventTSV}', \
        'inReg','{input.art}','L1Dir','$(dirname {output.SPM})', 'outFile', \
        '$tmpJob', 'bidsConfig','{input.bidsCfg}'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        rm $tmpJob
        '''

rule modelest:
    input:
        SPM = ancient('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/SPM.mat')
    output:
        beta = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/beta_0001.nii',
        res = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/Res_0001.nii'
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        L1_spm_modelest('SPM','{input.SPM}','outFile','$tmpJob'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        rm $tmpJob
        '''

rule concatResiduals:
    input:
        'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/Res_0001.nii'
    output:
        'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/residuals.nii.gz'
    shell:
        '''
        FSLOUTPUTTYPE=NIFTI_GZ
        resDir=$(dirname "{input}")
        fslmerge  -t {output} $resDir/Res_*.nii
        rm $resDir/Res_*.nii
        '''

rule modelcontrasts:
    input:
        SPM = ancient('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/SPM.mat'),
        beta = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/beta_0001.nii'
    output:
        con = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii'
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        L1_spm_modelcon('SPM','{input.SPM}', 'task', '{wildcards.task}','outFile','$tmpJob'); exit;"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        #rm "$tmpJob"
        '''

################################################################################
##########################CCOVERAGE CHECKING RULES #############################
################################################################################

# these rules produce text output with coverage information for certain regions
# of interest in our lab. Making a new coverage check should be as simple as
# placing the mask file in the directory specified in ./config/sm_config.json,
# updating the mask and output filepaths, and adding the output to rule all

rule wholeBrainCov:
    input:
        con = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii',
        mask = config['mask_dir'] + '/rwholeBrain_wfupickatlas.nii'
    output:
        'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/rwholeBrain_wfupickatlas.txt'
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin/; addpath
        $PWD/{config[spm_dir]}; batch_check_coverage('{input.con}',
        '{input.mask}','$(dirname {output})'); exit;"
        '''.replace('\n','')

rule frontalLobeCov:
    input:
        con = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii',
        mask = config['mask_dir'] + '/rfrontalLobe.nii'
    output:
        'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/rfrontalLobe.txt'
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin/; addpath
        $PWD/{config[spm_dir]}; batch_check_coverage('{input.con}',
        '{input.mask}','$(dirname {output})'); exit;"
        '''.replace('\n','')

rule gmPFCCov:
    input:
        con = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii',
        mask = config['mask_dir'] + '/GM_PFC_mask.nii'
    output:
        'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/GM_PFC_mask.txt'
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin/; addpath
        $PWD/{config[spm_dir]}; batch_check_coverage('{input.con}',
        '{input.mask}','$(dirname {output})'); exit;"
        '''.replace('\n','')

rule vsCov:
    input:
        con = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii',
        mask = config['mask_dir'] + '/rjuly_bilat_vs_duke.nii'
    output:
        'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/rjuly_bilat_vs_duke.txt'
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin/; addpath
        $PWD/{config[spm_dir]}; batch_check_coverage('{input.con}',
        '{input.mask}','$(dirname {output})'); exit;"
        '''.replace('\n','')

rule biamyCov:
    input:
        con = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii',
        mask = config['mask_dir'] + '/AAL_BiAmy_PickAtlas.nii'
    output:
        'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/AAL_BiAmy_PickAtlas.txt'
    shell:
        '''
	matlab -nodisplay -r "cd $PWD; addpath $PWD/bin/; addpath
        $PWD/{config[spm_dir]}; batch_check_coverage('{input.con}',
        '{input.mask}','$(dirname {output})'); exit;"
        '''.replace('\n','')

    

rule gmVSCov:
    input:
        con = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii',
        mask = config['mask_dir'] + '/GM_VS_mask.nii'
    output:
        'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/GM_VS_mask.txt'
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin/; addpath
        $PWD/{config[spm_dir]}; batch_check_coverage('{input.con}',
        '{input.mask}','$(dirname {output})'); exit;"
        '''.replace('\n','')

################################################################################
##########################QUALITY CHECKING RULES ###############################
################################################################################

# we need a reference functional image for coregistration check
# (see ./bin/qc_checkreg.sh)
rule getRegisteredFunc:
    input:
        'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/utbold.nii'
    output:
        'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_utboldref.nii.gz'
    shell:
        'fslroi {input} {output} 9 1'

# same for normalization check
# (see ./bin/qc_checkwarp.sh)
rule getNormFunc:
    input:
        'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/wutbold.nii'
    output:
        'data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_wutboldref.nii.gz'
    shell:
        'fslroi {input} {output} 9 1'
