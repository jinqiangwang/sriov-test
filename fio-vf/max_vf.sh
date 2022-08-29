#!/bin/bash

new_vf_cnt=
nvme_dev=
example_str="example:\n\t $0 -d nvme0 -n 4\n"
nvme_cmd=${nvme_cmd-./nvme}
persist=""

while getopts "n:d:p" opt
do
    case $opt in 
    n)
        new_vf_cnt=$OPTARG
        ;;
    d)
        nvme_dev=$OPTARG
        ;;
    p)
        persist=" -s 1"
        ;;
    *)
        echo -e ${example_str}
        exit
    esac
done

if [[ -z "${nvme_dev}" ]] || [[ `ls /dev/${nvme_dev} > /dev/null 2>&1; echo $?` -ne 0 ]]
then
    echo -e "incorrect nvme dev name, please check dev name. \n${example_str}"
    exit
fi

source sriov-helper 

echo "dev: ${nvme_dev}; drive_cap_gb: ${drive_cap_gb}; hw_max_vf_cnt: ${hw_max_vf_cnt}; max_vf_cnt: ${max_vf_cnt}"
echo "Current VFs:"
grep . /sys/class/nvme/${nvme_dev}/device/sriov_*vfs
cur_max_vf=$(cat /sys/class/nvme/${nvme_dev}/device/sriov_totalvfs)

if [ -z ${hw_max_vf_cnt} ]
then
    echo "please check if sr-iov is supported on ${nvme_dev}"
    exit
fi

if [[ -z "${new_vf_cnt}" ]] || [[ $((${new_vf_cnt})) -le 0 ]] || [[ ${new_vf_cnt} -gt 32 ]]
then
    echo -e "incorrect max VF count, it needs to be in [0, 32]. \n${example_str}"
    exit
fi

detach_all_ns ${nvme_dev}
# delete_all_ns ${nvme_dev}
offline_all_vf ${nvme_dev}

# disable all VF
switch_vf ${nvme_dev} 0

result=$(${nvme_vu} dapu set-sriov /dev/${nvme_dev} -n ${new_vf_cnt} ${persist} 2>&1)
echo ${result}

if [[ ! -z "`echo ${result} | grep -i fail`" ]] && [[ ${new_vf_cnt} -gt ${cur_max_vf} ]]
then
    echo "please add command option -p and try again. after set this new number you may need to power cycle the server for the new VF count [new_vf_cnt] to take effect"
fi

# run subsystem-reset to make new max VF count effective
nvme subsystem-reset /dev/${nvme_dev}

sleep 1
echo "New VFs:"
grep . /sys/class/nvme/${nvme_dev}/device/sriov_*vfs