#!/bin/bash

function helpTxt(){
	echo -e "\nDESCRIPTION:\n"
	echo -e "Automation of normalization visual inspection. This script searches "
	echo -e "through analyzed data and selects images that have not been visually"
	echo -e "inspected for normalization, dependent on the optional arguments "
	echo -e "received. It then launches papaya in firefox. After rating the images"
	echo -e "and saving the .csv file, the script will parse the file and save the"
	echo -e "quality check information."
	echo -e "\nUSAGE:\n"
	echo -e "  ${BASH_SOURCE[0]}"
	echo -e "  ${BASH_SOURCE[0]} -t <task>"
	echo -e "  ${BASH_SOURCE[0]} -s <session> -t <task> -a <acquisition>\n"
	echo -e "The first example would not filter which images are selected, whereas"
	echo -e "the second example would select from available images within <task>."
	echo -e "The third example would filter further, to only include images with "
	echo -e "The specified acquisition and session."
	echo -e "\nOPTIONS WITH ARGUMENTS:\n"
	echo -e "  -i, --sub        bids subject id"
	echo -e "  -s, --ses        bids session id"
	echo -e "  -t, --task       bids task label"
	echo -e "  -a, --acq        acquisition type"
	echo -e "  -r, --run        bids run id"
	echo -e "  -n, --n-subs     number of images to include in the batch [default=50]"
	echo -e "\nOTHER OPTIONS:\n"
	echo -e "  -f, --fail       only view images that have previously failed"
	echo -e "  -h, --help       display this help text\n"
	exit
}

function exitScript(){
	#delete temp files
	if ! [ -z ${workDir+x} ]; then
		rm -r "${workDir}"
	fi
	#remove locks
	if ! [ -z ${locks+x} ]; then
		rm ${locks[@]}
	fi
	cd "${startDir}" #return to start
	trap - SIGINT SIGTERM #clear trap
	kill -- -$$ #kills any possible child processes
	exit
}

#make sure cleanup happens if the script is killed  (e.g., with ctrl+C)
trap exitScript SIGINT SIGTERM

task='*'
acq='*'
sub='*'
ses='*'
run='*'
nCheck=50
failMode=0
while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-n|--n-subs)
    nCheck="$2"
    shift 2
    ;;
    -t|--task)
    task="$2"
    shift 2
    ;;
		-i|--sub)
		sub="$2"
		shift 2
		;;
		-s|--ses)
		ses="$2"
		shift 2
		;;
		-a|--acq)
		acq="$2"
		shift 2
		;;
		-r|--run)
		run="$2"
		shift 2
		;;
		-f|--fail)
		failMode=1
		shift
		;;
		-h|--help)
		helpTxt
		exit
		;;
	esac
done

# STEP 1: Select images to check.
startDir=$(pwd)
scriptDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)
cd "${scriptDir}/.."

i=0
bolds=()
t1ws=()
locks=()
if [ $failMode -eq 1 ]; then
	echo "Selecting failed images..."
	for reg in data/${task}/preproc/acq-${acq}/sub-${sub}/ses-${ses}/run-${run}/QC/checkwarp.done; do
		[ -f "${reg}" ] || continue #only move on if files are found through wildcard expansion
		# break the loop if we have as nSubs subs
	  if [[ $i -eq $nCheck ]]; then
	    break
	  fi
	#get rating from file
		regRating=$(tail -n 1 ${reg} | awk '{ print $1 }')
		if [ ${regRating} -eq 0 ]; then
			#load files into arrays
			i=$((i+1))
			preprocDir=$(dirname "${reg}")
			preprocDir=$(realpath "${preprocDir}/..")
			qcDir="${preprocDir}/QC"
			bolds+=(${preprocDir}/*_wutboldref.nii.gz)
			t1ws+=($(realpath "../../lib/spm12/canonical/avg152T1.nii"))
			lockFile="${qcDir}/checkwarp.lock"
			locks+=(${lockFile})
			#lock the subject
	    echo "${USER}" > "${lockFile}"
	    echo "$(date)" >> "${lockFile}"
		fi
	done
else
	echo "selecting images..."
	for bold in data/${task}/preproc/acq-${acq}/sub-${sub}/ses-${ses}/run-${run}/*_wutboldref.nii.gz; do
	  [ -f "${bold}" ] || continue
	  bold=$(realpath "${bold}")
	  # break the loop if we have as nSubs subs
	  if [[ $i -eq $nCheck ]]; then
	    break
	  fi

	  #define some files
	  preprocDir=$(dirname "${bold}")
	  t1w=$(realpath "../../lib/spm12/canonical/avg152T1.nii")
	  qcDir="${preprocDir}/QC"
	  lockFile="${qcDir}/checkwarp.lock"
	  doneFile="${qcDir}/checkwarp.done"
	  if [ ! -d "${qcDir}" ]; then mkdir -p "${qcDir}"; fi
		# remove donefile if it's older than the bold image
		if [ -f "${doneFile}" ] && [ "${bold}" -nt "${doneFile}" ]; then
			rm "${doneFile}"
		fi
	  #only select the QC file if it isn't locked by another user, if it isn't already done, and if the structural also exists
	  if [ -f "${t1w}" ] && [ ! -f "${lockFile}" ] && [ ! -f "${doneFile}" ]; then
	    i=$((i+1)) #increment counter
			bolds+=($bold) #add sub to the current subject list
	    t1ws+=($t1w)
	    locks+=($lockFile)
	    #lock the subject
	    echo "${USER}" > "${lockFile}"
	    echo "$(date)" >> "${lockFile}"
	  fi
	done
fi

nCheck=$i #set nCheck to number of files actually found

if [ $i -eq 0 ]; then echo "no files found with given search criteria."; exit 1; fi

# STEP 2: create working directory for papaya
echo "Configuring papaya..."
workDir=$(mktemp -d -p "tmp" "${USER}_XXXXXXXX")
workDir=$(realpath $workDir)
cp ./lib/papaya_template/* "${workDir}"/

echo 'username="'${USER}'";' > ${workDir}/envvars.js
echo 'filename="'${workDir}/subs.csv'";' >> ${workDir}/envvars.js
echo 'checktype="checkwarp";' >> ${workDir}/envvars.js
echo 'tempname="'$(basename ${workDir})'";' >> ${workDir}/envvars.js

#make JSON file
echo '[' > "${workDir}/images.json"
for i in $(seq 0 $nCheck); do
  echo '["'${t1ws[i]}'","'${bolds[i]}'"],' >> "${workDir}/images.json"
done
echo '["",""]' >> "${workDir}/images.json"
echo ']' >> "${workDir}/images.json"

#make CSV file
for i in $(seq 0 $nCheck); do
  a="sub-$(echo ${bolds[i]#*sub-} | cut -d "/" -f 1)"
  b="ses-$(echo ${bolds[i]#*ses-} | cut -d "/" -f 1)"
  c="task-$(echo ${bolds[i]#*"pipeline-task-standard"} | cut -d "/" -f 2)"
  d="run-$(echo ${bolds[i]#*run-} | cut -d "/" -f 1)"
  echo "${a}, ${b}, ${c}, ${d}" >> "${workDir}/subs"
done

# STEP 3: LAUNCH PAPAYA

echo "launching browser..."
firefox "${workDir}/index.html"

# STEP 4: CLEANUP

#the csv gets saved into the downloads folder with the same name as the temp directory
outCSV="${HOME}/Downloads/$(basename ${workDir}).csv"
if ! [ -f "${outCSV}" ]; then
	echo "ERROR: Firefox was closed before the CSV was saved :("
	exitScript
fi

echo "saving QC data and cleaning working environment..."
#get timestamp file created
checkTime=$(stat -c %y "$outCSV")
#read csv file and save contents to individual folders
while IFS=',' read func rating flag user check; do
	if [[ "${func}" == *"utboldref.nii"* ]]; then
		#parse filename for bids variables
		sub=$(echo "${func}" | cut -d "_" -f 1 | cut -d "-" -f 2)
		ses=$(echo "${func}" | cut -d "_" -f 2 | cut -d "-" -f 2)
		task=$(echo "${func}" | cut -d "_" -f 3 | cut -d "-" -f 2)
		acq=$(echo "${func}" | cut -d "_" -f 4 | cut -d "-" -f 2)
		run=$(echo "${func}" | cut -d "_" -f 5 | cut -d "-" -f 2)
		#construct qc Filename
		qcFile="data/${task}/preproc/acq-${acq}/sub-${sub}/ses-${ses}/run-${run}/QC/${check}.done"
		echo -e "\tsaving ${qcFile}"
		#save data into filename
		echo -e "Rating\tFlagged\tUser\tTimestamp" > "${qcFile}"
		echo -e "${rating}\t${flag}\t${user}\t${checkTime}" >> "${qcFile}"
	fi
done < $outCSV


rm -r "${workDir}"
rm ${locks[@]}
cd "${startDir}" #return to start

echo "done, pleasure doing business with you!"
