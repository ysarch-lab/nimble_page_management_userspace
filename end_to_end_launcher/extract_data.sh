#!/bin/bash

if [[ "x$1" == "x" ]]; then
	echo "Need to specify a folder"
	exit
fi

FOLDER=$1

BENCHS="503.postencil  551.ppalm  553.pclvrleaf  555.pseismic  556.psp  559.pmniGhost  560.pilbdc  563.pswim  570.pbt  graph500-omp"
CONFIGS="all-remote-access non-thp-migration thp-migration opt-migration exchange-pages all-local-access"
#CONFIGS="concur-only-opt-migration concur-only-exchange-pages"

echo "AVERAGE:"
echo "	"${BENCHS}
for C in ${CONFIGS}; do
	if test "$(find ${FOLDER}/*/*GB-${C}* -name '*cycles' -print -quit 2>/dev/null)"; then
		echo -n "${C} "
		for B in ${BENCHS}; do
			#echo "${C} "
			#grep "cycles:" ${FOLDER}/${B}/*GB-${C}*/*cycles | cut -f 2 -d" " | awk -v config=${C} '{printf("%s %s\n",config, $0)}'
			AVG=`grep "cycles:" ${FOLDER}/${B}/*GB-${C}*/*cycles | cut -f 2 -d" " | awk '{n += 1; sum += int($1); sumsq += int($1)^2} END {stddev=sqrt((sumsq - sum^2/n)/n);printf("%.2f",sum/n)}'`
			echo -n "${AVG} "
		done
		echo
	fi
done

echo "STDDEV:"
echo "	"${BENCHS}
for C in ${CONFIGS}; do
	if test "$(find ${FOLDER}/*/*GB-${C}* -name '*cycles' -print -quit 2>/dev/null)"; then
		echo -n "${C} "
		for B in ${BENCHS}; do
			#echo "${C} "
			#grep "cycles:" ${FOLDER}/${B}/*GB-${C}*/*cycles | cut -f 2 -d" " | awk -v config=${C} '{printf("%s %s\n",config, $0)}'
			STDDEV=`grep "cycles:" ${FOLDER}/${B}/*GB-${C}*/*cycles | cut -f 2 -d" " | awk '{n += 1; sum += int($1); sumsq += int($1)^2} END {stddev=sqrt((sumsq - sum^2/n)/n);printf("%.2f",stddev)}'`
			echo -n "${STDDEV} "
		done
		echo
	fi
done