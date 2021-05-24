#!/bin/bash

#read in entries from the sm_config file
task=$(cat config/sm_config.json | jq -r ".task[]")
ses=$(cat config/sm_config.json | jq -r ".ses[]")
acq=$(cat config/sm_config.json | jq -r ".acq[]")
run=$(cat config/sm_config.json | jq -r ".run[]")
bidsDir=$(cat config/sm_config.json | jq -r ".bids_dir")

#initialize empty subs array
subs=""
for sub in "${bidsDir}"/sub-*; do
  #extract subject id from filepath
  sub=$(echo ${sub} | cut -d "/" -f 4 | cut -d "-" -f 2)
  addSub=1
  missing="missing:"
  iMissing=0
  for t in ${task}; do
    for s in ${ses}; do
      for r in ${run}; do
        for a in ${acq}; do
          reqd='${bidsDir}/sub-${sub}/ses-${s}/func/sub-${sub}_ses-${s}_task-${t}_acq-${a}_run-${r}_bold.nii.gz ../../reorientation/sub-${sub}/ses-${s}/T1w_reorient.mat'
          if [ "${acq}" == "mb" ]; then
            reqd="${reqd}"' ${bidsDir}/sub-${sub}/ses-${s}/fmap/sub-${sub}_ses-${s}_acq-${t}_run-1_fieldmap.nii.gz ../../eventLogs/sub-${sub}/ses-${s}/sub-${sub}_ses-${s}_run-${r}_${t}.mat'
          elif [ "${acq}" == "sp" ]; then
            reqd="${reqd}"' ../../eventLogs/sub-${sub}/ses-${s}/sub-${sub}_ses-${s}_run-${r}_${t}.csv'
          fi
          for f in ${reqd}; do
            f=$(eval echo "${f}")
            if ! [ -f "${f}" ]; then
              addSub=0
              missing=${missing}$'\n'${f}
              let "iMissing=iMissing+1"
            fi
          done
        done
      done
    done
  done
  #if the subject has all files, add to list
  if [ ${addSub} -eq 1 ]; then
    subs="${subs} \"${sub}\","
  #otherwise, if the subject has the bold.nii.gz, but not other files, report it
  elif ! [[ "${missing}" == *"bold.nii.gz"* ]]; then
    echo "${sub}"
    echo "${missing}"
    echo
  fi
done

echo
echo "${subs}"
