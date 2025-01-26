# Vagrant

## Overview
Vagrant is an open-source tool for building and managing virtual machine environments.

## Key Features
- **Portable Environments**: Create consistent development environments.
- **Provider Support**: Works with VirtualBox, VMware, Docker, and more.
- **Automation**: Define environments using Vagrantfiles.

## Getting Started
1. Install Vagrant:
   ```bash
   sudo apt update
   sudo apt install vagrant
   ```
2. Create a Vagrantfile:
   ```ruby
   Vagrant.configure("2") do |config|
     config.vm.box = "ubuntu/focal64"
     config.vm.network "private_network", ip: "192.168.33.10"
     config.vm.provision "shell", inline: <<-SHELL
       apt-get update
       apt-get install -y apache2
     SHELL
   end
   ```
3. Start the VM:
   ```bash
   vagrant up
   ```
