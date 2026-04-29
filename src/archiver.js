const AWS = require('aws-sdk');
const { getKafkaClient } = require('./kafka-client');

const s3 = new AWS.S3({
  endpoint: `http://${process.env.MINIO_ENDPOINT}:${process.env.MINIO_PORT}`,
  accessKeyId: process.env.MINIO_ACCESS_KEY,
  secretAccessKey: process.env.MINIO_SECRET_KEY,
  s3ForcePathStyle: true, // Needed for MinIO
  signatureVersion: 'v4',
});

const BUCKET_NAME = 'kafka-archive';
const TENANTS = ['tenant-acme', 'tenant-globex', 'tenant-initech'];
const TOPICS = TENANTS.map(t => `audit.${t}.events`);

const initMinio = async () => {
  try {
    await s3.createBucket({ Bucket: BUCKET_NAME }).promise();
    console.log(`Bucket "${BUCKET_NAME}" created or already exists.`);
  } catch (err) {
    if (err.code !== 'BucketAlreadyOwnedByYou' && err.code !== 'BucketAlreadyExists') {
      console.error('Error creating MinIO bucket:', err);
    }
  }
};

const startArchiver = async () => {
  await initMinio();

  const adminClient = getKafkaClient(
    process.env.ADMIN_USERNAME || 'admin',
    process.env.ADMIN_PASSWORD || 'admin-password'
  );

  const consumer = adminClient.consumer({ groupId: 'archiver-group' });

  await consumer.connect();
  for (const topic of TOPICS) {
    await consumer.subscribe({ topic, fromBeginning: true });
  }

  console.log('Archiver worker started. Listening to topics:', TOPICS);

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      const timestamp = parseInt(message.timestamp);
      const now = Date.now();
      const ageMs = now - timestamp;
      
      const fiveMinutesMs = 5 * 60 * 1000;
      
      if (ageMs < fiveMinutesMs) {
        const waitTime = fiveMinutesMs - ageMs;
        console.log(`[${topic}] Message at offset ${message.offset} is too new (${Math.round(ageMs/1000)}s). Waiting ${Math.round(waitTime/1000)}s...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }

      const offset = message.offset.padStart(20, '0');
      const key = `kafka-archive/${topic}/partition=${partition}/${offset}.json`;

      console.log(`Archiving message from ${topic} [${partition}] at offset ${message.offset} (Age: ${Math.round((Date.now() - timestamp)/1000)}s)`);

      try {
        await s3.putObject({
          Bucket: BUCKET_NAME,
          Key: key,
          Body: message.value.toString(),
          ContentType: 'application/json',
          Metadata: {
            kafka_offset: message.offset,
            kafka_timestamp: message.timestamp,
          }
        }).promise();
      } catch (err) {
        console.error(`Failed to archive message ${offset} from ${topic}:`, err);
      }
    },
  });
};

module.exports = { startArchiver };
