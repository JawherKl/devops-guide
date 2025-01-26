# Alertmanager

## Overview
Alertmanager is a component of the Prometheus ecosystem that handles alerts sent by client applications such as the Prometheus server.

## Key Features
- **Alert Routing**: Route alerts to the correct receiver (e.g., email, Slack).
- **Deduplication**: Group similar alerts to reduce noise.
- **Silencing**: Mute alerts during maintenance windows.

## Getting Started
1. Install Alertmanager:
   ```bash
   wget https://github.com/prometheus/alertmanager/releases/download/v0.23.0/alertmanager-0.23.0.linux-amd64.tar.gz
   tar xvfz alertmanager-0.23.0.linux-amd64.tar.gz
   cd alertmanager-0.23.0.linux-amd64
   ./alertmanager
   ```
2. Access Alertmanager UI at `http://localhost:9093`.
