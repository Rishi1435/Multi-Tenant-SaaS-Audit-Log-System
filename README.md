# Multi-Tenant Audit Logging System

A production-grade, secure audit logging pipeline built with Apache Kafka, MinIO, and Node.js. This project demonstrates strict tenant isolation using Kafka ACLs, resource management via Client Quotas, and data archival to S3-compatible storage.

## Architecture

- **HTTP Gateway**: Express.js service that validates tenant identity and routes events.
- **Kafka Broker**: Configured with SASL/SCRAM authentication and ACL-based authorization.
- **MinIO**: S3-compatible storage for long-term archival of audit events.
- **Archiver Worker**: Background process that moves data from Kafka to MinIO.

## Prerequisites

- Docker and Docker Compose
- Node.js (for running test scripts locally)

## Getting Started

1.  **Clone the repository**.
2.  **Start the infrastructure**:
    ```bash
    docker-compose up --build -d
    ```
3.  **Wait for services to be healthy** (approx. 1-2 minutes).
4.  **Provision tenants**:
    ```bash
    ./provision.sh
    ```

## Demo

Watch the project demo on YouTube:

https://youtu.be/ANgaCeR1PFk

## Usage

### Sending Events

```bash
curl -X POST http://localhost:3000/events \
  -H "X-Tenant-ID: tenant-acme" \
  -H "Content-Type: application/json" \
  -d '{
    "actor_id": "user-123",
    "action": "login",
    "timestamp": "2023-10-27T10:00:00Z",
    "details": {"ip": "1.1.1.1"}
  }'
```

### Unauthorized Access

```bash
curl -X POST http://localhost:3000/events \
  -H "X-Tenant-ID: tenant-unknown" \
  -H "Content-Type: application/json" \
  -d '{"action": "test"}'
```

## Verification Scripts

### ACL Isolation Test
Ensures that one tenant cannot produce messages to another tenant's topic.
```bash
./test_acl_violation.sh
```

### Client Quota Test
Demonstrates that the broker throttles producers exceeding the 1MB/s limit.
```bash
./test_quota_violation.sh
```

## Security

Detailed security analysis can be found in [SECURITY.md](SECURITY.md).
