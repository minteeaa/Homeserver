#!/bin/bash
# Aimed to be used on Debian-based servers, please don't assume this will run correctly on Arch.
echo ">> Add and update proper repositories for Docker"
sudo apt-get --assume-yes update
sudo apt-get --assume-yes install ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ">> Begin installing server utilities"
echo ">> Wireguard VPN Tools"
sudo apt-get --assume-yes install wireguard-tools

echo ">> BRTBK"
sudo apt-get --assume-yes install btrbk

echo ">> Run-if-today Cron Scheduling Helper"
sudo wget -O /usr/bin/run-if-today https://raw.githubusercontent.com/xr09/cron-last-sunday/master/run-if-today
sudo chmod +x /usr/bin/run-if-today
echo "<< Enable cron service" 
sudo systemctl enable --now cron.service

echo ">> Nocache"
sudo apt-get --assume-yes install nocache

echo ">> S.M.A.R.T. Monitoring Tools"
sudo apt-get --assume-yes install smartmontools

echo ">> Bleachbit"
sudo apt-get --assume-yes install bleachbit

echo ">> MergerFS"
sudo apt-get --assume-yes install hdparm

echo ">> Nocache"
sudo apt-get --assume-yes install mergerfs

echo ">> Setup rootless docker user"
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

echo ">> Install Docker Engine and Docker Compose"
sudo apt-get --assume-yes update
sudo apt-get --assume-yes install docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo ">> Enable docker service"
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

echo ">> Auto-restart VPN server"
sudo tee -a /etc/systemd/system/wgui.path << EOF
[Unit]
Description=Watch /etc/wireguard/wg0.conf for changes
[Path]
PathModified=/etc/wireguard/wg0.conf
[Install]
WantedBy=multi-user.target
EOF
# Restart wireguard service automatically
sudo tee -a /etc/systemd/system/wgui.service << EOF
[Unit]
Description=Restart WireGuard
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl restart wg-quick@wg0.service
[Install]
RequiredBy=wgui.path
EOF
# Apply services
sudo systemctl enable --now wgui.{path,service}

echo ">> Email Notifications"
sudo apt-get --assume-yes install msmtp
sudo apt-get --assume-yes install s-nail
# Link sendmail to msmtp
sudo ln -s /usr/bin/msmtp /usr/bin/sendmail
sudo ln -s /usr/bin/msmtp /usr/sbin/sendmail
# Set msmtp as mta
echo "set mta=/usr/bin/msmtp" | sudo tee -a /etc/mail.rc

echo ">> Disable os-prober"
# This prevents docker container volumes to be falsely recognized as host system OS and added to boot menu
sudo sed -i -e "s^GRUB_DISABLE_OS_PROBER=false^GRUB_DISABLE_OS_PROBER=true^g" /etc/default/grub
# Apply change
sudo grub-mkconfig

echo "<< Add root BTRFS mount to fstab"

if sudo grep -Fq "/mnt/drives/system" /etc/fstab; then echo fstab system mount exists;
else 
sudo mkdir -p /mnt/drives/system
fs_uuid=$(findmnt / -o UUID -n)
sudo tee -a /etc/fstab &>/dev/null << EOF

# Mount root subvolume manually
UUID=${fs_uuid} /mnt/drives/system  btrfs   subvolid=5,defaults,noatime,noauto  0  0
EOF
fi
sudo mount -a

echo "<< Create Docker subvolume, add to fstab"
sudo mount /mnt/drives/system
sudo btrfs subvolume create /mnt/drives/system/@docker
sudo umount /mnt/drives/system
mkdir $HOME/docker
fs_uuid=$(findmnt / -o UUID -n)
sudo tee -a /etc/fstab &>/dev/null << EOF

# Mount @docker subvolume
UUID=${fs_uuid} $HOME/docker  btrfs   subvol=@docker,defaults,noatime,x-gvfs-hide,compress-force=zstd:1  0  0
EOF
sudo mount -a
sudo chown ${USER}:${USER} $HOME/docker
sudo chmod -R 755 $HOME/docker

echo "<< Create folderstruct"
sudo mkdir /mnt/drives/{data0,data1}
sudo mkdir /mnt/drives/backup1
sudo mkdir -p /mnt/pool/

echo ">> Pullio"
# Auto update docker images
mkdir -p $HOME/docker/HOST/updater
sudo curl -fsSL "https://raw.githubusercontent.com/hotio/pullio/master/pullio.sh" -o $HOME/docker/HOST/updater/pullio
sudo chmod +x $HOME/docker/HOST/updater/pullio
sudo ln -s $HOME/docker/HOST/updater/pullio /usr/local/bin/pullio

echo "<< Grab necessary setup files from repo"
echo "..env"
wget -O $HOME/docker/.env https://raw.githubusercontent.com/minteeaa/homeserver/master/docker/.env
echo "..docker-compose"
wget -O $HOME/docker/docker-compose.yml https://raw.githubusercontent.com/minteeaa/homeserver/master/docker/docker-compose.yml

echo " "  
echo "  Done'd"
echo "  Please reboot and do *not* use sudo for docker or compose commands"
echo " "  
