## Overview

Slurm overview: https://slurm.schedmd.com/overview.html

> Slurm is an open source, fault-tolerant, and highly scalable cluster management and job scheduling system for large and small Linux clusters. Slurm requires no kernel modifications for its operation and is relatively self-contained. As a cluster workload manager, Slurm has three key functions. First, it allocates exclusive and/or non-exclusive access to resources (compute nodes) to users for some duration of time so they can perform work. Second, it provides a framework for starting, executing, and monitoring work (normally a parallel job) on the set of allocated nodes. Finally, it arbitrates contention for resources by managing a queue of pending work. Optional plugins can be used for accounting, advanced reservation, gang scheduling (time sharing for parallel jobs), backfill scheduling, topology optimized resource selection, resource limits by user or bank account, and sophisticated multifactor job prioritization algorithms.

This guide provides the steps to install a slurm controller node as well as a single compute node.  
The following steps make the follwing assumptions.
* OS: Ubuntu 16.04
* Slurm controller node hostname: slurm-ctrl
* Non-root user: nvidia
* Compute node hostname: linux1
* Slurm DB Password: slurmdbpass
* Passwordless SSH is working between slurm-ctrl and linux1
* There is shared storage between all the nodes: /storage & /home
* The UIDs and GIDs will be consistent between all the nodes.
* Slurm will be used to control SSH access to compute nodes.
* Compute nodes are DNS resolvable.

## Install slurm and associated components on slurm controller node.
Install prerequisites 
```console
$ apt-get update
$ apt-get install gcc make ruby ruby-dev libpam0g-dev libmariadb-client-lgpl-dev
$ gem install fpm
```

### Install munge
MUNGE (MUNGE Uid 'N' Gid Emporium) is an authentication service for creating and validating credentials.
https://dun.github.io/munge/
```console
$ apt-get install libmunge-dev libmunge2 munge
$ dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
$ chown munge:munge /etc/munge/munge.key
$ chmod 400 /etc/munge/munge.key
$ vi /etc/default/munge
OPTIONS="--force --key-file /etc/munge/munge.key --num-threads 1"
$ service munge start
```

### Test munge
```console
$ munge -n | unmunge | grep STATUS
STATUS:           Success (0)
```

### Install MariaDB for Slurm accounting
MariaDB is an open source Mysql compatible database.
https://mariadb.org/
```console
$ apt-get install mariadb-server
$ mysql -u root
create database slurm_acct_db;
create user 'slurm'@'localhost';
set password for 'slurm'@'localhost' = password('slrumdbpass');
grant usage on *.* to 'slurm'@'localhost';
grant all privileges on slurm_acct_db.* to 'slurm'@'localhost';
flush privileges;
exit
```

### Download, build, and install Slurm
Download tar.bz2 from https://www.schedmd.com/downloads.php

Copy tar file to /storage
```console
$ cd /storage
$ tar xvjf slurm-17.02.6.tar.bz2
$ cd slurm-17.02.6
$ ./configure --prefix=/tmp/slurm-build --sysconfdir=/etc/slurm --enable-pam --with-pam_dir=/lib/x86_64-linux-gnu/security/
$ make
$ make contrib
$ make install
$ cd ..
$ fpm -s dir -t deb -v 1.0 -n slurm-17.02.6 --prefix=/usr -C /tmp/slurm-build .
$ dpkg -i slurm-17.02.6_1.0_amd64.deb
$ useradd slurm 
$ mkdir -p /etc/slurm /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm
$ chown slurm /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm

Download slurmdbd.service slurmctld.service slurm.conf slurmdbd.conf from this git repo.
$ cp slurmdbd.service /lib/systemd/system/
$ cp slurmctld.service /lib/systemd/system/
$ cp slurm.conf /etc/slurm/
$ cp slurmdbd.conf /etc/slurm/
$ systemctl daemon-reload
$ ln -s /var/run/mysqld/mysqld.sock /tmp/mysqld.sock
$ systemctl enable slurmdbd
$ service slurmdbd start
$ systemctl enable slurmctld
$ service slurmctld start
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite      1    unk linux1
```
## Install slurm and associated components on a compute node.

### Install munge
MUNGE (MUNGE Uid 'N' Gid Emporium) is an authentication service for creating and validating credentials.
https://dun.github.io/munge/
```console
$ apt-get update
$ apt-get install libmunge-dev libmunge2 munge
$ scp slurm-ctrl:/etc/munge/munge.key /etc/munge/
$ chown munge:munge /etc/munge/munge.key
$ chmod 400 /etc/munge/munge.key
$ vi /etc/default/munge
OPTIONS="--force --key-file /etc/munge/munge.key --num-threads 1"
$ service munge start
```

### Test munge
```console
$ munge -n | unmunge | grep STATUS
STATUS:           Success (0)
$ munge -n | ssh slurm-ctrl unmunge | grep STATUS
STATUS:           Success (0)
```

### Install Slurm
```console
$ dpkg -i /storage/slurm-17.02.6_1.0_amd64.deb
$ mkdir /etc/slurm
$ scp slurm-ctrl:/etc/slurm/slurm.conf /etc/slurm/slurm.conf 
$ useradd slurm
$ mkdir -p /var/spool/slurm/d
$ systemctl start slurmd
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite      1   idle linux1
```

## Finish Slurm configuration
These commands are run on slurm-ctrl
```console
$ sacctmgr add cluster compute-cluster
$ sacctmgr add account compute-account description "Compute accounts" Organization=OurOrg
$ sacctmgr create user nvidia account=compute-account adminlevel=None
```

## Run a job from slurm-ctrl
```console
$ su - nvidia
$ srun -N 1 hostname
linux1
```







