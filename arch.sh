#!/bin/bash
# Author: John Zlotek (gh:jzlotek)
# Version: 0.0.4
# Usage: Lazy install script for installing Arch Linux on a new machine.
#        Very basic right now and it might break existing system
#        configuration if not careful.

error() {
    echo $1
    echo "Check error.log for information about why it failed to install"
    exit 1
}

welcome() {
    pacman-key --init >/dev/null 2>error.log
    pacman-key --populate >/dev/null 2>error.log
    pacman-key --refresh-keys >/dev/null 2>error.log
    pacman -Sy --needed --noconfirm git dialog >/dev/null 2>error.log
    if [[ $? != 0 ]]; then
       error "Are you conected to the internet?  Do you have sudo?"
    fi

    dialog --title "Welcome" --msgbox "This script is an automated Arch Linux bootstrapping script\n\nAn internet connection is needed to install Arch Linux" 10 40
    dialog --title "Confirmation"  --yes-label "Let's GO!" --no-label "Wait... Stop" --yesno "Please make sure that your paritions are mounted on the live disk to '/mnt'\n\n - Ready to start?" 10 40

    if (( $? == 1 )); then
        dialog --title "" --msgbox "Stopped bootstrap" 10 40
        clear
        exit 1
    fi
}

get_valid_drives() {
	lsblk
}

partition() {
		# disabled for now until I can test on a linux box
		exit 1
		dialog --title "Select Format Option" --yes-label "Repartition Drives" --no-label "Select Existing Partitions" --yesno "Would you like to select existing partitions or format the drives?" 10 40

		swap=""
		boot=""
		home=""
		root=""

		if [[ $? == 0 ]]; then
			# repartition drives
		fi

		if [[ "$swap" != "" ]]; then
			dialog --title "Swap" --infobox "Making swap space"
			swapon -a "$swap" >/dev/null 2>error.log
		fi

		if [[ "$root" != "" ]]; then
			dialog --title "Root directory" --infobox "Mounting $root to /mnt"
			mount "$root" /mnt >/dev/null 2>error.log
			mkdir -p /mnt/boot >/dev/null 2>error.log
			mkdir -p /mnt/home >/dev/null 2>error.log
		fi

		if [[ "$boot" != "" ]]; then
			dialog --title "Boot directory" --infobox "Mounting $boot to /mnt/boot"
			mount "$boot" /mnt/boot >/dev/null 2>error.log
		fi

		if [[ "$home" != "" ]]; then
			dialog --title "Home directory" --infobox "Mounting $home to /mnt/home"
			mount "$home" /mnt/home >/dev/null 2>error.log
		fi
}

partition_confirmation() {
    dialog --title "Partitioning" --yesno "Would you like to partition your drive?" 10 40 &&\
    (dialog --title "Confirmation"  --yes-label "Let's GO!" --no-label "Wait... Stop" --defaultno --yesno "Are you SURE?" 10 40 && partition) ||\
    dialog --title "Cancelled" --msgbox "You cancelled the partitioning. Hopefully you mounted your drives properly to '/mnt'" 10 40
}

set_timedate() {
    timedatectl set-ntp true >/dev/null 2>error.log
}

run_pacstrap() {
    dialog --title "Running pacstrap" --infobox "Please wait while pactrap is being run" 10 40
    pacstrap /mnt base base-devel dialog >/dev/null 2>error.log
}

fstab_gen() {
    dialog --title "Running genfstab" --infobox "Please wait while fstab is being generated" 10 40
    genfstab -U /mnt >> /mnt/etc/fstab >/dev/null 2>error.log
}

set_hostname() {
    new_hostname=$(dialog --title "Hostname" --inputbox "Please create your system's hostname" 10 40 "arch" 3>&1 1>&2 2>&3 3>&1)

    while [[ $new_hostname == "" ]]; do
        new_hostname=$(dialog --title "Hostname" --inputbox "Hostname cannot be blank" 10 40 "arch" 3>&1 1>&2 2>&3 3>&1)
    done

    echo "$new_hostname" > /mnt/etc/hostname

    echo '127.0.0.1	localhost' >> /mnt/etc/hosts
    echo '::1		localhost' >> /mnt/etc/hosts
    echo '127.0.1.1	'"$new_hostname"'.localdomain	'"$new_hostname" >> /mnt/etc/hosts
}

install_pacman() {
    dialog --title "Installing pacman Packages" --infobox "Installing \`$1\` ($n of $(($total))). \n\n - $2" 5 70
	arch-chroot /mnt pacman --noconfirm --needed -S "$1" >/dev/null 2>error.log
}

install_all_packages() {
    echo $(cat $1 | while read line; do echo "$line" | awk -F',' 'BEGIN { ORS="\n" }; {printf "%s %s 0 ", $2, $3}'; done) > /tmp/pac.tmp
    packages=$(dialog --title "Select packages" --checklist "Select packages that you wish to install" 40 80 40 --file /tmp/pac.tmp 3>&1 1>&2 2>&3 3>&1)

    total=$(echo $packages | awk -F " " '{for (i=1; i<=NF; i++) print $i}' | wc -l)

    n=1
    echo $packages | awk -F " " '{for (i=1; i<=NF; i++) print $i}' | while read line; do
        package_meta=$(cat pacman.csv | grep "^\w*,$line,")
        description=$(echo $package_meta | awk -F"," '{print $3}' | sed s/\"//g)
        additional_packages=$(echo $package_meta | awk -F"," '{print $4}' | sed s/\"//g)
        additional_commands=$(echo $package_meta | awk -F"," '{print $5}' | sed s/\"//g)
        install_pacman "$line" "$description"
        n=$(($n+1))

        if [[ $additional_packages != "" ]]; then
	        arch-chroot /mnt pacman --noconfirm --needed -S "$additional_packages" >/dev/null 2>error.log
        fi

        if [[ $additional_commands != "" ]]; then
	        arch-chroot /mnt $additional_commands >/dev/null 2>error.log
        fi
    done
}

timezone() {
    clear

    arch-chroot /mnt tzselect

    arch-chroot /mnt hwclock --systohc >/dev/null 2>error.log

    echo 'en_US.UTF-8 UTF-8' >> /mnt/etc/locale.gen

    arch-chroot /mnt locale-gen >/dev/null 2>error.log
}

set_password(){
    if [[ $# == 0 ]]; then
        title="Sudo password"
        user="sudo"
    else
        user="$1"
        title="$user""'s password"
    fi

    p1=$(dialog --title "$title" --passwordbox "Please enter the password for $user" 10 40 3>&1 1>&2 2>&3 3>&1)
    p2=$(dialog --title "$title" --passwordbox "Please enter the password again" 10 40 3>&1 1>&2 2>&3 3>&1)

    while [[ $p1 == "" || $p1 != $p2 ]]; do
        p1=$(dialog --title "$title" --passwordbox "Password mismatch or was empty. Please try again" 10 40 3>&1 1>&2 2>&3 3>&1)
        p2=$(dialog --title "$title" --passwordbox "Please enter the password again" 10 40 3>&1 1>&2 2>&3 3>&1)
    done

    if [[ $# == 0 ]]; then
        (echo ${p1}; echo ${p2}) | arch-chroot /mnt passwd >/dev/null 2>error.log
    else
        (echo ${p1}; echo ${p2}) | arch-chroot /mnt passwd "$user" >/dev/null 2>error.log
    fi

		unset p1
		unset p2
}

create_user() {
    user=$(dialog --title "User" --inputbox "Please input a name for your user" 10 40 3>&1 1>&2 2>&3 3>&1)
    while [[ $user == "" ]]; do
        user=$(dialog --title "User" --inputbox "User's name cannot be blank. Please try again" 10 40 3>&1 1>&2 2>&3 3>&1)
    done

    set_password $user

    selected_shell=$(dialog --title "Shell Selection" --radiolist "Please select a default shell for your user" 20 40 10 zsh "" 0 bash "" 0 tsch "" 0 fish "" 0 3>&1 1>&2 2>&3 3>&1)

    dialog --title "Shell installation" --infobox "Installing $selected_shell" 10 40

    arch-chroot /mnt pacman -S --noconfirm --needed $selected_shell >/dev/null 2>error.log

    dialog --title "Shell installation" --infobox "Setting /bin/$selected_shell as the default shell for $user" 10 40

    arch-chroot /mnt useradd -m -G wheel -s "/bin/""$selected_shell" $user >/dev/null 2>error.log
}

arch_keyring() {
    dialog --title "Keyring" --infobox "Updating archlinux-keyring" 10 40

    arch-chroot /mnt pacman -S --noconfirm --needed archlinux-keyring >/dev/null 2>error.log

    arch-chroot /mnt pacman -Syy >/dev/null 2>error.log
}

grub_install() {
    # check for intel/amd
    proc_type="$(arch-chroot /mnt lscpu | grep 'Vendor Id:')"

    if [[ $proc_type =~ '[Ii]ntel'  ]]; then
        dialog --title "Grub Installation" --infobox "Intel Detected. Installing intel-ucode and grub" 10 40
        $(arch-chroot /mnt pacman -S --noconfirm --needed intel-ucode grub efibootmgr)
    elif [[ $proc_type =~ '[Aa][Mm][Dd]' ]]; then
        dialog --title "Grub Installation" --infobox "AMD Detected. Installing amd-ucode and grub" 10 40
        $(arch-chroot /mnt pacman -S --noconfirm --needed amd-ucode grub efibootmgr)
    else
        dialog --title "Grub Installation" --infobox "Unknown processor. Installing grub" 10 40
        $(arch-chroot /mnt pacman -S --noconfirm --needed grub efibootmgr)
    fi

    dialog --title "Grub Installation" --infobox "Configuring and installing grub to /boot" 10 40
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch\ Linux >/dev/null 2>error.log
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>error.log
}

completed() {
    dialog --title "Install complete!" --yes-label "chroot" --no-label "Reboot" --yesno "Would you like to chroot into your new arch installation or umount and reboot?" 10 40 && (clear && arch-chroot /mnt) || (umount -R /mnt && reboot)
}

main_install() {
    welcome || error "Welcome failed"
    partition_confirmation
    set_timedate || error "timedatectl failed"
    run_pacstrap || error "pacstrap failed. Are the partitions mounted correctly? Did formatting fail?"
    fstab_gen || error "genfstab failed"
    timezone || error "failed to set timezone"
    set_hostname || error "failed to set the system hostname"
    set_password || error "failed to set the sudo password"
    create_user || error "failed to create user"
    arch_keyring || error "failed to update the Arch keyring"
    install_all_packages pacman.csv || error "failed to install packages. Does the pacman.csv file exist in this directory?"
    grub_install || error "failed to install grub. Is your system using efi?"
    completed
}

main_install

