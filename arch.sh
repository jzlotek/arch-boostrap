#!/bin/bash

echo 'Please make sure that your partitions are mounted to /mnt'

echo 'Starting Bootstrap'

timedatectl set-ntp true

pacstrap /mnt base base-devel

genfstab -U /mnt >> /mnt/etc/fstab

curl https://raw.githubusercontent.com/jzlotek/arch-bootstrap/master/archchroot.sh > /mnt/tmp/archchroot.sh
chmod +x /mnt/tmp/archchroot.sh

arch-chroot /mnt /tmp/archchroot.sh
