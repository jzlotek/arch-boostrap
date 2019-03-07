#!/bin/bash
dialog --title "Welcome" --msgbox "This script is an automated Arch Linux bootstrapping script\n\nAn internet connection is needed to install Arch Linux" 10 40
dialog --title "Confirmation"  --yes-label "Let's GO!" --no-label "Wait... Stop" --yesno "Please make sure that your paritions are mounted on the live disk to '/mnt'\n\n - Ready to start?" 10 40

if (( $? == 1 )); then
    dialog --title "" --msgbox "Stopped bootstrap" 10 40
    clear
    exit 1
fi

hostname() {
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
	dialog --title "Installing pacman Packages" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	arch-chroot /mnt pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

install_all_packages() {
    packages=$(dialog --title "Select packages" --checklist "Select packages that you wish to install" 40 80 40 --file pacman.packages 3>&1 1>&2 2>&3 3>%1)

    total=$(echo $packages | awk -F " " '{for (i=1; i<=NF; i++) print $i}' | wc -l)

    n=1
    echo $packages | awk -F " " '{for (i=1; i<=NF; i++) print $i}' | while read line; do
        install_pacman $line
        n=$(($n+1))
    done
}

main_install() {
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

    hostname

    clear
    echo 'Please set the root password now'
    arch-chroot /mnt passwd

    #refresh keyring
    arch-chroot /mnt pacman -S --noconfirm --needed archlinux-keyring
    arch-chroot /mnt pacman -Syy

    install_all_packages

    # check for intel/amd
    proc_type="$(lscpu | grep 'vendor_id')"

    if [[ $proc_type =~ /intel/i  ]]; then
        arch-chroot /mnt pacman -S --noconfirm --needed intel-ucode grub efibootmgr
    else
        arch-chroot /mnt pacman -S --noconfirm --needed amd-ucode grub efibootmgr
    fi

    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch\ Linux
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

timedatectl set-ntp true

dialog --title "Running pacstrap" --infobox "Please wait while pactrap is being run" 10 40
pacstrap /mnt base base-devel dialog

dialog --title "Running genfstab" --infobox "Please wait while fstab is being generated" 10 40
genfstab -U /mnt >> /mnt/etc/fstab

main_install

arch-chroot /mnt
