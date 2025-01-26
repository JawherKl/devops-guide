# Ansible

## Overview
Ansible is an open-source automation tool for configuration management, application deployment, and task automation.

## Key Features
- **Agentless**: Uses SSH for communication with nodes.
- **Idempotent**: Ensures consistent state across multiple runs.
- **YAML-Based Playbooks**: Define automation tasks in human-readable YAML.

## Getting Started
1. Install Ansible:
   ```bash
   sudo apt update
   sudo apt install ansible
   ```
2. Create an inventory file (`inventory`):
   ```ini
   [webservers]
   server1 ansible_host=192.168.1.10
   server2 ansible_host=192.168.1.11
   ```
3. Create a playbook (`playbook.yml`):
   ```yaml
   - hosts: webservers
     tasks:
       - name: Ensure Apache is installed
         apt:
           name: apache2
           state: present
   ```
4. Run the playbook:
   ```bash
   ansible-playbook -i inventory playbook.yml
   ```
