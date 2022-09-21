# <p align="center">**mint-server**</p>
### <p align="center">not really a guide, or a fully-fledged homeserver setup, but it works, and is 99% stable. and it's also my personal setup.</p>
### <p align="center">very large thanks to [zilexa](https://github.com/zilexa) and their [homeserver repo](https://github.com/zilexa/Homeserver), without it I  would not have set this up so easily. *this homeserver setup is heavily based off of the mentioned repository. if you use Arch, go check it out.*</p>

# **Info**
**this setup is not at all finished, and there will be more added to this repo as time goes on and I set up more parts of the homeserver.**

this is meant more to be a backup for the important parts in case I ever need it. any suggestions are welcome. 

## **OS**
- Debian based OS (my server uses [Ubuntu Server 22.04.1](https://ubuntu.com/download/server))
    - Using server with no DE as this is not a workstation for myself; it is simply a standalone server I can access through SSH
- BTRFS filesystem

## **Installation**
### **Installing the OS**
Install the OS of choice, in your own way or using a [bootable live environment](https://ubuntu.com/tutorials/create-a-usb-stick-on-windows#1-overview)

* Select BTRFS filesystem with **no swap**

### **Docker and other tools**
`cd` to a directory you like downloads to be in, and run the [setup script](https://github.com/minteeaa/Homeserver/blob/master/initialsetup.sh)
```
wget https://raw.githubusercontent.com/minteeaa/Homeserver/master/initialsetup.sh
bash initialsetup.sh
```
##### installs Docker using the repository method and by [abiding to the post-install docs](https://docs.docker.com/engine/install/linux-postinstall/)

***

### **Filesystem**
My homeserver follows [zilexa's folderstructure guidelines](https://github.com/zilexa/Homeserver/tree/master/filesystem) to this point, via *option 1* on the datapool guide.

*One slightly important note:* when using BTRFS to create subvolumes and mount them in `fstab`, using the subvolume name alone, e.g.
```
UUID=...      /mnt/pool/Media   btrfs   subvol=Media,defaults,noatime  0 0
``` 
*may not work* and will return a ` No such file or directory` error from `mount`. Unfortunately, this has been an ongoing issue with BTRFS on Ubuntu for a very long time.

To get around this, when creating a subvolume, check the ID of the created subvolume and use that in your `fstab`.
```
# sudo btrfs subvolume create /mnt/disks/data0/datastore
Create subvolume '/mnt/disks/data0/ncstore'
# sudo btrfs subvolume list /mnt/pool
ID 258 gen 115 top level 5 path mnt/disks/data0/datastore
```
`fstab`:
```
UUID=...      /mnt/pool/Media   btrfs   subvolid=258,defaults,noatime  0 0
```
Yes, this does make it a bit difficult to keep track of subvolume names, but this is how I found it simplest to fix this issue; and also consider these probably wont be changed after they're set.

***

### **Docker**
Once you've gone through the filesystem setup and you're ready to start your containers, step back and take a look through and/or edit [docker compose](https://github.com/minteeaa/Homeserver/blob/master/docker/docker-compose.yml) file and be sure to fill out the [.env](https://github.com/minteeaa/Homeserver/blob/master/docker/.env) to your liking. Certain containers *will not run* if you don't.

In no way do I consider myself an expert when it comes to the best practices of docker, but I will continue to make the best effort I can to adhere to them.

***

### **That can't be all, right?**
it absolutely isn't the end of this README. 

well, it is for right now.

fear not, the rest of the instruction *will be added soon.* i'm updating this repo as i build my homeserver, so it might be slow to properly document everything that needs to happen for setup.


