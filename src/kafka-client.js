const { Kafka } = require('kafkajs');

const getKafkaClient = (username, password) => {
  return new Kafka({
    clientId: `audit-client-${username}`,
    brokers: [process.env.KAFKA_BROKERS || 'localhost:9093'],
    sasl: {
      mechanism: 'scram-sha-256',
      username,
      password,
    },
    ssl: false, // For local development
  });
};

module.exports = { getKafkaClient };
