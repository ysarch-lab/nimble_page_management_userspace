#!/bin/bash

BENCH_NAME="graph500-omp"
#BENCH_RUN="./omp-csr -s 25"
#BENCH_RUN="./omp-csr -s 22"
#BENCH_RUN="./omp-csr -s 20" #1GB memory
#BENCH_RUN="./omp-csr -s 21" #1.4GB memory
#BENCH_RUN="./omp-csr -s 22 -o edge-22 -r roots-22" #3.6GB memory
#BENCH_RUN="./omp-csr -s 23 -e 28" # 7.7GB memory
#BENCH_RUN="./omp-csr -s 24 -e 29" # 15.2GB memory, 5 min
#BENCH_RUN="./omp-csr -s 26 -e 17" # 38GB memory, 5 min


if [[ "x${BENCH_SIZE}" == "x4GB"  ]]; then
# 7.6GB, 3 mins
BENCH_RUN="./omp-csr -s 22 -e 29" # 7.7GB memory
elif [[ "x${BENCH_SIZE}" == "x8GB"  ]]; then
# 7.6GB, 3 mins
BENCH_RUN="./omp-csr -s 23 -e 28" # 7.7GB memory
elif [[ "x${BENCH_SIZE}" == "x16GB"  ]]; then
# 15.4GB, 3 mins
BENCH_RUN="./omp-csr -s 24 -e 29" # 15.2GB memory, 5 min
elif [[ "x${BENCH_SIZE}" == "x30GB"  ]]; then
# 15.4GB, 3 mins
BENCH_RUN="./omp-csr -s 25 -e 28" # 32GB memory, 5 min
elif [[ "x${BENCH_SIZE}" == "x30GB_SMALL"  ]]; then
# 15.4GB, 3 mins
BENCH_RUN="./omp-csr -s 25 -e 28" # 32GB memory, 5 min
elif [[ "x${BENCH_SIZE}" == "x30GB_LONG"  ]]; then
# 15.4GB, 3 mins
BENCH_RUN="./omp-csr -s 25 -e 28" # 32GB memory, 5 min
elif [[ "x${BENCH_SIZE}" == "x32GB"  ]]; then
# 15.4GB, 3 mins
BENCH_RUN="./omp-csr -s 25 -e 29" # 32GB memory, 5 min
elif [[ "x${BENCH_SIZE}" == "x40GB"  ]]; then
# 37.4GB, 3 mins
BENCH_RUN="./omp-csr -s 25 -e 36" # 38GB memory, 5 min
elif [[ "x${BENCH_SIZE}" == "x16GB_SB"  ]]; then
# 15.4GB, 3 mins
BENCH_RUN="./omp-csr -s 24 -e 29" # 15.2GB memory, 5 min
else
# 37.4GB, 3 mins
BENCH_RUN="./omp-csr -s 25 -e 36" # 38GB memory, 5 min
fi

#BENCH_RUN="./omp-csr -s 25 -e 29" # 32GB memory, 5 min
#BENCH_RUN="./omp-csr -s 25 -e 36" # 38GB memory, 5 min
#BENCH_RUN="./omp-csr -s 24"
#BENCH_RUN="./omp-csr -s 24 -o edge -r roots"

#${BENCH_RUN} &>/dev/null
#echo ${CPUID} ${BENCH_NAME}
