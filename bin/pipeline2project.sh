#!/bin/bash

# help text
function helpTxt(){
  echo -e ""
	txt="\nDESCRIPTION:\n  copy files from raw MIDS directory into BIDS standard.\nUSAGE:\n  ./$(basename $0) -d <MIDS_DATA_DIR> -s <BIDS session no> -n <no expected func runs> [OPTIONS]\nOPTIONS:\n  -d, --dir         /path/to/raw/MIDS/\n  -s, --session     BIDS session id (ses-\#)\n  -n, --n-runs      Number of expected runs in task-based functional folders\n  -j, --cores        Max number of cores in use at parallel (default 1)\n  -f, --force        force overwrite for already existing files in BIDS directory\n  -h, --help        Display this help text\n"
	echo -e "$txt"
	exit
}


N=1 #default n-cores
force=""
#========================================
#========parse/validate inputs===========
#========================================
while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-d|--dir)
		subject_directory="$2"
		shift 2
		;;
		-s|--session)
		ses="$2"
		shift 2
		;;
		-n|--n-runs)
		nRuns="$2"
		shift 2
		;;
		-h|--help)
		helpTxt
		shift 2
		;;
		-j|--cores)
		N="$2"
		shift 2
		;;
		-f|--force)
		force=" -f"
		shift
	esac
done
