#!/usr/bin/env bash

source colors.sh

# Get the device uuid
SSD2_UUID=$(blkid $SSD2 | awk -F '"' '{print $2}')
SSD3_UUID=$(blkid $SSD3 | awk -F '"' '{print $2}')

createUseraAndHost() {
  useradd -m -G wheel -s /bin/bash $USERNAME
  mkdir -p /home/$USERNAME
  echo $HOSTNAME > /etc/hostname
  chown -R $USERNAME:$USERNAME /home/$USERNAME
  echo "127.0.0.1	localhost
  ::1		localhost
  127.0.1.1	${HOSTNAME}" | tee /etc/hosts
}

reflectorMirrors() {
#  reflector --verbose -c BR --protocol https --protocol http --sort rate --save /etc/pacman.d/mirrorlist
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
  sed -i 's/#Color/Color\\\nILoveCandy/' /etc/pacman.conf
  sed -i 's/Color\\/Color/' /etc/pacman.conf
  sed -i 's/#TotalDownload/TotalDownload/' /etc/pacman.conf
  sed -i 's/#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
  sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 20/g" /etc/pacman.conf
}

localeAndTime() {
  echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
  sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /etc/locale.gen
  sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /etc/locale.gen
  sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
  sed -i "s/#en_US ISO-8859-1/en_US ISO-8859-1/g" /etc/locale.gen
  echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
  locale-gen
  ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
  hwclock --systohc
}

mkinitcpioConfigs() {
  sed -i "s/BINARIES=()/BINARIES=(btrfs)/g" /etc/mkinitcpio.conf
  sed -i "s/block/block encrypt/g" /etc/mkinitcpio.conf
  sed -i "s/#COMPRESSION=\"zstd\"/COMPRESSION=\"zstd\"/g" /etc/mkinitcpio.conf
  sed -i "s/#COMPRESSION_OPTIONS=()/COMPRESSION_OPTIONS=(-9)/g" /etc/mkinitcpio.conf
  mkinitcpio -P
}

bootloaderConfigs() {
  bootctl --path=/boot install
  mkdir -p /boot/loader/entries
  "title   Arch Linux
  linux   /vmlinuz-linux
  initrd  /initramfs-linux.img
  options rd.luks.name=${SSD3_UUID}=$DISK_NAME root=/dev/mapper/$DISK_NAME rootflags=subvol=root rd.luks.options=discard rw" | tee /boot/loader/entries/arch.conf

  echo "default  arch.conf
  timeout  4
  console-mode max
  editor   no" | tee /boot/loader/loader.conf
}

grubConfigs() {
  sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/g' /etc/default/grub
  sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash acpi_backlight=vendor"/g' /etc/default/grub
  sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='${SSD3_UUID}':cryptsystem"/g' /etc/default/grub
  sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g' /etc/default/grub
  sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/g' /etc/default/grub
  sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/g' /etc/default/grub
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
  grub-mkconfig -o /boot/grub/grub.cfg
}

systemdConfigs() {
  sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' /etc/systemd/logind.conf
  sed -i 's/#NAutoVTs=6/NAutoVTs=6/g' /etc/systemd/logind.conf
}

sshConfigs() {
  pwd=$(pwd)
    rm -rf /etc/ssh/ssh_config
    cd /etc/ssh
    wget https://raw.githubusercontent.com/openssh/openssh-portable/master/ssh_config
    chown -R root:root ssh_config
  cd $pwd
  sed -i "s/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g" /etc/ssh/ssh_config
  sed -i "s/#AllowAgentForwarding yes/AllowAgentForwarding yes/g" /etc/ssh/sshd_config
  sed -i "s/#AllowTcpForwarding yes/AllowTcpForwarding yes/g" /etc/ssh/sshd_config
}

systemctlConfigs() {
  systemctl disable NetworkManager
  systemctl enable dhcpcd
  systemctl enable iwd
  systemctl enable sshd.service
}

sudoersConfigs() {
  sed -i "s/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) NOPASSWD: ALL\n${USERNAME} ALL=(ALL:ALL) NOPASSWD: ALL/g" /etc/sudoers
  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
  echo "Defaults timestamp_timeout=0" >> /etc/sudoers
}

passwords() {
  clear
  echo -e "\n${BOL_GRE}Digite a senha para ${MAG}${USERNAME}${END}"
  passwd $USERNAME && clear
  echo -e "\n${BOL_GRE}Digite a senha para ${MAG}root${END}"
  passwd root
}

if [[ $USERNAME == mamutal91 ]]; then
  git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles
  sed -i 's/https/ssh/g' /home/mamutal91/.dotfiles/.git/config
  sed -i 's/github/git@github/g' /home/mamutal91/.dotfiles/.git/config
fi

run() {
  createUseraAndHost
  reflectorMirrors
  localeAndTime
  mkinitcpioConfigs
  bootloaderConfigs
  grubConfigs
  systemdConfigs
  sshConfigs
  systemctlConfigs
  sudoersConfigs
  passwords
}
run "$@" || echo "$@ falhou"
