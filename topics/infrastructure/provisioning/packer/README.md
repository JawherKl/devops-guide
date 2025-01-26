# Packer

## Overview
Packer is an open-source tool for creating machine images for multiple platforms from a single source configuration.

## Key Features
- **Multi-Platform Support**: Create images for AWS, Azure, GCP, and more.
- **Immutable Infrastructure**: Build consistent, reproducible images.
- **Automation**: Integrate with CI/CD pipelines.

## Getting Started
1. Install Packer:
   ```bash
   sudo apt update
   sudo apt install packer
   ```
2. Create a Packer template (`template.json`):
   ```json
   {
     "builders": [
       {
         "type": "amazon-ebs",
         "region": "us-east-1",
         "source_ami": "ami-0c55b159cbfafe1f0",
         "instance_type": "t2.micro",
         "ssh_username": "ubuntu",
         "ami_name": "my-image-{{timestamp}}"
       }
     ]
   }
   ```
3. Build the image:
   ```bash
   packer build template.json
   ```
