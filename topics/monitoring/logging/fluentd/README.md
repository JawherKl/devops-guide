# Fluentd

## Overview
Fluentd is an open-source data collector for unified logging layers.

## Key Features
- **Unified Logging**: Collect logs from various sources.
- **Flexible Configuration**: Use plugins to extend functionality.
- **Scalability**: Handle high volumes of log data.

## Getting Started
1. Install Fluentd:
   ```bash
   curl -L https://toolbelt.treasuredata.com/sh/install-ubuntu-bionic-td-agent4.sh | sh
   ```
2. Configure Fluentd (`/etc/td-agent/td-agent.conf`):
   ```xml
   <source>
     @type forward
     port 24224
   </source>
   <match **>
     @type stdout
   </match>
   ```
3. Start Fluentd:
   ```bash
   sudo systemctl start td-agent
   ```
