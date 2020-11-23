#tell it to not submit rule all to a cluster node


localrules: all, getRawFunc, getRawT1w, getRawFmap, getRawFmapMag, makeArtConfig
configfile: 'config/sm_config.json'

# pseudo rule to tell snakemake what we want the final product to be
rule all:
    input:
        expand(config['bids_dir']+'/sub-{sub}/ses-{ses}/func/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_events.tsv',
            sub=config['sub'],ses=config['ses'],task=config['task'],acq=config['acq'],run=config['run']),
        expand('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/chT1w.nii',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq'],
            run=config['run']),
        expand('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/swutbold.nii',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq'],
            run=config['run']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/con_0001.nii',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq']),
        expand('data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/coverage/rjuly_bilat_vs_duke.txt',
            task=config['task'],sub=config['sub'],ses=config['ses'],acq=config['acq'])


# STEP 1 - COPY INPUT FILES
rule getRawFunc:
    input:
        rawFunc = config['bids_dir']+'/sub-{sub}/ses-{ses}/func/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_bold.nii.gz'
    output:
        func = temp('data/{task}/preproc/acq-{acq}/sub-{sub}/ses-{ses}/run-{run}/bold.nii')
    shell:
        'gunzip -c {input} > {output}'

rule getRawT1w:
    input:
        RawT1w = config['bids_dir']+'/sub-{sub}/ses-{ses}/anat/sub-{sub}_ses-{ses}_acq-highres_T1w.nii.gz'
    output:
        tmpT1w = temp('tmp/sub-{sub}/ses-{ses}/T1w.nii')
    shell:
        'gunzip -c {input.RawT1w} > {output.tmpT1w}'

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

rule prep_realignUnwarp:
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

rule cleanRealignUnwarp:
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

#Now we begin creating Level 1s. Run wildcard is no longer used bc we created a
#run variable combining our multiple runs.

#if your bids directory does not yet have the events.tsv file, we're making those here
#from the source files. Remove this rule if you already have your events.tsv file
rule mkEventsTsv:
    input:
        eventMAT = '../../eventLogs/sub-{sub}/ses-{ses}/sub-{sub}_ses-{ses}_run-{run}_{task}.mat'
    output:
        eventTSV = config['bids_dir']+'/sub-{sub}/ses-{ses}/func/sub-{sub}_ses-{ses}_task-{task}_acq-{acq}_run-{run}_events.tsv'
    shell:
        '''
        matlab -nodisplay -r "cd $PWD; addpath ../../bin; addpath {config[spm_dir]};
        extract_events('{input}', '{output.eventTSV}', '{wildcards.task}', 1); exit"
        '''.replace('\n','')

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
        beta = 'data/{task}/L1/acq-{acq}/sub-{sub}/ses-{ses}/beta_0001.nii'
    shell:
        '''
        tmpJob=$(mktemp tmp/XXXXXXXX.mat)
        matlab -nodisplay -r "cd $PWD; addpath $PWD/bin; addpath {config[spm_dir]}; \
        L1_spm_modelest('SPM','{input.SPM}','outFile','$tmpJob'); exit"
        singularity run -B $PWD:/data {config[spmSif]} /data/bin/spm_jobman_run.m $tmpJob
        rm $tmpJob
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
