#!/bin/bash

ln -sf /usr/share/zoneinfo/EST5EDT /etc/localtime

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
# pacman -Sy amd-ucode
pacman -Sy intel-ucode

pacman -Sy grub

grub-mkconfig -o /boot/grub/grub.cfg