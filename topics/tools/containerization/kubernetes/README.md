
# Kubernetes

## Overview
Kubernetes is an open-source container orchestration platform for automating deployment, scaling, and management of containerized applications.

## Key Features
- **Automated Rollouts and Rollbacks**: Deploy updates and revert changes seamlessly.
- **Self-Healing**: Automatically restart failed containers.
- **Service Discovery and Load Balancing**: Expose containers using DNS or IP.
- **Storage Orchestration**: Mount storage systems dynamically.

## Getting Started
1. Install Minikube (for local Kubernetes):
   ```bash
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   minikube start

2. Deploy an application:
   ```bash
    kubectl create deployment hello-minikube --image=k8s.gcr.io/echoserver:1.4
    kubectl expose deployment hello-minikube --type=NodePort --port=8080
