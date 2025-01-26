# Chef

## Overview
Chef is a configuration management tool that automates the deployment and management of infrastructure.

## Key Features
- **Ruby-Based DSL**: Define infrastructure using Chef's Ruby-based DSL.
- **Idempotency**: Ensures consistent state across multiple runs.
- **Community Cookbooks**: Reusable configurations from the Chef Supermarket.

## Getting Started
1. Install Chef:
   ```bash
   curl -L https://omnitruck.chef.io/install.sh | sudo bash
   ```
2. Create a cookbook:
   ```bash
   chef generate cookbook my_cookbook
   ```
3. Define a recipe (`recipes/default.rb`):
   ```ruby
   package 'apache2' do
     action :install
   end
   service 'apache2' do
     action [:enable, :start]
   end
   ```
4. Apply the recipe:
   ```bash
   chef-client --local-mode recipes/default.rb
   ```
