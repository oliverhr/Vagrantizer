#!/bin/bash

# TODO: Add option to skip parts and a menu for run specific tasks

# ------------------------------
# Script colors
BG_YELLOW="\033[43m\033[30m"
BG_GREEN="\033[42m\033[30m"
BG_RED="\033[41m\033[30m"
COLOR_RESET="\033[m"

# Show a highlighted message
function hg_message() {
    echo " "
    echo -e "$BG_YELLOW $1 $COLOR_RESET"
    ask_to_continue
}

# Ask to continue
function ask_to_continue() {
    echo -n " To Exit script press X, or press ENTER to continue: "
    read action
    if [ "${action,,}" == "x" ]; then
        exit
    fi
    echo " "
}
# ------------------------------
E_FILEEXIST=88

ROOT_UID=0
E_NOTROOT=87
function check_privileges() {
    if [ "$UID" != "$ROOT_UID" ]; then
        echo 'Must run this script with Root privileges'
        exit $E_NOTROOT
    else
        echo 'Enough permission starting process'
    fi
}

function update_system() {
    apt-get update && apt-get upgrade -y
}

SUDO_FILE=/etc/sudoers.d/vagrant
function set_sudo() {
    if [ ! -f $SUDO_FILE ]; then
        apt-get install -y sudo
        touch $SUDO_FILE
        echo 'Defaults	env_keep="SSH_AUTH_SOCK"' >> $SUDO_FILE
        #echo '%admin ALL=(ALL) ALL' >> $SUDO_FILE
        #echo '%admin ALL=NOPASSWD: ALL' >> $SUDO_FILE
        echo 'vagrant ALL=NOPASSWD: ALL' >> $SUDO_FILE
    else
        echo 'File' $SUDO_FILE 'already exist'
    fi
}

function admin_group() {
    if [ $(getent group admin | grep -c '^admin:') == 0 ]; then
        groupadd admin
    fi
    usermod -a -G admin vagrant
}

function install_ruby() {
    apt-get install -y ruby ruby-dev rubygems
}

SSH_CONFIG_FILE=/etc/ssh/sshd_config
function install_ssh() {
    apt-get install -y openssh-client openssh-server
    if [ $(cat $SSH_CONFIG_FILE | grep -c '^UseDNS No') == 0 ]; then
        echo 'Use DNS no' >> $SSH_CONFIG_FILE
    fi
}

function install_puppet() {
    apt-get install -y puppet
}

function install_chef() {
    apt-get install -y chef
    echo -e '\nInstalling chef gems'
    gem install --no-rdoc --no-ri chef
}

SSH_DIR=/home/vagrant/.ssh
SSH_AUTHKEY=/home/vagrant/.ssh/authorized_keys
KEY_URL=https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
function vagrant_cert() {
    if [ ! -d $SSH_DIR ]; then
        mkdir $SSH_DIR
    fi

    wget --no-check-certificate -O $SSH_AUTHKEY $KEY_URL
    chmod 700 $SSH_DIR
    chmod 600 $SSH_AUTHKEY
    chown vagrant:vagrant -R $SSH_DIR
}

function remove_guestadditions() {
    apt-get remove -y virtualbox-guest-dkms virtualbox-guest-utils virtualbox-guest-x11
    apt-get remove -y virtualbox-ose-guest-x11
}

function prepare_to_compile() {
    apt-get install -y build-essential dkms
    apt-get install -y linux-headers-$(uname -r)
    apt-get autoremove -y
}


read -d '' grub <<EOF
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of options in this file, see:
# info -f grub -n 'Simple configuration'

GRUB_DEFAULT=0
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
EOF

function speed_grub() {
	# Remove 5s grub timeout to speed up booting
	cat <<< "$grub" > /etc/default/grub

    update-grub
}


function reboot_image() {
    shutdown -h -r now
}

EXE_VBOXLINUX=/media/cdrom/VBoxLinuxAdditions.run
function install_guestadditions() {
    if [ ! -d /media/cdrom ]; then
        mkdir /media/cdrom
    fi

    mount -t iso9660 -r /dev/cdrom /media/cdrom

    if [ -f $EXE_VBOXLINUX ]; then
        echo -e $BG_GREEN 'Installing VirtualBox Guest Additions' $COLOR_RESET
        $EXE_VBOXLINUX
    else
        echo -e $BG_RED $EXE_VBOXLINUX $COLOR_RESET '<-- Not Found\n'
        echo -n 'Insert Guest Additions CD and press ENTER to continue or press X to quit: '
        read action

        if [ "${action,,}" == "x" ]; then
            echo -e '\nTo install manually VirtualBox Guest Additions try to run this commands after inserting Guest Addittions CD: \n'
            echo -e '\t 1)' 'mount -t iso9660 -r /dev/cdrom /media/cdrom'
            echo -e '\t 2)' $EXE_VBOXLINUX
            echo -e '\nThen restart the machine.\n'
            exit $E_FILEEXIST
        else
            install_guestadditions
        fi
    fi
}

# Execute functions
hg_message 'Starting Vagrantization ...'
check_privileges
update_system

hg_message 'Install sudo and set permissions'
set_sudo
admin_group

hg_message 'Install ruby'
install_ruby

hg_message 'Install SSH'
install_ssh

hg_message 'Install puppet'
install_puppet

hg_message 'Install Chef'
install_chef

hg_message 'Install Vagrant SSH certificate'
vagrant_cert

hg_message 'Removing Guest Addittions'
remove_guestadditions

hg_message 'Install Linux Headers and Compilers'
prepare_to_compile

hg_message 'Install GuestAdditions'
install_guestadditions

hg_message 'Reestart image'
speed_grub
reboot_image
