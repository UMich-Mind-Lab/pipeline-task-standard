import numpy as np
import pandas as pd
import os
inFile=snakemake.input[0]
outFile=snakemake.output[0]
task=snakemake.wildcards.task

df = pd.read_csv(inFile)

if task == 'faces':
    # onsets can be found in one of 4 columns, where 3 columns are NA and one
    # holds the actual onset time in ms. pandas summing ignores NA so we can put
    # it all in one column pretty easily
    df['onset'] = df[['LeftSlideF_OnsetTime','LeftSlideS_OnsetTime','RightSlideF_OnsetTime','RightSlideS_OnsetTime']].sum(axis=1)

    # then lets go ahead and make onset time relative to first trial, and
    # convert to seconds
    df['onset'] = (df['onset'] - df['onset'].min()) / 1000

    # the trial duration is usually 2 seconds, but it does jitter by a couple
    # milliseconds. We can grab how long each trial lasted from the following
    # four columns
    df['duration'] = df[['LeftSlideF_OnsetToOnsetTime','LeftSlideS_OnsetToOnsetTime','RightSlideF_OnsetToOnsetTime','RightSlideS_OnsetToOnsetTime']].sum(axis=1) / 1000

    # The csv has one row per trial, but ultimately we only need the onset and
    # duration of each block. We can get an index for the first trial of each
    # block by comparing the 'BlockList' column to the value of the previous
    # row. We can then use that index to grab the onsets we care about

    idxBlockStart = df['BlockList'].ne(df['BlockList'].shift())

    onset = df['onset'][idxBlockStart].reset_index(drop=True)

    # We can snag trial_type using the same index, from the Procedure_Trial_ column

    trial_type = df['Procedure_Trial_'][idxBlockStart].reset_index(drop=True)
    trial_type = trial_type.replace({'Fear':'Fearful'})
    # if we shift idxBlockStart in the opposite direction (-1), and tell it to
    # make the final trial = True (by default it would be NaN as it has no shift
    # value, we get the final trial of each block

    idxBlockEnd = idxBlockStart.shift(-1,fill_value=True)

    # Duration = Last onset + last duration - onset

    offset = df['onset'][idxBlockEnd] + df['duration'][idxBlockEnd]

    # need to reset index as the offset/onset objects retained their original
    # dataframe indices, which would make it so they don't subtract with their
    # proper counterpart
    duration =  offset.reset_index(drop=True) - onset

    dfOut = pd.DataFrame({'onset':onset,'duration':duration,'trial_type':trial_type})

elif task == 'gng':
    # The gng task .csv has some rows we need to get rid of. The condition row
    # has the string 'g' for go trials and 'ng' for nogo trials, so we can remove
    # bad rows by filtering with that column

    df = df[df['condition'].str.contains('g',na=False)]

    # onsets are found in Mole_OnsetTime or Veggie_OnsetTime
    df['onset'] = df[['Mole_OnsetTime','Veggie_OnsetTime']].sum(axis=1)

    # convert to seconds and make relative to task start time
    df['onset'] = (df['onset'] - df['onset'].min()) / 1000

    # we need three trial types: Go, NoGoCorrect, NoGoIncorrect. We almost have
    # this in the 'condition' column, but we need to add correct/incorrect from
    # the Veggie_ACC column, and then format a little

    df['trial_type'] = df['condition'].str.replace('ng[1-5]','noGoCorrect')
    df['trial_type'] = df['trial_type'].str.replace('g[1-5]','go')

    df.loc[df['Veggie_ACC'] == 0, 'trial_type'] = 'noGoIncorrect'

    #duration is easy - just 0 for every trial (SPM interprets this as event design)

    df['duration'] = 0

    dfOut = df[['onset','duration','trial_type']]

elif task == 'reward':
    #we first need to clean up the 'Running' column to get trial type
    df = df[~df['Running'].isna()] #get rid of non-trial columns if exists
    #search substrings to standardize output (get rid of "islands")
    df.loc[df['Running'].str.contains('BW'),'Running'] = 'BigWin'
    df.loc[df['Running'].str.contains('LW'),'Running'] = 'LittleWin'
    df.loc[df['Running'].str.contains('NeutralW'),'Running'] = 'NeutralWin'
    df.loc[df['Running'].str.contains('NeutralL'),'Running'] = 'NeutralLoss'
    df.loc[df['Running'].str.contains('LL'),'Running'] = 'LittleLoss'
    df.loc[df['Running'].str.contains('BL'),'Running'] = 'BigLoss'

    #clear out all rows where running is not one of these trials
    keepRows = ['BigWin','LittleWin','NeutralWin','NeutralLoss','LittleLoss','BigLoss']
    df = df[df['Running'].str.contains('|'.join(keepRows))]

    # Like faces, we need to get the first and last row of each block
    idxBlockStart = df['Running'].ne(df['Running'].shift())
    idxBlockEnd = idxBlockStart.shift(-1,fill_value=True)

    # Onsets are spread out across 18 different columns cuz eprime. We can use
    # regex to capture each one (Blank##.OnsetTime), though need to drop Blank20
    # because that one isn't a thing. There's probably a way to one line regex that
    # but I can't be bothered with figuring that out rn so I'll just do two lines
    df.drop(columns=['Blank20.OnsetTime','Outcome20.OnsetTime'],inplace=True)

    onsetCols = df.columns[df.columns.str.contains('Blank[0-9]*.OnsetTime')]
    df['onset'] = df[onsetCols].sum(axis=1)

    # same with offset columns, which will be Outcome##_OnsetTime
    offsetCols = df.columns[df.columns.str.contains('Outcome[0-9]*.OnsetTime')]
    df['offset'] = df[offsetCols].sum(axis=1)

    # fix relative timing and convert to seconds
    startTime = df['onset'].min()
    df['onset'] = (df['onset'] - startTime) / 1000
    df['offset'] = (df['offset'] - startTime) / 1000

    #now just get the values needed for the block
    trial_type = df['Running'][idxBlockStart].reset_index(drop=True)
    onset = df['onset'][idxBlockStart].reset_index(drop=True)
    duration = df['offset'][idxBlockEnd].reset_index(drop=True) - onset

    dfOut = pd.DataFrame({'onset':onset,'duration':duration,'trial_type':trial_type})

dfOut.to_csv(outFile,index=False,sep='\t')
