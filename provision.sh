#!/bin/bash

# Configuration
KAFKA_CONTAINER="kafka"
BOOTSTRAP_SERVER="localhost:29092"
TENANTS=("tenant-acme" "tenant-globex" "tenant-initech")
PASSWORDS=("acme-password" "globex-password" "initech-password")
QUOTA=1048576 # 1 MB/s

echo "🚀 Bootstrapping multi-tenant Kafka environment..."

# Function to run kafka commands in the container
run_kafka_cmd() {
    docker exec $KAFKA_CONTAINER "$@"
}

# 1. Wait for Kafka to be fully ready (Hard readiness loop)
echo "Waiting for Kafka to be fully ready..."
until run_kafka_cmd kafka-topics --bootstrap-server $BOOTSTRAP_SERVER --list > /dev/null 2>&1; do
    echo -n "."
    sleep 5
done
echo -e "\nKafka is ready!"

# 2. Create audit.violations topic
echo "Creating audit.violations topic..."
run_kafka_cmd kafka-topics --bootstrap-server $BOOTSTRAP_SERVER --create --if-not-exists --topic audit.violations --partitions 1 --replication-factor 1

# 3. Provision each tenant
for i in "${!TENANTS[@]}"; do
    TENANT=${TENANTS[$i]}
    PASSWORD=${PASSWORDS[$i]}
    TOPIC="audit.$TENANT.events"

    echo "--------------------------------------------------"
    echo "Provisioning $TENANT..."

    # Create Topic
    echo "  Creating topic $TOPIC..."
    run_kafka_cmd kafka-topics --bootstrap-server $BOOTSTRAP_SERVER --create --if-not-exists --topic $TOPIC --partitions 1 --replication-factor 1

    # Create SASL/SCRAM user
    echo "  Creating SASL/SCRAM user $TENANT..."
    run_kafka_cmd kafka-configs --bootstrap-server $BOOTSTRAP_SERVER --alter --add-config "SCRAM-SHA-256=[password=$PASSWORD]" --entity-type users --entity-name $TENANT

    # Apply ACLs
    echo "  Applying ACLs for $TENANT..."
    # Producer access
    run_kafka_cmd kafka-acls --bootstrap-server $BOOTSTRAP_SERVER --add --allow-principal "User:$TENANT" --operation Write --topic $TOPIC
    run_kafka_cmd kafka-acls --bootstrap-server $BOOTSTRAP_SERVER --add --allow-principal "User:$TENANT" --operation Describe --topic $TOPIC
    
    # Consumer access
    run_kafka_cmd kafka-acls --bootstrap-server $BOOTSTRAP_SERVER --add --allow-principal "User:$TENANT" --operation Read --topic $TOPIC
    run_kafka_cmd kafka-acls --bootstrap-server $BOOTSTRAP_SERVER --add --allow-principal "User:$TENANT" --operation Read --operation Describe --group "*"

    # Set Quotas
    echo "  Setting byte-rate quotas for $TENANT..."
    run_kafka_cmd kafka-configs --bootstrap-server $BOOTSTRAP_SERVER --alter --add-config "producer_byte_rate=$QUOTA,consumer_byte_rate=$QUOTA" --entity-type users --entity-name $TENANT
done

echo "--------------------------------------------------"
echo "✅ Provisioning complete!"
