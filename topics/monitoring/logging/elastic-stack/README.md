# Elastic Stack (ELK)

## Overview
The Elastic Stack (ELK) consists of Elasticsearch, Logstash, and Kibana, and is used for searching, analyzing, and visualizing log data.

## Key Features
- **Elasticsearch**: Distributed search and analytics engine.
- **Logstash**: Data processing pipeline.
- **Kibana**: Visualization and exploration of data.

## Getting Started
1. Install Elasticsearch:
   ```bash
   wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.15.0-amd64.deb
   sudo dpkg -i elasticsearch-7.15.0-amd64.deb
   sudo systemctl start elasticsearch
   ```
2. Install Logstash:
   ```bash
   wget https://artifacts.elastic.co/downloads/logstash/logstash-7.15.0.deb
   sudo dpkg -i logstash-7.15.0.deb
   sudo systemctl start logstash
   ```
3. Install Kibana:
   ```bash
   wget https://artifacts.elastic.co/downloads/kibana/kibana-7.15.0-amd64.deb
   sudo dpkg -i kibana-7.15.0-amd64.deb
   sudo systemctl start kibana
   ```
4. Access Kibana at `http://localhost:5601`.
