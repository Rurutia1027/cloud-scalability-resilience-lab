#!/bin/sh

# checkout couponservice's Prometheus exporter output metrics 
curl -sS http://localhost:9091/actuator/prometheus | head -n 15

# checkout productservice's Prometheus exporter output metrics 
curl -sS http://localhost:9090/actuator/prometheus | head -n 15


echo ""
echo "fetch how many times the APIs of couponservice have been called"

# fetch how many times the APIs of couponservice have been called 
curl -sS http://localhost:9091/actuator/prometheus | grep '^http_server_requests_seconds_count'


# fetch API sum latency, and max latency 
echo ""
echo "fetch API sum latency, and max latency"
curl -sS http://localhost:9091/actuator/prometheus | grep '^http_server_requests_seconds_\(sum\|max\)'

echo ""
# fetch JVM heap and non-heap occupation 
curl -sS http://localhost:9091/actuator/prometheus | grep '^jvm_memory_used_bytes'


echo "" 
# fetch CPU usage 
curl -sS http://localhost:9091/actuator/prometheus | grep '^process_cpu_usage'


echo "" 
curl -sS http://localhost:9091/actuator/prometheus | grep '^hikaricp_connections'



