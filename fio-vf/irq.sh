#!/bin/bash

function nvme_irq() {
    nvme_dev=$1
    nvme_dev=$(echo ${nvme_dev} | sed -r "s/(nvme[0-9]+).*/\1/g")
    if [[ -z "${nvme_dev}" ]] || [[ ! -c /dev/${nvme_dev} ]]
    then
        echo -e "usage: $0 nvme_dev\nexample: $0 nvme1"
        exit 1
    fi

    echo "irq affinity list for [$nvme_dev]"
    printf "%8s %8s %26s %18s %24s\n" "name" "irqid" "affinity_hint" "smp_affinity_list" "effective_affinity_list"
    for irq in $(grep ${nvme_dev}q /proc/interrupts | sed -r "s/^\s*([0-9]+):.*(nvme[0-9]+q[0-9]+)/\2,\1/g" | sort -V)
    do
        name=$(echo $irq | cut -d, -f1)
        id=$(echo $irq | cut -d, -f2)
        affinity_hint=/proc/irq/${id}/affinity_hint
        smp_affinity_list=/proc/irq/${id}/smp_affinity_list
        effective_affinity_list=/proc/irq/${id}/effective_affinity_list
        printf "%8s %8s %26s %18s %24s\n" $(echo ${name}) \
                                          $(echo ${id}) \
                                          $(cat ${affinity_hint}) \
                                          $(cat ${smp_affinity_list}) \
                                          $(if [ -f ${effective_affinity_list} ]; then cat ${effective_affinity_list}; fi) 
    done
}

function numa_of_nvme()
{
    nvme_dev=$1
    printf "%7s --> NUMA %2s\n" ${nvme_dev} `cat /sys/class/nvme/${nvme_dev}/device/numa_node`
}

dev_list=($1)

echo "[OS_info]"
cat /etc/centos-release
uname -r

echo""
echo "[CPU_NUMA]"
lscpu | grep NUMA
for dev in ${dev_list[@]}
do
    numa_of_nvme ${dev%n*}
done

echo""
echo "[nvme_irq]"
for dev in ${dev_list[@]}
do
    nvme_irq ${dev}
done

