#!/usr/bin/env bash

# Get the device uuid
DISK2_UUID=$(blkid $DISK2 | awk -F '"' '{print $2}')
DISK3_UUID=$(blkid $DISK3 | awk -F '"' '{print $2}')

# Set user and hostname
useradd -m -G wheel -s /bin/bash $USERNAME
mkdir -p /home/$USERNAME
echo $HOSTNAME > /etc/hostname

# Configure hosts
echo "127.0.0.1	localhost
::1		localhost
127.0.1.1	myarch" | tee /etc/hosts

# Discover the best mirros to download packages and update pacman configs
reflector --verbose --country 'Brazil' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "s/#Color/Color/g" /etc/pacman.conf
sed -i "s/#UseSyslog/UseSyslog/g" /etc/pacman.conf
sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 50/g" /etc/pacman.conf

# Setup locate and time
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /etc/locale.gen
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
sed -i "s/#en_US ISO-8859-1/en_US ISO-8859-1/g" /etc/locale.gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
locale-gen
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc

# Generate the initramfs
sed -i "s/BINARIES=()/BINARIES=(btrfs)/g" /etc/mkinitcpio.conf
sed -i "s/block/block encrypt/g" /etc/mkinitcpio.conf
mkinitcpio -P

# Setup the bootloader
# install bootloader
bootctl --path=/boot install

# generate the arch linux entry config
mkdir -p /boot/loader/entries
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options rd.luks.name=${DISK3_UUID}=system root=/dev/mapper/system rootflags=subvol=root rd.luks.options=discard rw
EOF

# generate the loader config
cat > /boot/loader/loader.conf << EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

# Configure grub
sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash acpi_backlight=vendor nvidia-drm.modeset=1"/g' /etc/default/grub
sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='${DISK3_UUID}':cryptsystem"/g' /etc/default/grub
sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g' /etc/default/grub
sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/g' /etc/default/grub
sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/g' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

# Configure systemd for laptop's
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' /etc/systemd/logind.conf
sed -i 's/#NAutoVTs=6/NAutoVTs=6/g' /etc/systemd/logind.conf

# Services
systemctl disable NetworkManager
systemctl enable dhcpcd
systemctl enable iwd

# graphics driver
nvidia=$(lspci | grep -e VGA -e 3D | grep 'NVIDIA' 2> /dev/null || echo '')
if [[ -n $nvidia ]]; then
  pacman -S nvidia nvidia-settings nvidia-utils nvidia-dkms opencl-nvidia --noconfirm
  sed -i "s/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g" /etc/mkinitcpio.conf
  mkinitcpio -P
fi

# Sudo configs
sed -i "s/root ALL=(ALL) ALL/root ALL=(ALL) NOPASSWD: ALL\n$USERNAME ALL=(ALL) NOPASSWD:ALL/g" /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL$/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

# My notebook
if [[ $USERNAME == mamutal91 ]]; then
  STORAGE_UUID=$(blkid $STORAGE | awk -F '"' '{print $2}')
  mkdir -p /mnt/storage
  echo -e "\nstorage UUID=$STORAGE_UUID /root/keyfile luks" >> /etc/crypttab
  echo -e "\n# Storage" >> /etc/fstab
  echo "/dev/mapper/storage  /mnt/storage     btrfs    defaults        0       2" >> /etc/fstab
  dd if=/dev/urandom of=/root/keyfile bs=1024 count=4
  chmod 0400 /root/keyfile
  clear
  echo "Type crypt password $STORAGE"
  cryptsetup -v luksAddKey $STORAGE /root/keyfile
fi

# Define passwords
clear
echo "Type user password $USERNAME"
passwd $USERNAME && clear
echo "Type user password root"
passwd root

if [[ $USERNAME == mamutal91 ]]; then
  git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles
  sed -i 's/https/ssh/g' /home/mamutal91/.dotfiles/.git/config
  sed -i 's/github/git@github/g' /home/mamutal91/.dotfiles/.git/config
fi
