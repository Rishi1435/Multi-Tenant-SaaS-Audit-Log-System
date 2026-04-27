const express = require('express');
const { getKafkaClient } = require('./kafka-client');
const router = express.Router();

// Tenant credential mapping (In a real app, this would be in a secure database)
const tenantPasswords = {
  'tenant-acme': process.env.TENANT_ACME_PASSWORD || 'acme-password',
  'tenant-globex': process.env.TENANT_GLOBEX_PASSWORD || 'globex-password',
  'tenant-initech': process.env.TENANT_INITECH_PASSWORD || 'initech-password',
};

// Admin client for violations
const adminClient = getKafkaClient(
  process.env.ADMIN_USERNAME || 'admin',
  process.env.ADMIN_PASSWORD || 'admin-password'
);
const violationProducer = adminClient.producer();

router.post('/events', async (req, res) => {
  const tenantId = req.headers['x-tenant-id'];
  const event = req.body;

  if (!tenantId || !tenantPasswords[tenantId]) {
    console.warn(`Unauthorized access attempt for tenant: ${tenantId}`);
    
    // Log violation to Kafka
    try {
      await violationProducer.connect();
      await violationProducer.send({
        topic: 'audit.violations',
        messages: [{
          value: JSON.stringify({
            tenantId,
            ip: req.ip,
            timestamp: new Date().toISOString(),
            details: 'Invalid or missing X-Tenant-ID'
          })
        }]
      });
    } catch (err) {
      console.error('Failed to log violation to Kafka', err);
    }

    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const password = tenantPasswords[tenantId];
    const tenantClient = getKafkaClient(tenantId, password);
    const producer = tenantClient.producer();

    await producer.connect();
    await producer.send({
      topic: `audit.${tenantId}.events`,
      messages: [{ value: JSON.stringify(event) }],
    });
    await producer.disconnect();

    res.status(202).json({ status: 'Accepted' });
  } catch (error) {
    console.error(`Error producing event for ${tenantId}:`, error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

router.get('/health', (req, res) => {
  res.status(200).send('OK');
});

module.exports = router;
