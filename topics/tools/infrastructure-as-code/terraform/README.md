# Terraform

## Overview
Terraform is an open-source infrastructure as code (IaC) tool for provisioning and managing cloud resources.

## Key Features
- **Declarative Syntax**: Define infrastructure using HCL (HashiCorp Configuration Language).
- **Multi-Cloud Support**: Manage resources across AWS, Azure, GCP, and more.
- **State Management**: Track the state of your infrastructure.

## Getting Started
1. Install Terraform:
   ```bash
   sudo apt update
   sudo apt install terraform
   
2. Create a Terraform configuration file (main.tf):
   ```bash
   provider "aws" {
      region = "us-east-1"
    }
    
    resource "aws_instance" "example" {
      ami           = "ami-0c55b159cbfafe1f0"
      instance_type = "t2.micro"
    }
   
4. Apply the configuration:
   ```bash
   terraform init
   terraform apply
