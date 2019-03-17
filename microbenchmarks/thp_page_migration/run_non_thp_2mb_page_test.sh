#!/bin/bash


PAGE_LIST=`seq 0 9`
COPY_METHOD="mt"
MULTI="1 2 4 8 16"

if [ ! -d thp_verify ]; then
	mkdir thp_verify
fi

if [ ! -d stats_non_thp ]; then
	mkdir stats_non_thp
fi

for I in `seq 1 5`; do
	for MT in ${MULTI}; do
		sudo sysctl vm.limit_mt_num=${MT}
		for METHOD in ${COPY_METHOD}; do
			if [[ "x${METHOD}" == "xmt" && "x${MT}" == "x1" ]]; then
				PARAM="st"
			else
				PARAM=${METHOD}
			fi
			for N in ${PAGE_LIST}; do
				NUM_PAGES=$((512<<N))

				if [[ "x${I}" == "x1" ]]; then
					numactl -N 0 -m 0 ./non_thp_move_pages ${NUM_PAGES} ${PARAM} 2>./thp_verify/non_thp_2mb_page_order_${N} | grep -A 3 "\(Total_cycles\|Test successful\)" > ./stats_non_thp/${METHOD}_${MT}_non_thp_2mb_page_order_${N}
				else
					numactl -N 0 -m 0 ./non_thp_move_pages ${NUM_PAGES} ${PARAM} 2>./thp_verify/non_thp_2mb_page_order_${N} | grep -A 3 "\(Total_cycles\|Test successful\)" >> ./stats_non_thp/${METHOD}_${MT}_non_thp_2mb_page_order_${N}
				fi

				sleep 1
			done
		done
	done
done


