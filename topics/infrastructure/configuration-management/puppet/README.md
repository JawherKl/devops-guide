# Puppet

## Overview
Puppet is a configuration management tool that automates the provisioning, configuration, and management of infrastructure.

## Key Features
- **Declarative Language**: Define infrastructure state using Puppet's DSL.
- **Idempotency**: Ensures consistent state across multiple runs.
- **Scalability**: Manages thousands of nodes efficiently.

## Getting Started
1. Install Puppet:
   ```bash
   sudo apt update
   sudo apt install puppet
   ```
2. Create a manifest file (`site.pp`):
   ```puppet
   node 'webserver' {
     package { 'apache2':
       ensure => installed,
     }
     service { 'apache2':
       ensure => running,
       enable => true,
     }
   }
   ```
3. Apply the manifest:
   ```bash
   sudo puppet apply site.pp
