# betelgeuse-vboxtools
My attempt to write my own Vagrant for virtualbox. Manages multiple machines at once.

Table of Contents
=================

  * [VBoxTools](#vboxtools)
  * [Key concepts](#key-concepts)
  * [Usage](#usage)
    * [Create template](#create-template)
    * [Create group](#create-group)
    * [Useful tools](#useful-tools)
      * [machine-ssh.sh](#machine-sshsh)
      * [machine-run.sh](#machine-runsh)
      * [group-run.sh](#group-runsh)
      * [machine-exec.sh](#machine-execsh)
      * [group-exec.sh](#group-execsh)
      * [group-manage.sh](#group-managesh)
    * [Cleanup](#cleanup)

Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc)

# VBoxTools

Set of scripts that can create nad manage bunch of Virtualbox machines.
Makes repetitive tasks consisting of deleting a 'cluster' and bringing it 
back again a little easier. 

I use it when i want to test something new. Like some new hipster \[no/new\]sql
database. There usually is no point in starting only one instance of it.
Starting n instances on one laptop does not allow to check how it will work
in distributed environment. How to simulate latencies? Or how to check if
and how it is scalable? So I usually create N machines in Virtualbox
install new stuff in them and then play around. Killing machines, bringing 
them up or load testing. Virtualbox is very helpful in limiting machines
capabilities like IO/CPU/network. 

But it is so depressing to click through Virtualbox UI in order to create 
these machines configured them the way I like. What I like is:

 * All machines for particular test to be in one network
 * All machines should have internet access
 * All machines should be reachable from my host like there are in
    local network
 * Easy way of logging into those machines via ssh
 * A way to perform some simple operation on all machines at once
 * Creating new group of machines has to be a one step operation

# Key concepts

Scripts create and manage groups of machines. Groups are 
numbered from 1 to N. All machines have 2 network interfaces: NAT for 
internet access and one additional 'Host Only' that will be attached to 
network that will allow from one side host to see the machine and for the 
machine to see all other machines. Because host only networks in
Virtualbox are named vboxnetN, and the name cannot be changed I decided
that I'll stick with Virtualbox numeric naming convention. So all
machines from group X are attached to network vboxnetX, this network
will have address 10.10.X.0/24. Every machine will be named X_Machine_Y
where Y is a machine number in group. Its Ip address will be
10.10.X.Y. When creating the group apart from machines scripts will create 
and configure all necessary networks and dhcp servers. 

All machines are created from a template Machine. Scripts also
automate the process of template creation. Template goes to group '0'
and will use network vboxnet0. When you create a template vm and install
OS inside (currently Ubuntu Server) template has to be prepared for cloning. 
Template customization consists of: 
    
* disabling sudo password for sudousers, 
* uploading ssh keys, 
* configuring the additional interface for host only network to start up automatically
and get its ip address from dhcp server. 

When template machine gets cloned
scripts change the machine name and sets the static ip address for them.

# Usage

Scripts can be found in repo root. Clone the repo 
and put them somewhere. Later I'll make something with it ...
Let's name directory where these scripts lie as VBTHOME.

Before you start install Virtualbox. I use version 5.0.2.r102096. 
Verify it with:

```bash
VBoxManage -version
```

Scripts are for bash. Tested on Linux Mint 17.3.

## Create template

To create template issue:
```
$VBTHOME/template-create-vm.sh
```

It will create networks, machine, download ubuntu image and start it up
 in GUI mode. There ubuntu will start to install. This part has to be dome 
 manually. 
 
During Ubuntu installation use all the defaults. Name the user 'guestadmin', 
and remember the password. Just keep pressing 'Enter' all the time with these 
exceptions:
 * "Write the changes to disk and configure LVM" -> Choose 'Yes'
 * "Write the changes to disks" -> Choose 'Yes'
 * **REMEMBER TO Install OPENSSH SERVER when you will be asked for additional 
    software to install**

After installation of ubuntu, machine will reboot, log int it and:

```
sudo apt-get install build-essential dkms
```

This will install packages required for Virtualbox guest addons. Then in 
Virtualbox vindow menu choose devices/Insert Guest additions CD Image
and issue following commands:

```
sudo mount /dev/sr0 /media/cdrom
sudo /media/cdrom/VBoxLinuxAdditions.sh
sudo dhclient
```

It will mount the Guest iso, install additions. Dhcclient will bring 
host only network interface up, and from now on machine will be accesible 
from host. Additions are required to be able to detect what ip address 
was assigned to machine by Virtualbox dhcp server.

Then on your host do:

```
$VBTHOME/template-customize.sh
```

If you have locally ~/.ssh/id_rsa.pub it won't, but if you don't script will 
generate new ssh keys so you will be asked to choose location for it (leave default)
and password for the key - here  do as you wish. You will be asked to 
 give guestadmin password twice - once for first ssh login once for sudo.
 
After all that template is ready. You can test it by trying to login to the machine:

```
$VBTHOME/machine-ssh.sh Template
```

This should open ssh session without asking you for password.

## Create group

To create group of machines do:

```
$VBTHOME/group-create.sh 1 2
```

It will create 2 machines in group 1. To log into any of them use:

```bash
$VBTHOME/machine-ssh.sh 1_Machine_1
```

for first machine or:

```bash
$VBTHOME/machine-ssh.sh 1_Machine_2
```

For second machine.

If you want to resize the group 1:

```
$VBTHOME/group-create.sh 1 4
```

It will create 2 more machines in group 1, not 4. So this command adds 
machines to meet desired number. 

## Useful tools

### machine-ssh.sh

Is a simple script that starts ssh session to given Machine without 
the need to remember the IP address of the machine. Takes only one argument:
the machine name. 

### machine-run.sh

Script for issuing one command through ssh in that machine. 

```bash
$VBTHOME/machine-run.sh 1_Machine_2 ls -al /home
```

will do `ls -al /home` in second machine in group one.

### group-run.sh

Is a script for issuing same command on all machines in group.

```bash
$VBTHOME/machine-run.sh 1 all ls -al /home
```

will execute `ls -al /home` in all machines in group one. 

So first parameter is group number second can be either 
* 'all' - action is going to be performed on all machines in group
* N - number for one particular machine
* 1,4,3 - a list of machines in group where we want the command to be 
    execured. Order matters.


### machine-exec.sh

It runs script that exists locally on host with sudo privilege on given machine.

```bash
$VBTHOME/machine-exec.sh 1_Machine_2 ./path_to_some_script.sh arg1 arg2
```

It will copy script pointed by `./path_to_some_scr  ipt.sh` to second machine
(to folder `/home/guestadmin/.guest_scripts`)
in group one and execute it there as `sudo /home/guestadmin/.guest_scripts/path_to_some_script.sh arg1 arg2`.
 

### group-exec.sh

Simmilar to group-run but works like machine-exec.

```
$VBTHOME/group-exec.sh 1 all ./path_to_some_script.sh arg1 arg2
```

Where '1' and 'all' works in same manner as in group-run.

### group-manage.sh

Group manage can be used to manipulate Virtualbox machines through `VBoxManage`
command for all machines in group at once. 

```
$VBTHOME/group-manage.sh 1 all VBoxManage guestproperty enumerate _M_ 
```

First two arguments work as in all group-* commands, rest is a standard 
 list of VBoxManage arguments. The '\_M\_' argument will be substituted with
  machine name. That's because in different VBoxManage operation machine name 
   can occur in different places.
   
You can see how it is used in helper scripts `group-start.sh` and `group-stop.sh`,
   two scripts that start every machine in group and stop all machines.

## Cleanup

When done playing with machines script `$VBTHOME/group-delete.sh X` deletes all 
machines in group X. When you want to delete everything script `$VBTHOME/all-delete.sh`
deletes all machines all groups templates networks from Virtualbox installation.
Use with caution in deletes every machine, not only ones managed by these scripts!
