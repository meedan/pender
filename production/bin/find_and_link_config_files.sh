#!/bin/bash

# find all the files that end in *.example and setup links to them in the `shared` directory

# change to the code base directory
BASEDIR=$1
cd ${BASEDIR};

SHARED=${DEPLOYDIR}/shared;


# find all the files named example, except for the `vendor` directory
FILES=$(find . -not \( -path ./vendor -prune \) -name '*.example');

for F in $FILES; do
	# get the link name by removing the `.example` portion of the file name
	LF=$(echo $F | sed 's/\.example//' | sed 's|^./||');
	echo ${LF};
	
	# get the directory name by removing the BASEDIR portion
	LDIR=$(dirname ${LF} | sed 's/${BASEDIR}//' );

	# if the directory doesn't exist in `shared`, create it
	if [ ! -e ${SHARED}/${LDIR} ]; then
		echo "creating ${SHARED}/${LDIR}";
		mkdir -p ${SHARED}/${LDIR}	
	fi

	# setup the link
	rm -f ${LF};
	echo "linking ${LF} <-- ${DEPLOYDIR}/shared/${LF}"; 
	ln -s ${SHARED}/${LF} ${LF};
done