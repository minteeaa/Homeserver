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

echo ">> lm-sensors"
sudo apt-get --assume-yes install lm-sensors
sudo sensors-detect --auto

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

echo ">> HD Parm"
sudo apt-get --assume-yes install hdparm

echo ">> MergerFS"
sudo apt-get --assume-yes install mergerfs

echo ">> Setup rootless docker user"
sudo groupadd docker
sudo usermod -aG docker $USER

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
echo "[!]"
echo " "
echo "To receive server notifications, please enter your email address that should receive notifications"
echo " "
echo "[!]"
read -p 'Enter email address to receive server notifications:' DEFAULTEMAIL
sudo sh -c "echo default:$DEFAULTEMAIL >> /etc/aliases"
## Get config file
sudo tee -a /etc/msmtprc &>/dev/null << EOF
# Set default values for all following accounts.
defaults
auth           on
tls            on
#tls_trust_file /etc/ssl/certs/ca-certificates.crt
#logfile        $HOME/docker/HOST/logs/msmtp.log
aliases        /etc/aliases
# smtp provider
account        default
host           mail.smtp2go.com
port           587
from           FROMADDRESS
user           SMTPUSER
password       SMTPPASS
EOF
# set SMTP server
echo "[!]"
echo "Add SMTP credentials"
echo "[!]"
echo "                                                            "
echo "Would you like to configure sending email now?"
echo "You need to have an smtp provider account correctly configured with your domain"
read -p "Do you have your smtp credentials on hand? (y/n) " answer
case ${answer:0:1} in
    y|Y )
    read -p "Enter SMTP server address (or hit ENTER for default: mail.smtp2go.com):" SMTPSERVER
    SMTPSERVER="${SMTPSERVER:=mail.smtp2go.com}"
    read -p "Enter SMTP server port (or hit ENTER for default:587):" SMTPPORT
    SMTPPORT="${SMTPPORT:=587}"
    read -p 'Enter SMTP username: ' SMTPUSER
    read -p 'Enter password: ' SMTPPASS
    read -p 'Enter the from emailaddress that will be shown as sender, for example username@yourdomain.com: ' FROMADDRESS
    sudo sed -i -e "s#mail.smtp2go.com#$SMTPSERVER#g" /etc/msmtprc
    sudo sed -i -e "s#587#$SMTPPORT#g" /etc/msmtprc
    sudo sed -i -e "s#SMTPUSER#$SMTPUSER#g" /etc/msmtprc
    sudo sed -i -e "s#SMTPPASS#$SMTPPASS#g" /etc/msmtprc
    sudo sed -i -e "s#FROMADDRESS#$FROMADDRESS#g" /etc/msmtprc
    echo "Done, now sending you a test email...." 
    echo " "
    echo "NOTE: if your SMTP server uses TLS over port 465 and not STARTTLS over 587" 
    echo "      you must add \"tls_starttls off\" to your /etc/msmtprc"
    echo "      and the following email test will most likely fail."
    echo " "
    printf "Subject: Your Homeserver is almost ready\nHello there, I am almost ready. I can send you emails now." | msmtp -a default $DEFAULTEMAIL
    echo "Email sent!" 
    echo "if an error appeared above, the email has not been sent and you made an error or did not configure your domain and smtp provider"
    ;;
    * )
        echo "Not configuring SMTP. Please manually enter your SMTP provider details in file /etc/msmtprc.." 
    ;;
esac

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
