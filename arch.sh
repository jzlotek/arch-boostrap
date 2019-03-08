#!/bin/bash
# Author: John Zlotek (gh:jzlotek)
# Version: 0.0.3
# Usage: Lazy install script for installing Arch Linux on a new machine.
#        Very basic right now and it might break existing system
#        configuration if not careful.

welcome() {
    pacman -S --needed --noconfirm git dialog
    if [[ $? != 0 ]]; then
        clear
        echo "Are you conected to the internet?"
        echo "Do you have sudo?"
        exit 1
    fi

    dialog --title "Welcome" --msgbox "This script is an automated Arch Linux bootstrapping script\n\nAn internet connection is needed to install Arch Linux" 10 40
    dialog --title "Confirmation"  --yes-label "Let's GO!" --no-label "Wait... Stop" --yesno "Please make sure that your paritions are mounted on the live disk to '/mnt'\n\n - Ready to start?" 10 40

    if (( $? == 1 )); then
        dialog --title "" --msgbox "Stopped bootstrap" 10 40
        clear
        exit 1
    fi
}

partition() {
    echo
}

partition_confirmation() {
    dialog --title "Partitioning" --yesno "Would you like to partition your drive?" 10 40 &&\
    (dialog --title "Confirmation"  --yes-label "Let's GO!" --no-label "Wait... Stop" --defaultno --yesno "Are you SURE?" 10 40 && partition) ||\
    dialog --title "Cancelled" --msgbox "You cancelled the partitioning. Hopefully you mounted your drives properly to '/mnt'" 10 40
}

set_timedate() {
    timedatectl set-ntp true
}

pactrap() {
    dialog --title "Running pacstrap" --infobox "Please wait while pactrap is being run" 10 40
    pacstrap /mnt base base-devel dialog 1>&2
}

fstab_gen() {
    dialog --title "Running genfstab" --infobox "Please wait while fstab is being generated" 10 40
    genfstab -U /mnt >> /mnt/etc/fstab
}

set_hostname() {
    hostname=$(dialog --title "Hostname" --inputbox "Please create your system's hostname" 10 40 "arch" 3>&1 1>&2 2>&3 3>&1)

    while [[ $hostname == "" ]]; do
        hostname=$(dialog --title "Hostname" --inputbox "Hostname cannot be blank" 10 40 "arch" 3>&1 1>&2 2>&3 3>&1)
    done

    echo "$hostname" > /etc/hostname

    echo '127.0.0.1	localhost' >> /mnt/etc/hosts
    echo '::1		localhost' >> /mnt/etc/hosts
    echo '127.0.1.1	'"$hostname"'.localdomain	'"$hostname" >> /mnt/etc/hosts
}

install_pacman() {
    dialog --title "Installing pacman Packages" --infobox "Installing \`$1\` ($n of $(($total))). \n\n - $2" 5 70
	arch-chroot /mnt pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

install_all_packages() {
    echo $(cat $1 | while read line; do echo "$line" | awk -F',' 'BEGIN { ORS="\n" }; {printf "%s %s 0 ", $1, $2}'; done) > /tmp/pac.tmp
    packages=$(dialog --title "Select packages" --checklist "Select packages that you wish to install" 40 80 40 --file /tmp/pac.tmp 3>&1 1>&2 2>&3 3>&1)

    total=$(echo $packages | awk -F " " '{for (i=1; i<=NF; i++) print $i}' | wc -l)

    n=1
    echo $packages | awk -F " " '{for (i=1; i<=NF; i++) print $i}' | while read line; do
        description=$(cat pacman.csv | grep "^$line," | awk -F"," '{print $2}' | sed s/\"//g)
        install_pacman "$line" "$description"
        n=$(($n+1))
    done
}

timezone() {
    time_zones=""
    ls /usr/share/zoneinfo | while read line; do
        if [[ -d /usr/share/zoneinfo/"$line" ]]; then
            ls /usr/share/zoneinfo/"$line" | while read subzone; do
                time_zones="$time_zones""\n""$line"'/'"$subzone";
            done
        else
            time_zones="$time_zones""\n""$line"
        fi
    done

    selected_zone=$(dialog --title "Time Zone selection" --radiolist "Select your time zone" 40 80 40 $(echo $time_zones | awk -F '\n' '{ if ($1) print $1, $1, "0" }') 3>&1 1>&2 2>&3 3>&1)

    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$selected_zone" /etc/localtime

    arch-chroot /mnt hwclock --systohc

    echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen
    echo 'LANG=en_US.UTF-8' >> /mnt/etc/locale.gen

    arch-chroot /mnt locale-gen
}

sudo_password(){

    p1=$(dialog --title "Sudo Password" --passwordbox "Please enter the sudo password for your system" 10 40 3>&1 1>&2 2>&3 3>&1)
    p2=$(dialog --title "Sudo Password" --passwordbox "Please enter the password again" 10 40 3>&1 1>&2 2>&3 3>&1)

    while [[ $p1 == "" || $p1 != $p2 ]]; do
        p1=$(dialog --title "Sudo Password" --passwordbox "Password mismatch or was empty. Please try again" 10 40 3>&1 1>&2 2>&3 3>&1)
        p2=$(dialog --title "Sudo Password" --passwordbox "Please enter the password again" 10 40 3>&1 1>&2 2>&3 3>&1)
    done

    (echo ${p1}; echo ${p2}) | arch-chroot /mnt passwd
}

create_user() {
    user=$(dialog --title "User" --inputbox "Please input a name for your user" 10 40 3>&1 1>&2 2>&3 3>&1)
    while [[ $user == "" ]]; do
        user=$(dialog --title "User" --inputbox "User's name cannot be blank. Please try again" 10 40 3>&1 1>&2 2>&3 3>&1)
    done

    selected_shell=$(dialog --title "Shell Selection" --radiolist "Please select a default shell for your user" 20 40 10 zsh "" 0 bash "" 0 oh-my-zsh "" 0 csh "" 0 tsch "" 0 fish "" 0 3>&1 1>&2 2>&3 3>&1)

    dialog --title "Shell installation" --infobox "Installing $selected_shell" 10 40

    arch-chroot /mnt pacman -S $selected_shell 1>&2

    arch-chroot /mnt useradd -m -G wheel -s /bin/$selected_shell $user 1>&2
}

arch_keyring() {
    arch-chroot /mnt pacman -S --noconfirm --needed archlinux-keyring
    #refresh keyring
    arch-chroot /mnt pacman -Syy
}

grub_install() {
    # check for intel/amd
    proc_type="$(lscpu | grep 'vendor_id')"

    if [[ $proc_type =~ /intel/i  ]]; then
        dialog --title "Grub Installation" --infobox "Intel Detected. Installing intel-ucode and grub" 10 40
        arch-chroot /mnt pacman -S --noconfirm --needed intel-ucode grub efibootmgr 1>&2
    elif [[ $proc_type =~ /amd/i ]]; then
        dialog --title "Grub Installation" --infobox "AMD Detected. Installing amd-ucode and grub" 10 40
        arch-chroot /mnt pacman -S --noconfirm --needed amd-ucode grub efibootmgr 1>&2
    else
        dialog --title "Grub Installation" --infobox "Unknown processor. Installing grub" 10 40
        arch-chroot /mnt pacman -S --noconfirm --needed grub efibootmgr 1>&2
    fi

    dialog --title "Grub Installation" --infobox "Configuring and installing grub to /boot" 10 40
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch\ Linux 1>&2
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 1>&2
}

completed() {
    dialog --title "Install complete!" --yes-label "chroot" --no-label "Reboot" --yesno "Would you like to chroot into your new arch installation or umount and reboot?" 10 40 && (clear && arch-chroot /mnt) || (umount -R /mnt && reboot)
}

main_install() {
    welcome
    partition_confirmation
    set_timedate
    pacstrap
    fstab_gen
    timezone
    set_hostname
    sudo_password
    create_user
    arch_keyring
    install_all_packages pacman.csv
    grub_install
    completed
}
create_user
exit
main_install

