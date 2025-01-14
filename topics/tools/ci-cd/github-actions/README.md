# GitHub Actions

## Overview
GitHub Actions is a CI/CD platform integrated directly into GitHub. It allows you to automate workflows for building, testing, and deploying your code.

## Key Features
- **Event-Driven Workflows**: Trigger workflows based on GitHub events (e.g., push, pull request).
- **Reusable Workflows**: Share workflows across repositories.
- **Matrix Builds**: Test across multiple environments simultaneously.
- **Self-Hosted Runners**: Run workflows on your own infrastructure.

## Getting Started
1. Create a `.github/workflows` directory in your repository.
2. Add a workflow file (e.g., `ci.yml`):
   ```yaml
   name: CI

   on:
     push:
       branches:
         - main
     pull_request:
       branches:
         - main

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - name: Checkout code
           uses: actions/checkout@v3

         - name: Set up Node.js
           uses: actions/setup-node@v3
           with:
             node-version: '16'

         - name: Install dependencies
           run: npm install

         - name: Run tests
           run: npm test
