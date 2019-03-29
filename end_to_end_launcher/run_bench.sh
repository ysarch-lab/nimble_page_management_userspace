#!/bin/bash

if [ "x$1" != "x" ]
then
	export CPUS=$1
else
	export CPUS=1
fi

PROJECT_LOC="/home/yanzi/projects/thp_migration/two-level-memory"

if [[ "x${BENCH}" == "xdata-caching" || "x${BENCH}" == "xmemcached-user"  ]]; then
LAUNCHER="${PROJECT_LOC}/launcher --dumpstats_signal --dumpstats_period ${STATS_PERIOD}"
else
LAUNCHER="${PROJECT_LOC}/launcher --dumpstats --dumpstats_period ${STATS_PERIOD}"
fi

PERF="/home/yanzi/projects/repos/linux/tools/perf/perf"
PERF_EVENTS="cycles,instructions,itlb_misses.miss_causes_a_walk,itlb_misses.walk_duration,dtlb_load_misses.miss_causes_a_walk,dtlb_load_misses.walk_duration,dtlb_store_misses.miss_causes_a_walk,dtlb_store_misses.walk_duration"
#PERF_EVENTS="cycles,instructions,iTLB-loads,iTLB-load-misses,itlb_misses.miss_causes_a_walk,itlb_misses.walk_duration,dTLB-loads,dTLB-load-misses,dtlb_load_misses.miss_causes_a_walk,dtlb_load_misses.walk_duration,dTLB-stores,dTLB-store-misses,dtlb_store_misses.miss_causes_a_walk,dtlb_store_misses.walk_duration"

FLAMEGRAPH_LOC="/home/yanzi/tools/FlameGraph"

PERF_CMD="${PERF} stat -e ${PERF_EVENTS}"

MEMCG_PROC="/sys/fs/cgroup/two-level-memory/cgroup.procs"


THREAD_PER_CORE=`lscpu|grep Thread|awk '{print $NF}'`
CORE_PER_SOCKET=`lscpu|grep Core|awk '{print $NF}'`
SOCKET=`lscpu|grep Socket|awk '{print $NF}'`

TOTAL_CORE=$((CORE_PER_SOCKET*SOCKET))

if [[ "x${MEMHOG_THREADS}" == "x"  ]]; then
	MEMHOG_THREADS=6
fi

if [[ "x${STATS_PERIOD}" == "x" ]]; then
	STATS_PERIOD=5
fi

FAST_NUMA_NODE=${FAST_NODE}
#FAST_NUMA_NODE=0

if [[ "x${SHRINK_PAGE_LISTS}" == "xyes" ]]; then
LAUNCHER="${LAUNCHER} --shrink_page_lists"
SCHEME_ADDON=-shrink-page-lists
fi

CONFIG_INFO=${BENCH}-"${CPUS}-cpu-${BENCH_SIZE}"-${SCHEME}${SCHEME_ADDON}-${MEMHOG_THREADS}-memhogs-`date +%F-%T`

LAUNCHER="${LAUNCHER} --memcg ${MEMCG_PROC}"


if [[ "x${NO_MIGRATION}" == "xyes" ]]; then
	LAUNCHER="${LAUNCHER} --nomigration"
else # pages will be migrated

	case ${SCHEME} in
		non-thp-migration)
			LAUNCHER="${LAUNCHER} --non_thp_migration"
		;;
		thp-migration)
			LAUNCHER="${LAUNCHER} --thp_migration"
		;;
		concur-only-opt-migration)
			LAUNCHER="${LAUNCHER} --concur_migration"
		;;
		opt-migration)
			LAUNCHER="${LAUNCHER} --opt_migration"
		;;
		basic-exchange-pages)
			LAUNCHER="${LAUNCHER} --basic_exchange_pages"
		;;
		concur-only-exchange-pages)
			LAUNCHER="${LAUNCHER} --concur_only_exchange_pages"
		;;
		exchange-pages)
			LAUNCHER="${LAUNCHER} --exchange_pages"
		;;
		non-thp-exchange-pages)
			LAUNCHER="${LAUNCHER} --exchange_pages"
		;;
		*)
	esac
	if [[ "x${FORCE_NO_MIGRATION}" == "xyes" ]]; then
		LAUNCHER="${LAUNCHER} --nomigration"
	fi
fi

if [[ "x${MOVE_HOT_AND_COLD_PAGES}" == "xyes" ]]; then
	LAUNCHER="${LAUNCHER} --move_hot_and_cold_pages"
fi


#LAUNCHER="${LAUNCHER} --vm_stats --contig_stats --perf ${PERF_EVENTS} --defrag_online_stats"
#LAUNCHER="${LAUNCHER} --vm_stats --contig_stats --defrag_online_stats"
LAUNCHER="${LAUNCHER} --vm_stats" # --perf_loc ${PERF} --perf_events ${PERF_EVENTS}"

if [[ "x${PERF_STATS}" == "xyes" ]]; then
	LAUNCHER="${LAUNCHER} --perf_loc ${PERF} --perf_events ${PERF_EVENTS}"

	if [[ "x${PERF_INTERV}" != "x0" ]]; then
		LAUNCHER="${LAUNCHER} --perf_interv ${PERF_INTERV}"
	fi
fi

if [[ "x${PERF_FLAMEGRAPH}" == "xyes" ]]; then
	LAUNCHER="${LAUNCHER} --perf_loc ${PERF} --perf_flamegraph"
fi


FAST_NUMA_NODE_CPUS=`numactl -H| grep "node ${FAST_NUMA_NODE} cpus" | cut -d" " -f 4-`
read -a CPUS_ARRAY <<< "${FAST_NUMA_NODE_CPUS}"


if [ "x${BENCH}" == "x" ]; then
BENCH="canneal-mt"
fi

sync
echo 3 | sudo tee /proc/sys/vm/drop_caches

if [[ "x${SCHEME}" != "xall-local-access" ]] && [[ "x${MEMHOG_THREADS}" != "x0" ]]; then
sudo insmod /home/yanzi/tools/kernel-mod-ubench/pref-test.ko nthreads=${MEMHOG_THREADS}
trap "sudo rmmod -f pref_test;  exit" INT
fi

if [[ "x${SCHEME}" != "xall-local-access" ]] && [[ "x${SCHEME}" != "xall-remote-access" ]] ; then
	if [[ "x${PREFER_FAST_NODE}" == "xyes" ]]; then
	LAUNCHER="${LAUNCHER} --prefer_memnode"
	fi
fi

if [[ "x${SCHEME}" == "xall-local-access" ]]; then
NUMACTL_CMD="${LAUNCHER} --cpunode ${FAST_NODE} --fast_mem ${FAST_NODE} --slow_mem ${FAST_NODE} --memory_manage"
else
NUMACTL_CMD="${LAUNCHER} --cpunode ${FAST_NODE} --fast_mem ${FAST_NODE} --slow_mem ${SLOW_NODE} --memory_manage"
fi


#sleep 5

ALL_CPU_MASK=0
for IDX in $(seq 0 $((CPUS-1)) ); do
	CPU_IDX=$((IDX % ${#CPUS_ARRAY[@]}))
	CPU_MASK=$((1<<${CPUS_ARRAY[${CPU_IDX}]}))
	#CPU_MASK=$((1<<${CPUS_ARRAY[${CPU_IDX}]} | 1<<(${CPUS_ARRAY[${CPU_IDX}]}+${TOTAL_CORE})))

	ALL_CPU_MASK=`echo "${CPU_MASK}+${ALL_CPU_MASK}" | bc`

done

ALL_CPU_MASK=`echo "obase=16; ${ALL_CPU_MASK}" | bc`

#NUMACTL_CMD="${NUMACTL_CMD} -c 0x${ALL_CPU_MASK}"

echo "${NUMACTL_CMD}"

echo "begin benchmark"

RES_FOLDER=result-${CONFIG_INFO}

mkdir -p ${RES_FOLDER}

sysctl vm > ${RES_FOLDER}/vm_config


export NTHREADS=${CPUS}


if [[ "x${BENCH}" == "xdata-caching" || "x${BENCH}" == "xmemcached-user"  ]]; then

sudo dmesg -c >/dev/null
CUR_PWD=`pwd`
	cd ${CUR_PWD}/${BENCH}

	rm vm_stats_*

	echo -n "Warming up server..."
	export NUMACTL_CMD=${NUMACTL_CMD}
	#export TASKSET_CMD="taskset ${ALL_CPU_MASK}"
	./setup-server.sh
	echo "Done"

	LAUNCHER_PID=`pgrep launcher`


cat /proc/meminfo | grep "Migrated\|>\|<" > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_meminfo
cat /proc/zoneinfo > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_zoneinfo

if [[ "x${NO_MIGRATE}" == "x" ]]; then
	kill -USR1 ${LAUNCHER_PID}
fi

	${CUR_PWD}/time_rdts ${NUMACTL_CMD_CLIENT} -C ${CLIENT_TASK_MASK}  -- bash ./bench_run.sh 2> ${CUR_PWD}/${RES_FOLDER}/${BENCH}_cycles

if [[ "x${NO_MIGRATE}" == "x" ]]; then
	kill -USR1 ${LAUNCHER_PID}
fi

cat /proc/meminfo | grep "Migrated\|>\|<" >> ${CUR_PWD}/${RES_FOLDER}/${BENCH}_meminfo

	for STATS_FILE in `ls vm_stats_*`; do
		mv ${STATS_FILE} ${CUR_PWD}/${RES_FOLDER}/${BENCH}_${STATS_FILE}
	done
	if [ -f perf_results ]; then
		mv perf_results ${CUR_PWD}/${RES_FOLDER}/${BENCH}_perf_results
	fi

awk '{if (!($1 in dict)) {dict[$1] = int($2) } else {print $1, int($2)-dict[$1] } }' ${CUR_PWD}/${RES_FOLDER}/${BENCH}_meminfo > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_meminfo_res

	cd ${CUR_PWD}

	killall memcached
dmesg > ${RES_FOLDER}/${BENCH}_dmesg
sleep 5
numastat -m > ${RES_FOLDER}/${BENCH}_numastat

else # normal applications

sudo dmesg -c >/dev/null
CUR_PWD=`pwd`
	cd ${CUR_PWD}/${BENCH}
	source ./bench_run.sh

	rm vm_stats_*
	rm page_migration_periodic_stats_*
	rm page_migration_stats_*

cat /proc/meminfo | grep "Migrated\|>\|<" > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_meminfo
cat /proc/zoneinfo > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_zoneinfo
cat /proc/vmstat > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_vmstat
echo "${NUMACTL_CMD} ${LAUNCHER_OPT} -- ${BENCH_RUN}" > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_cmd

	${NUMACTL_CMD} ${LAUNCHER_OPT} -- ${BENCH_RUN} 2> ${CUR_PWD}/${RES_FOLDER}/${BENCH}_cycles

cat /proc/meminfo | grep "Migrated\|>\|<">> ${CUR_PWD}/${RES_FOLDER}/${BENCH}_meminfo
cat /proc/vmstat >> ${CUR_PWD}/${RES_FOLDER}/${BENCH}_vmstat

	unset LAUNCHER_OPT
	
	for STATS_FILE in `ls vm_stats_*`; do
		mv ${STATS_FILE} ${CUR_PWD}/${RES_FOLDER}/${BENCH}_${STATS_FILE}
	done
	for STATS_FILE in `ls page_migration_periodic_stats_*`; do
		mv ${STATS_FILE} ${CUR_PWD}/${RES_FOLDER}/${BENCH}_${STATS_FILE}
	done
	for STATS_FILE in `ls page_migration_stats_*`; do
		mv ${STATS_FILE} ${CUR_PWD}/${RES_FOLDER}/${BENCH}_${STATS_FILE}
	done

	if [[ "x${PERF_FLAMEGRAPH}" == "xyes" ]]; then
		perf script -i perf_results | ${FLAMEGRAPH_LOC}/stackcollapse-perf.pl > out.perf-folded
		${FLAMEGRAPH_LOC}/flamegraph.pl out.perf-folded > flamegraph.svg
		mv perf_results ${CUR_PWD}/${RES_FOLDER}/${BENCH}_perf_results
		mv flamegraph.svg ${CUR_PWD}/${RES_FOLDER}/${BENCH}_flamegraph.svg
	fi
	
	if [ -f perf_results ]; then
		mv perf_results ${CUR_PWD}/${RES_FOLDER}/${BENCH}_perf_results
	fi

awk '{if (!($1 in dict)) {dict[$1] = int($2) } else {print $1, int($2)-dict[$1] } }' ${CUR_PWD}/${RES_FOLDER}/${BENCH}_meminfo > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_meminfo_res
awk '{if (!($1 in dict)) {dict[$1] = int($2) } else {print $1, int($2)-dict[$1] } }' ${CUR_PWD}/${RES_FOLDER}/${BENCH}_vmstat > ${CUR_PWD}/${RES_FOLDER}/${BENCH}_vmstat_res
	cd ${CUR_PWD}
	cd ${CUR_PWD}
dmesg > ${RES_FOLDER}/${BENCH}_dmesg
sleep 5
numastat -m > ${RES_FOLDER}/${BENCH}_numastat
fi

if [[ ${BENCH_NAME} == "tensorflow"* ]]; then
        deactivate
fi

if [[ ${BENCH} == "cifar10" ]]; then
	rm -r ./cifar10/train/*
fi


if [[ "x${SCHEME}" != "xall-local-access" ]] && [[ "x${MEMHOG_THREADS}" != "x0" ]]; then
sleep 5
sudo rmmod pref_test
fi

date

