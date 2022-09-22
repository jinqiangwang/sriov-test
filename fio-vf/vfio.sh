#!/bin/bash

usage="invalid parameters provided. \nexample:\n\t $0 -d \"nvme0n1 nvme1n1\" [-b \"0-7 8-15\"] [-j job_cfg_file]\n"

export my_dir="$( cd "$( dirname "$0"  )" && pwd  )"
timestamp=`date +%Y%m%d_%H%M%S`
output_dir=${my_dir}/${timestamp}
job_cfg=""

# default values
disks=""
bind_list=""

while getopts "d:b:j:" opt
do
    case $opt in 
    d)
        disks=($OPTARG)
        ;;
    b)
        bind_list=($OPTARG)
        ;;
    j)
        job_cfg=($OPTARG)
        ;;
    *)
        echo -e ${usage}
        exit 1
    esac
done

if [ -z "${disks}" ]
then
    echo -e ${usage}
    exit 1
fi

if [ -z "${job_cfg}" ]
then
    job_cfg="job_config"
fi

echo ${my_dir}/${job_cfg}

source ${my_dir}/functions
source ${my_dir}/${job_cfg}
source ${my_dir}/nvme_dev.sh > /dev/null

fio_cmd="fio"
ld_preload=""
filename_format="/dev/%s"
nvme_dev_info=$(${my_dir}/nvme_dev.sh)

if [ ! -d "${output_dir}" ]; then mkdir -p ${output_dir}; fi
result_dir=${output_dir}/result
drvinfo_dir=${output_dir}/drvinfo
iolog_dir=${output_dir}/io_logs
iostat_dir=${output_dir}/iostat
mkdir -p ${result_dir}
mkdir -p ${drvinfo_dir}
mkdir -p ${iolog_dir}
mkdir -p ${iostat_dir}

echo -n "$(which ${fio_cmd}): "         > ${output_dir}/sysinfo.log
echo "version $(${fio_cmd} --version)" >> ${output_dir}/sysinfo.log
echo -e "$0 $@\n"                      >> ${output_dir}/sysinfo.log
echo "${nvme_dev_info}"                >> ${output_dir}/sysinfo.log
collect_sys_info                       >> ${output_dir}/sysinfo.log
cp ${my_dir}/${job_cfg} ${output_dir}/

test_disks=""

for disk in ${disks[@]}
do
    ls /dev/${disk} > /dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "${disk} does not exist, please check name"
        continue
    fi

    nvme_has_mnt_pnt ${disk}
    if [ $? -ne 0 ]
    then
        echo "${disk} is mounted or contains file system, skipping it for test"
        continue
    fi
    test_disks=(${test_disks[@]} ${disk})
done

disks=(${test_disks[@]})

if [ -z "${disks}" ]
then
    echo "no valid nvme drive for testing, please check provided parameters"
    exit 1
fi

bind_cnt=0
if [ ! -z ${bind_list} ]
then
    bind_cnt=${#bind_list[@]}
fi

for workload in ${workloads[@]}
do
    fio_pid_list=""
    i=0
    for disk in ${disks[@]};
    do
        bind_param=""
        if [ $i -lt $bind_cnt ]
        then
            bind_param="${bind_opt}=${bind_list[$i]}"
        fi
        export output_name=${iolog_dir}/${disk}_${workload}
        
        iostat_pids="${iostat_pids} $(start_iostat ${disk} ${workload} ${iostat_dir})"

        ${fio_cmd} --filename="$(printf "${filename_format}" ${disk})" \
            ${bind_param} \
            --output=${result_dir}/${disk}_${workload}.fio \
            ${my_dir}/jobs/${workload}.fio &
        fio_pid_list="${fio_pid_list} $!"
        i=$(($i+1))
    done

    wait ${fio_pid_list}
    if [ ! -z "${iostat_pids}" ]; then kill ${iostat_pids}; fi
    sync
done

for disk in ${disks[@]}
do
    iostat_to_csv ${iostat_dir}
    fio_to_csv ${result_dir} ${disk}
done

consolidate_summary ${result_dir} ${output_dir}