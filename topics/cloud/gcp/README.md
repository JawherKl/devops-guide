# Google Cloud Platform (GCP)

## Overview
GCP is Google's cloud platform, offering services for computing, storage, machine learning, and data analytics.

## Key Services
- **Compute**: Compute Engine, App Engine, Kubernetes Engine (GKE).
- **Storage**: Cloud Storage, Persistent Disk, Cloud SQL.
- **Databases**: Firestore, Bigtable, Spanner.
- **Networking**: Virtual Private Cloud (VPC), Cloud Load Balancing, Cloud CDN.
- **DevOps**: Cloud Build, Cloud Deployment Manager, Cloud Operations.

## Getting Started
1. Create a GCP account: [GCP Sign-Up](https://cloud.google.com/).
2. Install the Google Cloud SDK:
   ```bash
   echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
   sudo apt-get install apt-transport-https ca-certificates gnupg
   curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
   sudo apt-get update && sudo apt-get install google-cloud-sdk
   ```
3. Log in to GCP:
   ```bash
   gcloud auth login
   ```
