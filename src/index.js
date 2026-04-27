require('dotenv').config();
const express = require('express');
const gatewayRouter = require('./gateway');
const { startArchiver } = require('./archiver');

const app = express();
const PORT = process.env.APP_PORT || 3000;

app.use(express.json());
app.use('/', gatewayRouter);

// Start the archiver in the background
startArchiver().catch(err => {
  console.error('Failed to start archiver:', err);
});

app.listen(PORT, () => {
  console.log(`🚀 Audit Gateway server running on port ${PORT}`);
});
