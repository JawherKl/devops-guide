# Jaeger

## Overview
Jaeger is an open-source tracing system for monitoring and troubleshooting microservices-based distributed systems.

## Key Features
- **Distributed Tracing**: Track requests across services.
- **Performance Monitoring**: Identify bottlenecks and latency issues.
- **Integration**: Works with OpenTracing and OpenTelemetry.

## Getting Started
1. Install Jaeger:
   ```bash
   docker run -d --name jaeger \
     -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 \
     -p 5775:5775/udp \
     -p 6831:6831/udp \
     -p 6832:6832/udp \
     -p 5778:5778 \
     -p 16686:16686 \
     -p 14268:14268 \
     -p 9411:9411 \
     jaegertracing/all-in-one:1.30
   ```
2. Access Jaeger UI at `http://localhost:16686`.
