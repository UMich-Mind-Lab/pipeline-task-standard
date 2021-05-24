#!/bin/bash

function helpTxt(){
	echo -e "\nDESCRIPTION:\n"
	echo -e "Prepares a project directory with the information specified via flags "
	echo -e "a work in progress, ya know?"
	echo -e "\nUSAGE:\n"
	echo -e "  ${BASH_SOURCE[0]} -p <project_dir> -t <bids_task>"
	echo -e "\nOPTIONS WITH ARGUMENTS:\n"
	echo -e "  -p, --proj       project directory"
	echo -e "  -s, --ses        bids session id"
	echo -e "  -t, --task       bids task label"
	echo -e "  -a, --acq        acquisition type"
	echo -e "\nOTHER OPTIONS:\n"
	echo -e "  -f, --force      overwrite previously existing files"
	echo -e "  -h, --help       display this help text\n"
	exit
}


#defaults
acq='*'
force=""
#========================================
#========parse/validate inputs===========
#========================================
while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-p|--proj)
		proj="$2"
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
		-h|--help)
		helpTxt
		shift 2
		;;
		-f|--force)
		force=" -f"
		shift
	esac
done

module load anaconda-3.7

if ! [ -d "${proj}" ]; then
	echo "Error: specified project directory (${proj}) does not exist!"
	exit 1
fi

mkdir ${proj}/bin
mkdir ${proj}/config
mkdir ${proj}/qc
mkdir ${proj}/lib

mkdir ${proj}/data
mkdir ${proj}/data/mri
mkdir ${proj}/data/survey
mkdir ${proj}/data/behavioral

# COPY CONTRASTS
echo "copying contrast files..."
for x in ./data/${task}/L1/acq-${acq}/sub-*/ses-${ses}/con_0*.nii; do
	[ -e ${x} ] || continue
	sub=$(echo ${x} | awk -F '[/-]' '{print $8}')
	if ! [ -d "${proj}/data/mri/sub-${sub}" ]; then
		mkdir ${proj}/data/mri/sub-${sub}
	fi
	con=$(basename ${x})
	cp -v ${x} ${proj}/data/mri/sub-${sub}/${con}
	# for gng, if the subject is perfect, then con_0001 should also be con_0002
	if [ "${task}" == "gng" ] && [ "${con}" == "con_0001.nii" ] && ! [ -f ${con/"0001"/"0002"} ]; then
		cp -v ${x} ${proj}/data/mri/sub-${sub}/${con/"0001"/"0002"}
	fi
done

# Make tables
echo "creating qc table..."
./bin/qc_table.sh -t ${task} -s ${ses} > ${proj}/qc/preproc_visual_qc.tsv
echo "creating art table..."
./bin/get_art_table.py  -t ${task} -s ${ses} -o ${proj}/qc/art_outliers.tsv
echo "creating coverage table..."
./bin/get_coverage_table.sh -t ${task} -s ${ses} > ${proj}/qc/coverage_table.tsv

#Copy config
cp config/spm_config.json ${proj}/config/
cp config/spm_modelcon_config.json ${proj}/config/

echo "done!"
