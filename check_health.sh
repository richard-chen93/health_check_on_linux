#!/bin/bash

##---------- Author : Zhengang.chen ----------------------------------------------------##
##---------- Github page : https://github.com/richard-chen93/health_check_on_linux ------------##
##---------- Purpose : To quickly check and report health status in a linux system.----------##
##---------- Tested on : Centos7. May work on other linux distributions as well.-------------## 
##---------- Updated version : v0.1 (Updated on 14th Feb 2021) ------------------------------##

set -u

#显示操作系统基本信息
function sysinfo {
    echo -e "
#####################################################################
    Health Check Report (CPU、Memory、Disk、IO、Network、Middleware)
#####################################################################

Hostname         : `hostname`
Linux Version    : `cat /etc/redhat-release `
Uptime           : `uptime | sed 's/.*up \([^,]*\), .*/\1/'`
Last Reboot Time : `who -b | awk '{print $3,$4}'`
Report Time      : `date`
" 
}

#检测cpu
function check_cpu {

echo "Cpu Name       :`cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq` " #cpu type
echo "Cpu Count      : `cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l` " #physical cpu number
echo "Cores Per Cpu  : `cat /proc/cpuinfo| grep "cpu cores"| uniq |awk '{print $4}'`"  #cores of each cpu
echo -e " \n "
#使用列表for循环采集5次cpu使用情况。
for variable  in 1 2 3 4 5
do
    cpu_us=`top -bn 1 | grep 'Cpu(s)' | awk -F'[" "%]+' '{print $3}'`
    cpu_sy=`top -bn 1 | grep 'Cpu(s)' | awk -F'[" "%]+' '{print $5}'`
    io_wait=`top -bn 1 | grep 'Cpu(s)' | awk -F',' '{print $5}'`
    load_average=`top -bn 1 | head -n 1 | awk -F'  ' '{print $4}'`
    cpu_sum=$(echo "($cpu_us+$cpu_sy)")
    nowdate=$(date | awk -F' ' '{print $5}')
    echo "$nowdate Usage: $cpu_sum% Io_wait:$io_wait $load_average"
done
}

#检测内存
function check_mem {
    InfoFile="/proc/meminfo"
    [[ -f $InfoFile ]] || { echo "$InfoFile not exist,please check"; exit 124; }
    TotalMem="$(grep '^MemTotal:' /proc/meminfo|grep  -o '[0-9]\{1,\}')"
    BuffersMem="$(grep '^Buffers:' /proc/meminfo|grep  -o '[0-9]\{1,\}')"
    CachedMem="$(grep '^Cached:' /proc/meminfo|grep  -o '[0-9]\{1,\}')"
    FreeMem="$(grep '^MemFree:'  /proc/meminfo|grep  -o '[0-9]\{1,\}')"
    RealFreeMem=`expr $FreeMem + $CachedMem + $BuffersMem`
    RealUsedMem=`expr $TotalMem - $RealFreeMem`
    nowdate=$(date +"%Y-%m-%d %H:%M:%S")
    mem_usage=`echo -e "${RealUsedMem}\t${TotalMem}"|awk '{printf "%2.2f\n",$1/$2*100}'`
    ALLMEM=`free -m | head -2 | tail -1| awk '{print $2}'`
    echo -e "MemSize:           $ALLMEM M"
    echo -e "Mem_Utilization:   $mem_usage%"
}

#检查磁盘分区使用率
function check_disk {
    df -TH | grep -v 'tmpfs' | grep -v 'devtmpfs'
}

function check_io {
    IOSTAT=`which iostat`
    IOSTAT=$?
    if [ $IOSTAT != 0 ];then
        echo "sysstat is not installed. Please run 'sudo yum install sysstat'"
    else
    iostat -d -x -k 1 5 > /tmp/tmp_iostat.log
    echo "`grep -v Linux  /tmp/tmp_iostat.log  | awk '{print $1,$11,$12,$13,$14}' | column -t`"
    fi
}

#检查网络
function check_network {
    SAR=`which sar`
    SAR=$?
    if [ $SAR != 0 ];then
        echo "sysstat is not installed. Please run 'sudo yum install sysstat'"
    else
    sar -n DEV 1 3 > /tmp/tmp_sar.log
    echo "`grep -v Linux /tmp/tmp_sar.log  | awk '{print $1,$2,$5,$6}' | column -t`"
    fi
}

#检查中间件
function check_middleware {
    echo -e "存在的端口："
    ss -tunpl | grep 2181 &>/dev/null && echo "Zookeeper:2181"
    ss -tunpl | grep 9092 &>/dev/null && echo "Kafka:9092"
    ss -tunpl | grep 9200 &>/dev/null && echo "ElasticSearch:9200"
    ss -tunpl | grep 3306 &>/dev/null && echo "Mysql:3306 "
    
    echo -e "\nES集群和索引状态(若存在)："
    curl http://localhost:9200/_cluster/health?pretty | grep green &>/dev/null && echo "ES cluster status: green" || echo "error: ES cluster has problems, check it out ! "
    curl http://localhost:9200/_cat/indices?v | grep -v green &>/dev/null && echo "ES index status: green" || echo "error: ES index has problems, check it out ! "

    echo -e " \n其他组件查看："
    echo -e "Kafka需要指定安装路径，查看消费堆积情况需要指定消费者组名"
    echo -e "查看正在运行的消费者组：./kafka-consumer-groups.sh --bootstrap-server {ip}:9092 --list --new-consumer "
    echo -e "消费堆积情况查看：./kafka-consumer-groups.sh --bootstrap-server {ip}:9092 --describe --group {group name} "
    echo -e "Aerospike检查需通过web客户端查看，重点查看集群颜色状态、节点和namespace信息，关注内存和磁盘使用率。"
    echo -e "Mysql检查需要登录mysql，执行命令show processlist，查看TIME列，若有几千毫秒数值，需要进一步排查。 "
    
}

#检查应用
function check_app {
    echo -e "检查应用错误日志:\n进入应用所在目录，查看各应用日志。命令格式：cat app.log |grep -E ‘error|exception’ "
    echo -e "\n检查近7日的业务调用量统计:\n使用web浏览器打开产品的风险大盘页面进行最近7日的业务调用量的记录 "
    echo -e "\n检查系统License过期时间:\n使用web浏览器登录超级管理员，找到系统设置菜单，打开后在页面上查看license过期时间，并将过期时间记录到excel中 "
}

#汇聚所有检测内容
function check_OS {
    sysinfo
    echo -e "\n\n--------------------------cpu----------------------------------"
    check_cpu
    echo -e "\n\n--------------------------memory-------------------------------"
    check_mem
    echo -e "\n\n--------------------------disk---------------------------------"
    check_disk
    echo -e "\n\n--------------------------io-----------------------------------"
    check_io
    echo -e "\n\n--------------------------network------------------------------"
    check_network
    echo -e "\n\n--------------------------Middleware---------------------------"
    check_middleware
    echo -e "\n\n--------------------------app------------------------------"
    check_app
}

#输出检测报告到当前目录，文件名以.txt结尾
FILENAME="health-`hostname`-`date +%y%m%d`-`date +%H%M`.txt"
check_OS > $FILENAME
