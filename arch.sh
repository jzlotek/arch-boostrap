#!/bin/bash

dialog --title "arch-bootstrap"  --yesno "Please make sure that your paritions are mounted on the live disk to \'/mnt\'\n\n Ready to start?" 10 40

if [[ $? == 1 ]]; then
    echo "Stopping bootstrap"
    exit 1;
fi


run_in_chroot() {
    arch-chroot /mnt

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

    ln -sf /usr/share/zoneinfo/"$selected_zone" /etc/localtime

    hwclock --systohc

    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
    echo 'LANG=en_US.UTF-8' >> /etc/locale.gen

    locale-gen

    echo 'arch' >> /etc/hostname

    echo '127.0.0.1	localhost' >> /etc/hosts
    echo '::1		localhost' >> /etc/hosts
    echo '127.0.1.1	arch.localdomain	arch' >> /etc/hosts

    passwd


    # check for intel/amd
    proc_type="$(lscpu | grep 'vendor_id')"

    if [[ $(proc_type) =~ /intel/i  ]]; then
        pacman -Sy intel-ucode grub
    else
        pacman -Sy amd-ucode grub
    fi

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch\ Linux
    grub-mkconfig -o /boot/grub/grub.cfg
    exit
}

#timedatectl set-ntp true
run_in_chroot
dialog --title "Running pacstrap" --infobox "Please wait while pactrap is being run" 10 40
pacstrap /mnt base base-devel dialog 1>&2


dialog --title "Running genfstab" --infobox "Please wait while fstab is being generated" 10 40
genfstab -U /mnt >> /mnt/etc/fstab

curl https://raw.githubusercontent.com/jzlotek/arch-bootstrap/master/archchroot.sh > /mnt/root/archchroot.sh
chmod +x /mnt/root/archchroot.sh

arch-chroot /mnt /root/archchroot.sh
