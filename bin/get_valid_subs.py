#!/bin/env python3

import json
import itertools
import os

#read snakemake config file into python variable
with open('./config/sm_config.json','r') as f:
    smCfg = json.load(f)

# get list of all bids subjects
bidsDir = smCfg['bids_dir']
subs = os.listdir(bidsDir)
subs = [x[4:] for x in subs if 'sub-' in x] #only include paths with sub-, also remove sub-

#combine the parameters. Loop through this to see if all necessary files exist
params = itertools.product(subs,smCfg['ses'],smCfg['task'],smCfg['run'],smCfg['acq'])

#load subjects into iterSubs and whether files exist into validParams, we'll zip
#the two lists together after the loop to figure out which subjects are valid
iterSubs=[]
validParams=[]
for x in params:
    valid=True
    reqFiles=[]
    #func image
    valid = os.path.exists(os.path.join(bidsDir,f'sub-{x[0]}',f'ses-{x[1]}','func',f'sub-{x[0]}_ses-{x[1]}_task-{x[2]}_acq-{x[4]}_run-{x[3]}_bold.nii.gz')) & valid
    #anat image
    valid = (os.path.exists(os.path.join(bidsDir,f'sub-{x[0]}',f'ses-{x[1]}','anat',f'sub-{x[0]}_ses-{x[1]}_acq-highres_T1w.nii.gz')) |
            os.path.exists(os.path.join(bidsDir,f'sub-{x[0]}',f'ses-{x[1]}','anat',f'sub-{x[0]}_ses-{x[1]}_acq-overlay_T1w.nii.gz'))) & valid
    if x[4] == 'mb':
        #fieldmap
        valid = os.path.exists(os.path.join(bidsDir,f'sub-{x[0]}',f'ses-{x[1]}','fmap',f'sub-{x[0]}_ses-{x[1]}_acq-{x[2]}_run-1_fieldmap.nii.gz')) & valid
        #raw mat event file
        valid = os.path.exists(os.path.abspath(os.path.join(bidsDir,os.pardir,'eventLogs',f'sub-{x[0]}',f'ses-{x[1]}',f'sub-{x[0]}_ses-{x[1]}_run-{x[3]}_{x[2]}.mat'))) & valid
    elif x[4] == 'sp':
        #raw csv event file
        valid = os.path.exists(os.path.abspath(os.path.join(bidsDir,os.pardir,'eventLogs',f'sub-{x[0]}',f'ses-{x[1]}',f'sub-{x[0]}_ses-{x[1]}_run-{x[3]}_{x[2]}.csv'))) & valid
    #determine if each path exists
    validParams.append(valid)
    iterSubs.append(x[0])

# if all params containing a particular subject are true, then the subject is valid
for i in range(len(subs)-1,-1,-1):
    if not(all([y for x,y in zip(iterSubs,validParams) if x == subs[i]])):
        del(subs[i])

# update json file with valid subs
smCfg['sub'] = subs
with open('./config/sm_config.json','w') as f:
    f.write(json.dumps(smCfg,indent=2))
