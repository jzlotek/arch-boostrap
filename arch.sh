#!/bin/bash

echo 'Please make sure that your partitions are mounted to /mnt'

echo 'Starting Bootstrap'

timedatectl set-ntp true

pacstrap /mnt base base-devel

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt
