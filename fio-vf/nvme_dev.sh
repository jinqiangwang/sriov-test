#!/bin/bash
#
# lspci -d1e3b: -v | grep -e NUMA -e Non-Vol | sed -r -e "s/(.*)\s+Non-Vol.*/\1/g" -e "s/.*NUMA node\s([0-9]+).*/\1/g" 
#

function nvme2busid_full() {
    drv_name=$1
    bdf=$(cat /sys/class/nvme/${drv_name%n*}/address)
    echo ${bdf}
}

function nvme2busid() {
    drv_name=$1
    bdf=$(nvme2busid_full ${drv_name})
    bdf=${bdf##*0000:}
    echo ${bdf}
}

function nvme2busid_spdk() {
    drv_name=$1
    bdf=$(nvme2busid ${drv_name})
    echo ${bdf/:/.}
}

function busid2lspci_vv() {
    bdf=$1
    if [ ! -z "${bdf}" ]
    then
        echo "$(lspci -s ${bdf} -vv)"
    else
        echo ""
    fi 
}

function lspci_vv2numa() {
    lspci_vv=$1
    if [ ! -z "${lspci_vv}" ]
    then
        echo $(echo "${lspci_vv}" | grep NUMA | sed -r "s/.*NUMA node:\s+([0-9]+).*/\1/g")
    else
        echo ""
    fi 
}

function busid2numa() {
    bdf=$1
    if [ ! -z "${bdf}" ]
    then
        echo $(lspci -s ${bdf} -v | grep NUMA | sed -r "s/.*NUMA node:\s+([0-9]+).*/\1/g")
    else
        echo ""
    fi 
}

function nvme2numa() {
    drv_name=$1
    bdf=$(nvme2busid ${drv_name})
    if [ ! -z "${bdf}" ]
    then
        echo $(busid2numa ${bdf})
    else
        echo ""
    fi    
}

function lspci_vv2desc() {
    lspci_vv=$1
    if [ ! -z "${lspci_vv}" ]
    then
        echo $(echo "${lspci_vv}" | grep "Non-Volatile" | cut -d: -f3-)
    else
        echo ""
    fi 
}

function busid2desc() {
    bdf=$1
    echo $(lspci -s ${bdf} | cut -d: -f3-)
}

function lspci_vv2lnksta() {
    lspci_vv=$1
    if [ ! -z "$(echo ${lspci_vv} | grep '\[virtual\]')" ]
    then
        echo "VF?"
    else
        echo $(echo "${lspci_vv}" | grep LnkSta: | sed -r "s/.*\s+([0-9]+GT).*,.*(x[0-9]+).*/\1+\2/g")
    fi 
}

function busid2lnksta() {
    bdf=$1
    lspci_vv=$(lspci -s ${bdf} -vv)
    if [ ! -z "$(echo ${lspci_vv} | grep '\[virtual\]')" ]
    then
        echo "VF"
    else
        echo $(echo "${lspci_vv}" | grep LnkSta: | sed -r "s/.*\s+([0-9]+GT).*,.*(x[0-9]+).*/\1+\2/g")
    fi
}

function lspci_vv2_mps_mrrs() {
    lspci_vv=$1
    if [ ! -z "${lspci_vv}" ]
    then
        echo $(echo "${lspci_vv}" | grep DevCtl: -A2 | grep MaxPayload | sed -r "s/\s+MaxPayload\s+([0-9]+)\s+.*MaxReadReq\s+([0-9]+)\s+.*/\1+\2/g")
    else
        echo ""
    fi 
}

function busid2_mps_mrrs() {
    bdf=$1
    echo $(lspci -s ${bdf} -vv | grep DevCtl: -A2 | grep MaxPayload | sed -r "s/\s+MaxPayload\s+([0-9]+)\s+.*MaxReadReq\s+([0-9]+)\s+.*/\1+\2/g")
}

function lspci_vv2is_phy_dev() {
    lspci_vv=$1
    if [ ! -z "${lspci_vv}" ]
    then
        echo $(echo "${lspci_vv}" | grep "\[virtual\]")
    else
        echo ""
    fi 
}

function nvmeblk_2_chardev()
{
    nvme_blk_dev=$1

    if [ -d /sys/block/${nvme_blk_dev}/device/device/physfn ]
    then 
        echo $(ls /sys/block/${nvme_blk_dev}/device/device/physfn/nvme)
    else
        echo $(ls /sys/block/${nvme_blk_dev}/device/device/nvme) 
    fi
}

function is_physical_dev() {
    bdf=$1
    phy_slot=$(lspci -s ${bdf} -v | grep "Physical Slot:")
    is_phy_slot=1
    if [ -z "${phy_slot}" ]
    then
        is_phy_slot=0
    fi
    echo ${is_phy_slot}
}

if [ ! -z "`nvme list | grep nvme`" ]
then
    # echo "drive,bdf,numa_node,lnksta,mps+mrrs,temp,desc"
    print_fmt="%9s%9s%6s%9s%12s%12s%10s%6s  %-s\n"
    printf "${print_fmt}" drive bdf numa lnksta mps+mrrs nr_requests phy_dev temp desc
    for nvme_dev in  `nvme list | sort -V | grep /dev/nvme | cut -d" " -f1`
    do 
        drv=${nvme_dev##*/}
        bdf=$(nvme2busid ${drv})
        if [ ! -z "${bdf}" ]
        then 
            temp=$(nvme smart-log /dev/${drv} | grep temperature |  sed -r "s/.*:\s*([0-9]+).*/\1/g")
            lspci_vv="$(lspci -s ${bdf} -vv)"
            numa_node=$(lspci_vv2numa "${lspci_vv}")
            lnksta=$(lspci_vv2lnksta "${lspci_vv}")
            max_mps_mrrs=$(lspci_vv2_mps_mrrs "${lspci_vv}")
            char_dev=$(nvmeblk_2_chardev ${drv})
            nr_request=$(cat /sys/block/${drv}/queue/nr_requests)
            desc=$(lspci_vv2desc "${lspci_vv}")
            # echo ${drv}, ${bdf}, ${numa_node}, ${lnksta}, ${max_mps_mrrs}, ${temp}, ${desc}
            printf "${print_fmt}" ${drv} ${bdf} ${numa_node} ${lnksta} ${max_mps_mrrs} "${nr_request}" "${char_dev}" "${temp}C" "${desc}"
        else
            echo "${drv},info not availble"
        fi
    done
else
    header="bdf,numa_node,lnksta,mps+mrrs,desc"
    # header=(bdf numa lnksta mps+mrrs desc)
    print_fmt="%9s%6s%9s%12s  %-s\n"
    printf "${print_fmt}" bdf numa lnksta mps+mrrs desc
    for pcie_dev in  `lspci | grep "Non-Volatile memory controller" | cut -d" " -f1`
    do
        bdf=${pcie_dev}
        lspci_vv="$(lspci -s ${bdf} -vv)"
        numa_node=$(lspci_vv2numa "${lspci_vv}")
        lnksta=$(lspci_vv2lnksta "${lspci_vv}")
        max_mps_mrrs=$(lspci_vv2_mps_mrrs "${lspci_vv}")
        desc=$(lspci_vv2desc "${lspci_vv}")
        if [ ! -z "${bdf}" ]
        then
            # echo ${bdf},${numa_node},${lnksta},${max_mps_mrrs},${desc}
            printf "${print_fmt}" ${bdf} ${numa_node} ${lnksta} ${max_mps_mrrs} "${desc}"
        fi
    done
fi