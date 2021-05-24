#!/bin/bash
# help text
function helpTxt(){
	txt="\nDESCRIPTION:\n outputs a mask coverage percentage table. Providing option inputs will filter the table to the specified criteria, otherwise it will simply display all data it can find.\nUSAGE:\n  ./$(basename $0) [OPTIONS]\nOPTIONS:\n  -i, --sub        bids subject id\n  -s, --ses        bids session id\n  -t, --task       fmri task name\n  -a, --acq        acquisition type\n  -m, --mask       mask filename of coverage check\n  -h, --help       display this help text\n"
	echo -e "$txt"
	exit
}

#========================================
#========parse/validate inputs===========
#========================================
sub='*'
ses='*'
task='*'
acq='*'
mask='*'
while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
    -i|--subject)
    sub="$2"
    shift 2
    ;;
    -s|--session)
    ses="$2"
    shift 2
    ;;
    -t|--task)
    task="$2"
    shift 2
    ;;
    -a|--acq)
    acq="$2"
    shift 2
    ;;
    -m|--mask)
    mask="$2"
    shift 2
    ;;
    -h|--help)
    helpTxt
    exit
    ;;
	esac
done

printf "%-6s\t%-6s\t%-6s\t%-6s\t%-30s\t%-10s\n" "sub" "ses" "task" "acq" "mask" "coverage"
for x in data/${task}/L1/acq-${acq}/sub-${sub}/ses-${ses}/coverage/${mask}.txt; do
  [ -e "$x" ] || continue
  curTask=$(echo ${x} | cut -d "/" -f 2)
  curAcq=$(echo ${x} | cut -d "/" -f 4 | cut -d "-" -f 2)
  curSub=$(echo ${x} | cut -d "/" -f 5 | cut -d "-" -f 2)
  curSes=$(echo ${x} | cut -d "/" -f 6 | cut -d "-" -f 2)
  curMask=$(basename ${x})
  printf "%-6s\t%-6s\t%-6s\t%-6s\t%-30s\t%.4f\n" "${curSub}" "${curSes}" "${curTask}" "${curAcq}" "${curMask/.txt/}" "$(cat ${x} | tail -n 1)"
done
