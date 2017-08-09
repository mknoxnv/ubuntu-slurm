## Overview

Slurm overview: https://slurm.schedmd.com/overview.html

> Slurm is an open source, fault-tolerant, and highly scalable cluster management and job scheduling system for large and small Linux clusters. Slurm requires no kernel modifications for its operation and is relatively self-contained. As a cluster workload manager, Slurm has three key functions. First, it allocates exclusive and/or non-exclusive access to resources (compute nodes) to users for some duration of time so they can perform work. Second, it provides a framework for starting, executing, and monitoring work (normally a parallel job) on the set of allocated nodes. Finally, it arbitrates contention for resources by managing a queue of pending work. Optional plugins can be used for accounting, advanced reservation, gang scheduling (time sharing for parallel jobs), backfill scheduling, topology optimized resource selection, resource limits by user or bank account, and sophisticated multifactor job prioritization algorithms.

This guide provides the steps to install a slurm controller node as well as a single compute node.  
For simplicity sake a few assumptions have been made.  
* Slurm controller node hostname: slurm-ctrl
* Compute node hostname: linux1
* Slurm DB Password: slurmdbpass
* Passwordless SSH is working between slurm-ctrl and linux1
* There is shared storage between all the nodes: /storage & /home
* The UIDs and GIDs will be consistent between all the nodes.

## Install slurm and associated components on slurm controller node.
Install prerequisites 
```console
apt-get update
apt-get install gcc make
```

## Install munge
MUNGE (MUNGE Uid 'N' Gid Emporium) is an authentication service for creating and validating credentials.
https://dun.github.io/munge/
```console
$ apt-get install libmunge-dev libmunge2 munge
$ dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
$ chown munge:munge /etc/munge/munge.key
$ chmod 400 /etc/munge/munge.key
$ service munge start
```

## Test munge
```console
$ munge -n | unmunge | grep STATUS
STATUS:           Success (0)
```

## Install MariaDB for Slurm accounting
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

## Download and build Slurm
Download tar.bz2 from https://www.schedmd.com/downloads.php
Copy tar file to /storage
```console
$ cd /storage
$ tar xvjf slurm-17.02.6.tar.bz2
$ cd slurm-17.02.6
$ ./configure --prefix=/tmp/slurm-build --sysconfdir=/etc/slurm
$ make
$ make contrib
$ make install
```



