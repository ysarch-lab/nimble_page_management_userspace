#!/bin/bash


PAGE_LIST=`seq 0 9`
COPY_METHOD="mt"
MULTI="1 2 4 8 16"

if [ ! -d thp_verify ]; then
	mkdir thp_verify
fi

if [ ! -d stats_4kb ]; then
	mkdir stats_4kb
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
				NUM_PAGES=$((1<<N))

				if [[ "x${I}" == "x1" ]]; then
					numactl -N 0 -m 0 ./non_thp_move_pages ${NUM_PAGES} ${PARAM} 2>./thp_verify/${METHOD}_${MT}_4kb_page_order_${N} | grep -A 3 "\(Total_cycles\|Test successful\)" > ./stats_4kb/${METHOD}_${MT}_4kb_page_order_${N}
				else
					numactl -N 0 -m 0 ./non_thp_move_pages ${NUM_PAGES} ${PARAM} 2>./thp_verify/${METHOD}_${MT}_4kb_page_order_${N} | grep -A 3 "\(Total_cycles\|Test successful\)" >> ./stats_4kb/${METHOD}_${MT}_4kb_page_order_${N}
				fi

				sleep 1
			done
		done
	done
done


