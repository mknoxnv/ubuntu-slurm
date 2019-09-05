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
* Compute nodes have GPUs and the latest CUDA drivers installed

The slurm controller node (slurm-ctrl) does not need to be a physical piece of hardware.  A VM is fine.  However, this node will be used by users for compiling codes and as such it should have the same OS and libraries (such as CUDA) that exist on the compute nodes.

## Install slurm and associated components on slurm controller node.
Install prerequisites 

Ubuntu 16.04
```console
$ apt-get update
$ apt-get install git gcc make ruby ruby-dev libpam0g-dev libmariadb-client-lgpl-dev libmysqlclient-dev
$ gem install fpm
```
Ubuntu 14.04
```console
$ apt-get update
$ apt-get install git gcc make ruby ruby-dev libpam0g-dev libmariadbclient-dev
$ gem install fpm
```


### Copy git repo
```console
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

Ubuntu 16.04
```console
$ apt-get install libmunge-dev libmunge2 munge
$ systemctl enable munge
$ systemctl start munge
```

Ubuntu 14.04
```console
$ apt-get install libmunge-dev libmunge2 munge
$ create-munge-key
$ update-rc.d munge enable
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

In the following steps change the DB password "slurmdbpass" to something secure.

Ubuntu 16.04
```console
$ apt-get install mariadb-server
$ systemctl enable mysql
$ systemctl start mysql
$ mysql -u root
create database slurm_acct_db;
create user 'slurm'@'localhost';
set password for 'slurm'@'localhost' = password('slurmdbpass');
grant usage on *.* to 'slurm'@'localhost';
grant all privileges on slurm_acct_db.* to 'slurm'@'localhost';
flush privileges;
exit
```

Ubuntu 14.04
```console
$ apt-get install mariadb-server
$ update-rc.d mysql enable
$ service mysql start
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
$ wget https://download.schedmd.com/slurm/slurm-17.11.12.tar.bz2
$ tar xvjf slurm-17.11.12.tar.bz2
$ cd slurm-17.11.12
$ ./configure --prefix=/tmp/slurm-build --sysconfdir=/etc/slurm --enable-pam --with-pam_dir=/lib/x86_64-linux-gnu/security/ --without-shared-libslurm
$ make
$ make contrib
$ make install
$ cd ..
$ fpm -s dir -t deb -v 1.0 -n slurm-17.11.12 --prefix=/usr -C /tmp/slurm-build .
$ dpkg -i slurm-17.11.12_1.0_amd64.deb
$ useradd slurm 
$ mkdir -p /etc/slurm /etc/slurm/prolog.d /etc/slurm/epilog.d /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm
$ chown slurm /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm
```

Ubuntu 16.04
```console
Copy into place config files from this repo which you've already cloned into /storage
$ cd /storage
$ cp ubuntu-slurm/slurmdbd.service /etc/systemd/system/
$ cp ubuntu-slurm/slurmctld.service /etc/systemd/system/
```

Ubuntu 14.04
```console
Copy into place config files from this repo which you've already cloned into /storage
$ cd /storage
$ cp ubuntu-slurm/slurmd.init /etc/init.d/slurmd
$ cp ubuntu-slurm/slurm.default /etc/default/slurm
$ chmod 755 /etc/init.d/slurmd
$ cp ubuntu-slurm/slurmdbd.init /etc/init.d/slurmdbd
$ chmod 755 /etc/init.d/slurmdbd
```

Ubuntu 16.04
```console
$ systemctl daemon-reload
$ systemctl enable slurmdbd
$ systemctl start slurmdbd
$ systemctl enable slurmctld
$ systemctl start slurmctld
```

Ubuntu 14.04
```console
$ update-rc.d slurmdbd start 20 3 4 5 . stop 20 0 1 6 .
$ update-rc.d slurmd start 20 3 4 5 . stop 20 0 1 6 .
$ service slurmdbd start
$ service slurmd start
```

## Create initial slurm cluster, account, and user.
```console
$ sacctmgr add cluster compute-cluster
$ sacctmgr add account compute-account description="Compute accounts" Organization=OurOrg
$ sacctmgr create user myuser account=compute-account adminlevel=None
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
```

Ubuntu 16.04
```console
$ systemctl enable munge
$ systemctl restart munge
```

Ubuntu 14.04
```console
$ update-rc.d munge enable
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
$ cp /storage/ubuntu-slurm/slurm.conf /etc/slurm/slurm.conf

If necessary modify gres.conf to reflect the properties of this compute node.
gres.conf.dgx is an example configuration for the DGX-1. 
Use "nvidia-smi topo -m" to find the GPU-CPU affinity.

The node-config.sh script will, if run on the compute node, output the appropriate lines to
add to slurm.conf and gres.conf.

$ cp /storage/ubuntu-slurm/gres.conf /etc/slurm/gres.conf
$ cp /storage/ubuntu-slurm/cgroup.conf /etc/slurm/cgroup.conf
$ cp /storage/ubuntu-slurm/cgroup_allowed_devices_file.conf /etc/slurm/cgroup_allowed_devices_file.conf
$ useradd slurm
$ mkdir -p /var/spool/slurm/d
```

Ubuntu 16.04
```console
$ cp /storage/ubuntu-slurm/slurmd.service /etc/systemd/system/
$ systemctl enable slurmd
$ systemctl start slurmd
```

Ubuntu 14.04
```console
$ cp /storage/ubuntu-slurm/slurmd.init /etc/init.d/slurmd
$ cp /storage/ubuntu-slurm/slurm.default /etc/default/slurm
$ chmod 755 /etc/init.d/slurmd
$ update-rc.d slurmd start 20 3 4 5 . stop 20 0 1 6 .
$ service slurmd start
```

## Test Slurm
```console
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

## Run a job from slurm-ctrl
```console
$ su - myuser
$ srun -N 1 hostname
linux1
```
## Run a GPU job from slurm-ctrl
```console
$ srun -N 1 --gres=gpu:1 env | grep CUDA
CUDA_VISIBLE_DEVICES=0
```

## Enable Slurm PAM SSH Control
This prevents users from ssh-ing into a compute node on which they do not have an allocation.

On the compute nodes:
```console
$ cp /storage/slurm-17.02.6/contribs/pam/.libs/pam_slurm.so /lib/x86_64-linux-gnu/security/
$ vi /etc/pam.d/sshd
account    required     /lib/x86_64-linux-gnu/security/pam_slurm.so
```

If you are using something such as LDAP for user accounts and want to allow local system 
accounts (for example, a non-root local admin account) to login without going through 
slurm make the following change.  Add this line to the beginning of the sshd file.

```console
$ vi /etc/pam.d/sshd
account    sufficient   pam_localuser.so
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




