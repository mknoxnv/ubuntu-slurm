#!/bin/bash
SOCKETS=`lscpu | grep "Socket(s):"  | cut -d : -f 2 | awk '{print $1}'`
THREADSPERCORE=`lscpu | grep "Thread(s) per core:" | cut -d : -f 2 | awk '{print $1}'`
CORESPERSOCKET=`lscpu | grep "Core(s) per socket:" | cut -d : -f 2 | awk '{print $1}'`
echo ""$HOSTNAME"_CPU_LAYOUT:"
echo "    Sockets: \"$SOCKETS\""
echo "    CoresPerSocket: \"$CORESPERSOCKET\""
echo "    ThreadsPerCore: \"$THREADSPERCORE\""
COUNT="0"
echo ""$HOSTNAME"_GPU_AFFINITY:"
for i in `lspci | grep -i nvidia | awk '{print $1}' | cut -d : -f 1`
        do
        CPUAFFINITY=`cat /sys/class/pci_bus/0000:$i/cpulistaffinity`
        echo "    GPU"$COUNT": \"$CPUAFFINITY\""
        ((COUNT++))
        done
