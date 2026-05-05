#!/bin/bash

echo "🧪 Testing ACL Isolation..."
echo "Attempting to produce to 'audit.tenant-acme.events' using 'tenant-globex' credentials..."

docker exec -t app node -e "
const { Kafka } = require('kafkajs');
const kafka = new Kafka({
  clientId: 'violation-test',
  brokers: ['kafka:9092'],
  sasl: {
    mechanism: 'scram-sha-256',
    username: 'tenant-globex',
    password: 'globex-password',
  },
});

const producer = kafka.producer();

const run = async () => {
  try {
    await producer.connect();
    console.log('Connected to Kafka');
    await producer.send({
      topic: 'audit.tenant-acme.events',
      messages: [{ value: 'Unauthorized message' }],
    });
    console.log('❌ Error: Message sent successfully (ACLs failed)');
    process.exit(0);
  } catch (error) {
    console.log('✅ Successfully blocked by ACLs:', error.name);
    if (error.name === 'KafkaJSProtocolError' || error.name === 'KafkaJSTopicAuthorizationError' || error.message.includes('not authorized')) {
      process.exit(1);
    }
    process.exit(1);
  }
};

run();
"
