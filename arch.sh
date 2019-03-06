#!/bin/bash
dialog --title "Welcome" --msgbox "This script is an automated Arch Linux bootstrapping script\n\nAn internet connection is needed to install Arch Linux" 10 40
dialog --title "Confirmation"  --yes-label "Let's GO!" --no-label "Wait... Stop" --yesno "Please make sure that your paritions are mounted on the live disk to '/mnt'\n\n -Ready to start?" 10 40

if (( $? == 1 )); then
    dialog --title "" --msgbox "Stopped bootstrap" 10 40
    exit 1;
fi

install_pacman() {
	dialog --title "Installing pacman Packages" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

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
        pacman -S --noconfirm --needed intel-ucode grub
    else
        pacman -S --noconfirm --needed amd-ucode grub
    fi

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch\ Linux
    grub-mkconfig -o /boot/grub/grub.cfg
    exit
}

timedatectl set-ntp true

dialog --title "Running pacstrap" --infobox "Please wait while pactrap is being run" 10 40
pacstrap /mnt base base-devel dialog 1>&2


dialog --title "Running genfstab" --infobox "Please wait while fstab is being generated" 10 40
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt run_in_chroot
