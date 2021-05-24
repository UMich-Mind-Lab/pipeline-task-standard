#!/bin/bash

#The line before is literally the location of bash coding language in computer. #Bash is a coding language but is also a script itself.
count=0
missing=0
notready=0
for task in ./data/*; do
	for acq in ${task}/preproc/acq-*; do
		for ses in 1 2; do
			for sub in ${acq}/sub-*/ses-${ses}/run-*; do
				boldref=${sub}/*_utboldref.nii.gz
				if [ -f ${sub}/QC/checkreg.done ]; then
					count=$(($count+1))
				elif [ -f ${boldref} ]; then
			  		missing=$(($missing+1))
				else
					notready=$(($notready+1))
				fi
			done
			currentTask=$(echo ${task} | cut -d "/" -f 3)
			currentAcq=$(echo ${acq} | cut -d "-" -f 2)
			echo "ses $ses acq $currentAcq task $currentTask"
			echo "completed=$count"
			echo "missing=$missing"
			echo "not ready=$notready"
			echo ""
			count=0
			missing=0
			notready=0
		done
	done
done

#Now we are running a for loop so that we can look at the subjects within each #subject folder. We are using stars as “wild cards” to search for all of the #different iterations/ different variables.









#Search every subject
#If sub folder exists, we want the qc check file to exists for subject
#Count how many qc files are done
#how many don’t have qc files
#How many don’t have qc files in each task (faces, gng, reward)
#How many don’t have qc files in each session (s1, s2)


#                       completed missing flags
#task-<task>_acq-<acq>_ses-<ses>_run-<run>
#task<faces>


#           Completed Flagged
#users
