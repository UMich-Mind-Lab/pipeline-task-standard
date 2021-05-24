#!/bin/env python3

import glob
import scipy.io as sio
import pandas as pd
import argparse

# ARGUMENT PARSING
ap = argparse.ArgumentParser()
ap.add_argument('-i','--sub',nargs='?',default='*',type=str,help='BIDS subject ID')
ap.add_argument('-s','--ses',nargs='?',default='*',type=str,help='BIDS session label')
ap.add_argument('-r','--run',nargs='?',default='*',type=str,help='BIDS run label')
ap.add_argument('-a','--acq',nargs='?',default='*',type=str,help='BIDS acquisition label')
ap.add_argument('-t','--task',nargs='?',default='*',type=str,help='BIDS task label')
ap.add_argument('-o','--out',required=True,type=str,help='Filename for output csv')

args = vars(ap.parse_args())

artGlob = f'data/{args["task"]}/preproc/acq-{args["acq"]}/sub-{args["sub"]}/ses-{args["ses"]}/run-{args["run"]}/art_regression_outliers_swutbold.mat'

#search for all files given search filters
artFiles = glob.glob(artGlob)

df = pd.DataFrame({'sub':[],'ses':[],'task':[],'run':[],'acq':[],'nVols':[],'nOutliers':[]})

for x in artFiles:
    data=sio.loadmat(x)
    row = {'sub':x.split('/')[4][4:],
           'ses':x.split('/')[5][4:],
           'task':x.split('/')[1],
           'run':x.split('/')[6][4:],
           'acq':x.split('/')[3][4:],
           'nVols':data['R'].shape[0],
           'nOutliers':data['R'].shape[1]}
    df = df.append(row,ignore_index=True)

df['pOutliers'] = df['nOutliers'] / df['nVols']

if '.tsv' in args['out']:
	df.to_csv(args['out'],sep='\t',index=False)
else:
	df.to_csv(args['out'],index=False)
