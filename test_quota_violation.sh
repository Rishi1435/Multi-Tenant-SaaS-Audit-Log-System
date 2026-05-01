#!/bin/bash

echo "🧪 Testing Client Quotas..."
echo "Producing messages at high rate for 'tenant-initech'..."

docker exec -t app node -e "
const { Kafka } = require('kafkajs');
const kafka = new Kafka({
  clientId: 'quota-test',
  brokers: ['kafka:29092'],
  sasl: {
    mechanism: 'scram-sha-256',
    username: 'tenant-initech',
    password: 'initech-password',
  },
});

const producer = kafka.producer();

const run = async () => {
  await producer.connect();
  console.log('Connected to Kafka. Starting high-rate production (Target: >5MB/s)...');
  
  const startTime = Date.now();
  const duration = 20000; // 20 seconds
  let bytesSent = 0;
  
  const largeMessage = 'X'.repeat(1024 * 200); // 200KB message
  const batchSize = 10;

  while (Date.now() - startTime < duration) {
    try {
      // Send batches in parallel to maximize throughput
      const batch = Array(batchSize).fill().map(() => 
        producer.send({
          topic: 'audit.tenant-initech.events',
          messages: [{ value: largeMessage }],
        })
      );
      
      await Promise.all(batch);
      bytesSent += (largeMessage.length * batchSize);
      
      const elapsed = (Date.now() - startTime) / 1000;
      const rate = (bytesSent / 1024 / 1024) / elapsed;
      console.log(\`Sent \${Math.round(bytesSent / 1024 / 1024)} MB. Current Rate: \${rate.toFixed(2)} MB/s\`);
    } catch (error) {
      if (error.name === 'KafkaJSRequestTimeoutError') {
        console.log('⚠️ Throttling detected (Request Timeout/Delay)');
      }
    }
  }
  
  console.log('Finished production test.');
  process.exit(0);
};

run();
"
