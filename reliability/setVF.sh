#!/bin/bash 
##########################################################################################
# this script is use to set source for vf
# Author : daining
# Date   : 2022.5.10
#*******************************************************************************
if [ "$#" != 2 ]; then
    echo -e "please input para dev,vf cnt \nexample: $0 nvme0"
    exit
fi

nvme_dev=$1
active_vf_cnt=$2

#set_vf_cnt=`nvme dapu set-sriov /dev/nvme0 -s 1 -n 8`
res_cnt=7

# shutoff sriov
echo 0 > /sys/class/nvme/${nvme_dev}/device/sriov_numvfs
sleep 5

###########################
# offline those online VFs 
online_ctls=($(nvme list-secondary /dev/${nvme_dev} | grep Online -B 2 | grep "Secondary Controller Identifier" | awk -F: '{print $3}'))
#online_ctls=`eval echo $online_ctrls`
echo "online ctrl num is $online_ctls"
for ctl in ${online_ctls[@]} 
do
    nvme virt-mgmt /dev/${nvme_dev} -c ${ctl} -a 7
done

for((i=1; i<=${active_vf_cnt};i++))
do
    nvme virt-mgmt /dev/${nvme_dev} -c $i -r 0 -n ${res_cnt} -a 8
    nvme virt-mgmt /dev/${nvme_dev} -c $i -r 1 -n ${res_cnt} -a 8
    nvme virt-mgmt /dev/${nvme_dev} -c $i -a 9
	echo "success set resource for ctrl $i"
done
nvme list-secondary /dev/${nvme_dev} -e $active_vf_cnt
sleep 3
echo ${active_vf_cnt} > /sys/class/nvme/${nvme_dev}/device/sriov_numvfs