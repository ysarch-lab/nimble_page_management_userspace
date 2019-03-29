#!/bin/bash

if [[ "x$1" == "x" ]]; then
	echo "Need to specify a folder"
	exit
fi

FOLDER=$1

BENCHS="503.postencil  551.ppalm  553.pclvrleaf  555.pseismic  556.psp  559.pmniGhost  560.pilbdc  563.pswim  570.pbt  graph500-omp"
CONFIGS="all-remote-access non-thp-migration thp-migration opt-migration exchange-pages all-local-access"
#CONFIGS="all-remote-access non-thp-migration thp-migration opt-migration all-local-access"
#CONFIGS="all-remote-access non-thp-migration thp-migration opt-migration"
#CONFIGS="non-thp-migration thp-migration opt-migration exchange-pages"
#CONFIGS="opt-migration exchange-pages"


for B in ${BENCHS}; do
	echo "${B}"
	for C in ${CONFIGS}; do
		#grep "cycles:" ${FOLDER}/${B}/*GB-${C}*/*cycles | cut -f 2 -d" " | awk '{n += 1; sum += int($1); sumsq += int($1)^2} END {stddev=sqrt((sumsq - sum^2/n)/n);printf("%.2f",sum/n)}'
	if test "$(find ${FOLDER}/${B}/*GB-${C}* -name '*cycles' -print -quit 2>/dev/null)"; then
		echo -n "${C} "
		grep "cycles:" ${FOLDER}/${B}/*GB-${C}*/*cycles | cut -f 2 -d" " | awk '{n += 1; sum += int($1); sumsq += int($1)^2} END {stddev=sqrt((sumsq - sum^2/n)/n);printf("%.2f %.2f %.2f",sum/n, stddev, stddev/(sum/n))}'
		echo
	fi
	done
done