## Overview

Slurm overview: https://slurm.schedmd.com/overview.html

> Slurm is an open source, fault-tolerant, and highly scalable cluster management and job scheduling system for large and small Linux clusters. Slurm requires no kernel modifications for its operation and is relatively self-contained. As a cluster workload manager, Slurm has three key functions. First, it allocates exclusive and/or non-exclusive access to resources (compute nodes) to users for some duration of time so they can perform work. Second, it provides a framework for starting, executing, and monitoring work (normally a parallel job) on the set of allocated nodes. Finally, it arbitrates contention for resources by managing a queue of pending work. Optional plugins can be used for accounting, advanced reservation, gang scheduling (time sharing for parallel jobs), backfill scheduling, topology optimized resource selection, resource limits by user or bank account, and sophisticated multifactor job prioritization algorithms.

This guide provides the steps to install a slurm controller node as well as a single compute node.  
The following steps make the follwing assumptions.
* OS: Ubuntu 16.04
* Slurm controller node hostname: slurm-ctrl
* Non-root user: myuser
* Compute node hostname: linux1
* Slurm DB Password: slurmdbpass
* Passwordless SSH is working between slurm-ctrl and linux1
* There is shared storage between all the nodes: /storage & /home
* The UIDs and GIDs will be consistent between all the nodes.
* Slurm will be used to control SSH access to compute nodes.
* Compute nodes are DNS resolvable.

The slurm controller node (slurm-ctrl) does not need to be a physical piece of hardware.  A VM is fine.  However, this node will be used by users for compiling codes and as such it should have the same OS and libraries (such as CUDA) that exist on the compute nodes.

## Install slurm and associated components on slurm controller node.
Install prerequisites 
```console
$ apt-get update
$ apt-get install gcc make ruby ruby-dev libpam0g-dev libmariadb-client-lgpl-dev libmysqlclient-dev
$ gem install fpm
$ cd /storage
$ git clone https://github.com/mknoxnv/ubuntu-slurm.git
```

Customize slurm.conf with your slurm controller and compute node hostnames:
```console
$ vi ubuntu-slurm/slurm.conf
ControlMachine=slurm-ctrl
NodeName=linux1 (you can specify a range of nodes here, for example: linux[1-10])
```


### Install munge
MUNGE (MUNGE Uid 'N' Gid Emporium) is an authentication service for creating and validating credentials.
https://dun.github.io/munge/
```console
$ apt-get install libmunge-dev libmunge2 munge
$ dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
$ chown munge:munge /etc/munge/munge.key
$ chmod 400 /etc/munge/munge.key
$ systemctl enable munge
$ systemctl start munge
```

### Test munge
```console
$ munge -n | unmunge | grep STATUS
STATUS:           Success (0)
```

### Install MariaDB for Slurm accounting
MariaDB is an open source Mysql compatible database.
https://mariadb.org/

In the following steps change the DB password "slurmdbpass" to something secure.
```console
$ apt-get install mariadb-server
$ mysql -u root
create database slurm_acct_db;
create user 'slurm'@'localhost';
set password for 'slurm'@'localhost' = password('slurmdbpass');
grant usage on *.* to 'slurm'@'localhost';
grant all privileges on slurm_acct_db.* to 'slurm'@'localhost';
flush privileges;
exit
```

### Download, build, and install Slurm
Download tar.bz2 from https://www.schedmd.com/downloads.php to /storage

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

Copy into place config files from this repo which you've already cloned into /storage
$ cd /storage
$ cp ubuntu-slurm/slurmdbd.service /lib/systemd/system/
$ cp ubuntu-slurm/slurmctld.service /lib/systemd/system/

Edit /storage/ubuntu-slurm/slurm.conf and replace AccountingStoragePass=slurmdbpass with the DB password 
you used in the above SQL section.
$ cp ubuntu-slurm/slurm.conf /etc/slurm/

Edit /storage/ubuntu-slurm/slurmdbd.conf and replace StoragePass=slrumdbpass with the DB password you used
in the above SQL section.
$ cp ubuntu-slurm/slurmdbd.conf /etc/slurm/

$ systemctl daemon-reload
$ ln -s /var/run/mysqld/mysqld.sock /tmp/mysql.sock
$ systemctl enable slurmdbd
$ systemctl start slurmdbd
$ systemctl enable slurmctld
$ systemctl start slurmctld
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite      0    n/a
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
$ systemctl enable munge
$ systemctl start munge
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
$ cp /storage/ubuntu-slurm/slurm.conf /etc/slurm/slurm.conf
$ cp /storage/ubuntu-slurm/slurmd.service /lib/systemd/system/

If necessary modify gres.conf to reflect the properties of this compute node.
$ cp /storage/ubuntu-slurm/gres.conf /etc/slurm/gres.conf
$ cp /storage/ubuntu-slurm/cgroup.conf /etc/slurm/cgroup.conf
$ useradd slurm
$ mkdir -p /var/spool/slurm/d
$ systemctl enable slurmd
$ systemctl start slurmd
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite      1   idle linux1
```

### Set up cgroups
Using memory cgroups to restrict jobs to allocated memory resources requires setting kernel parameters
```console
$ vi /etc/default/grub
GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"
$ update-grub
$ reboot
```

## Finish Slurm configuration on slurm-ctrl
```console
$ sacctmgr add cluster compute-cluster
$ sacctmgr add account compute-account description "Compute accounts" Organization=OurOrg
$ sacctmgr create user myuser account=compute-account adminlevel=None
```

## Run a job from slurm-ctrl
```console
$ su - myuser
$ srun -N 1 hostname
linux1
```

## Enable Slurm PAM SSH Control
This prevents users from ssh-ing into a compute node on which they do not have an allocation.

On the compute nodes:
```console
$ cp /storage/slurm-17.02.6/contribs/pam/.libs/pam_slurm.so /lib/x86_64-linux-gnu/security/
$ vi /etc/pam.d/sshd
account    required     /lib/x86_64-linux-gnu/security/pam_slurm.so
```

On slurm-ctrl as non-root user
```console
$ ssh linux1 hostname
Access denied: user myuser (uid=1000) has no active jobs on this node.
Connection to linux1 closed by remote host.
Connection to linux1 closed.
$ salloc -N 1 -w linux1
$ ssh linux1 hostname
linux1
```

## Allow slurm to set NV_GPU
This plugin will copy the value of the CUDA_VISIBLE_DEVICES environment variable to NV_GPU.  NV_GPU is used by nvidia-docker to determine which GPUs a docker container can access.

On slurm-ctrl:
```console
$ cd /storage/ubuntu-slurm
$ gcc -fPIC -shared -o nvdocker-plugin.so nvdocker-plugin.c
$ cp nvdocker-plugin.so /usr/lib/slurm/
$ systemctl restart slurmctld
```

On the compute nodes:
```console
$ cp /storage/ubuntu-slurm/nvdocker-plugin.so /usr/lib/slurm/
$ systemctl restart slurmd
```




