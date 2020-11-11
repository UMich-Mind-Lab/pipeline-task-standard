import numpy as np
import pandas as pd

inFile=snakemake.input[0]
outFile=snakemake.output[0]
task=snakemake.wildcards.task

#inFile='/nfs/turbo/lsa-csmonk/SAND/mri/eventLogs/sub-10002/ses-1/sub-10002_ses-1_task-faces_run-1_events.csv'



df = pd.read_csv(inFile)

if task == 'reward':
    #remove non-trial rows
    df = df[df['Cue.OnsetTime'].notna()].copy()

    #Format Timing Parameters. All timing values need to be set relative to the first
    #Cue onset time, then, times need to be converted from ms to s.

    startTime = min(df['Cue.OnsetTime'])
    df['Ant.Onset'] = (df['Cue.OnsetTime'] - startTime)/1000
    df['Ant.Duration'] = 0
    #df['Ant.Duration'] = (df['Dly.OnsetTime'] - df['Cue.OnsetTime'])/1000
    df['Tgt.Onset'] = (df['Tgt.OnsetTime'] - startTime)/1000
    df['Tgt.Duration'] = 0
    df['Fbk.Onset'] = (df['Fbk.OnsetTime'] - startTime)/1000
    df['Fbk.Duration'] = 0
    #df['Fbk.Duration'] = (df['Dly3.OnsetTime'] - df['Fbk.OnsetTime'])/1000

    #name trial types
    df['Ant.Trial_Type'] = df['Current'].map({'No win or lose':'NeutAnt',
      'Lose 250':'LoseAnt','Lose 0':'LoseAnt','Win 0':'WinAnt','Win 500':'WinAnt'})
    df['Fbk.Trial_Type'] = df['Current'].map({'No win or lose':'NeutFeedback','Lose 250':'LoseFeedbackNeg',
      'Lose 0':'LoseFeedbackPos','Win 0':'WinFeedbackNeg','Win 500':'WinFeedbackPos'})
    df['Tgt.Trial_Type'] = df['Current'].map({'No win or lose':'NeutTarget','Lose 250':'LoseTarget',
      'Lose 0':'LoseTarget','Win 0':'WinTarget','Win 500':'WinTarget'})


    onset = df['Ant.Onset'].append(df['Fbk.Onset']).append(df['Tgt.Onset'])
    duration = df['Ant.Duration'].append(df['Fbk.Duration']).append(df['Tgt.Duration'])
    trial_type = df['Ant.Trial_Type'].append(df['Fbk.Trial_Type']).append(df['Tgt.Trial_Type'])

    dfOut = pd.concat([onset,duration,trial_type],axis=1,ignore_index=True)
    dfOut.rename(columns={0:'onset',1:'duration',2:'trial_type'},inplace=True)

elif task == 'faces':
    #remove non-trial rows
    df = df[df['EmoStim.OnsetTime'].notna()].copy()

    #format Timing parameters. All timing values need to be set relative to the
    #start of the task in the scanner.
    #TODO: confirm this!!!
    startTime = min(df['Fixation.OnsetTime'])
    df['onset'] = (df['EmoStim.OnsetTime'] - startTime)/1000
    df['duration'] = 0
    df['pmod_rt'] = df['EmoStim.RT']

    #define trial type for each condition.
    df['trial_type'] = df['condition']

    #we need to filter out rt and trial_type for incorrect  responses. RT is
    #ditched because some incorrect trials had no response
    idx = (df['EmoStim.ACC'].astype(int)==0) & (df['EmoStim.RT'].astype(int) > 0)
    df.loc[idx,'trial_type'] = 'incorrect'
    idx = (df['EmoStim.ACC'].astype(int)==0) & (df['EmoStim.RT'].astype(int) == 0)
    df.loc[idx,'trial_type'] = 'missing'

    df.loc[idx,'pmod_rt'] = np.nan


    dfOut = df[['onset','duration','trial_type','pmod_rt']]
    #error (incorrect trials) onset = trialOnsetTime
    #happyface onset happyface (correct trials only)
    #parametric modulator emostimRT (happyfaceRT, etc...)
    #durations 0 prolly

dfOut.to_csv(outFile,index=False,sep='\t')
