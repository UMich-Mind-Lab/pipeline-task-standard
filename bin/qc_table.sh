#!/bin/bash

function helpTxt(){
	echo -e "\nDESCRIPTION:\n"
	echo -e "This script formats visual inspection output into a table, listing "
	echo -e "their status and results. Users have the option to provide additional "
	echo -e "flags to filter the table to include only what is specified (e.g., a "
	echo -e "particular task or session)"
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
  echo -e "\nOTHER OPTIONS:\n"
	echo -e "  -h, --help       display this help text\n"
	exit
}

task='*'
acq='*'
sub='*'
ses='*'
run='*'
while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
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
		-h|--help)
		helpTxt
		exit
		;;
	esac
done


# move to pipeline-<pipeline> directory
startDir=$(pwd)
scriptDir=$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P) #location of this script
cd "${scriptDir}/.."

printf "%-12s\t%-6s\t%-6s\t%-6s\t%-6s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t\n" \
  "sub" "ses" "task" "acq" "run" "regDone" "regRate" "regTime" "warpDone" "warpRate" "warpTime"
for x in ./data/${task}/preproc/acq-${acq}/sub-${sub}/ses-${ses}/run-${run}/; do
  curSub=$(echo ${x} | cut -d "/" -f 6 | cut -d "-" -f 2)
  curSes=$(echo ${x} | cut -d "/" -f 7 | cut -d "-" -f 2)
  curTask=$(echo ${x} | cut -d "/" -f 3)
  curAcq=$(echo ${x} | cut -d "/" -f 5 | cut -d "-" -f 2)
  curRun=$(echo ${x} | cut -d "/" -f 8 | cut -d "-" -f 2)
  regQC="${x}/QC/checkreg.done"
  if [ -f ${regQC} ]; then
    regDone="1"
    regRating=$(tail -n 1 ${regQC} | awk '{ print $1 }')
    regTime=$(tail -n 1 ${regQC} | awk '{ print $4 }')
  else
    regDone="0"
    regRating="N/A"
    regTime="N/A"
  fi
  warpQC="${x}/QC/checkreg.done"
  if [ -f ${warpQC} ]; then
    warpDone="1"
    warpRating=$(tail -n 1 ${warpQC} | awk '{ print $1 }')
    warpTime=$(tail -n 1 ${warpQC} | awk '{ print $4 }')
  else
    warpDone="0"
    warpRating="N/A"
    warpTime="N/A"
  fi
  printf "%-12s\t%-6s\t%-6s\t%-6s\t%-6s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t%-10s\t\n" \
    ${curSub} ${curSes} ${curTask} ${curAcq} ${curRun} ${regDone} ${regRating} ${regTime} ${warpDone} ${warpRating} ${warpTime}
done
