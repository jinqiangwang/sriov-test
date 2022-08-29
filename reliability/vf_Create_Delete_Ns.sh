#! /bin/bash
##########################################################################################
# this script is use to multi ns test
# Author : daining
# Date   : 2022.5.10
#*******************************************************************************
#脚本参数说明:
#sn      : 盘片sn
#dev_pf  : PF 字符设备
#*******************************************************************************
#####  prepare log file

if [ $# -ne 1 ]; then 	
	echo -e "Please check and input parameter
	1 pf dev" 	
	exit 0	
else
	echo -e "test device sn is $1"
	dev_pf=$1	
fi

#fmt=$(python -c 'import random;list=["0","1"];print random.choice(list)')
#*******************************************************************************
#函数名称：ns_create_ave
#函数功能：创建指定N个均分大小ns, number:1-32
#输入参数：ns num
#输出参数: 
#*******************************************************************************	
function ns_create_ave()
{
	local ns_num=$1
	ns_crt_num=0
	echo -e "start to create random format vf ns" | tee -a $log_file
	for i in `seq 1 $ns_num`; do	
		num_blk=$(($size_cap/1000/1000/1000/$ns_num*1000*1000*1000/512))
		sleep 2
		
		echo "debug for create-ns $dev_pf --nsze=$num_blk --ncap=$num_blk --flbas=0"
		crt_ns=`nvme create-ns $dev_pf --nsze=$num_blk --ncap=$num_blk --flbas=0`
		
		if [ $? -ne 0 ]; then
			echo -e "create-ns failed..." | tee -a $log_file
			exit 1
		else
			echo -e "successful create-ns $i, the ns format is 0!" | tee -a $log_file
			ns_crt_num=$((ns_crt_num+1))
		fi
		sleep 1
		
	done
	echo -e "the tatol create ns num is $ns_crt_num!" | tee -a $log_file
}

#*******************************************************************************
#函数名称：ns_attach_ave
#函数功能：attach ns_create_ave函数创建的ns
#输入参数：默认ns_crt_num
#输出参数: 
#*******************************************************************************
function ns_attach_ave()
{
	for i in `seq 1 $ns_crt_num`; do
		att_ns=`nvme attach-ns $dev_pf -c $i -n $i`
		if [ $? -ne 0 ]; then
			echo -e "attach-ns failed..." | tee -a $log_file
			exit 1
		else
			echo -e "successful attach-ns to ctrl id:" $i | tee -a $log_file
		fi
		sleep 2
	done
}
#*******************************************************************************
#函数名称：ns_delete
#函数功能：一次删除所有待测盘片ns
#输入参数：
#输出参数: 
#*******************************************************************************
function ns_delete()
{
	nvme delete-ns $dev_pf -n 0xffffffff
	if [ $? -ne 0 ]; then
		echo -e "delete-ns failed..." | tee -a $log_file
		exit 1
	else
		echo -e "successful delete all ns " | tee -a $log_file
	fi

}

#############main test flow###############
size_cap=`nvme id-ctrl $dev_pf | grep 'tnvmcap' | awk -F ":" '{print $2}'`
for((i=0;i<50;i++));do
	ns_delete
	ns_create_ave 16
	ns_attach_ave

	pf_nvme=${dev_pf##*/}
	./setVF_res.sh $pf_nvme 16
done

