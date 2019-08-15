#!/bin/bash
SOCKETS=`lscpu | grep "Socket(s):"  | cut -d : -f 2 | awk '{print $1}'`
THREADSPERCORE=`lscpu | grep "Thread(s) per core:" | cut -d : -f 2 | awk '{print $1}'`
CORESPERSOCKET=`lscpu | grep "Core(s) per socket:" | cut -d : -f 2 | awk '{print $1}'`
COUNT="0"
echo "Add lines between --- to gres.conf:"
echo "---"
for i in `lspci | grep -i nvidia | grep -v Audio | awk '{print $1}' | cut -d : -f 1`
        do
        CPUAFFINITY=`cat /sys/class/pci_bus/0000:$i/cpulistaffinity`
        echo "NodeName=$HOSTNAME Name=gpu File=/dev/nvidia"$COUNT" CPUs=$CPUAFFINITY"
        ((COUNT++))
        done

echo "---"
echo ""
echo "Add line to end of slurm.conf:"
echo "NodeName="$HOSTNAME" Gres=gpu:$COUNT Sockets=$SOCKETS CoresPerSocket=$CORESPERSOCKET ThreadsPerCore=$THREADSPERCORE State=UNKNOWN"
