# Security Analysis: Multi-Tenant Audit Logging System

#### Credential Rotation Strategy
In this system, credentials for tenants are managed via SASL/SCRAM. Rotating credentials involves:
1.  **Administrative Update**: Using `kafka-configs` to update the SCRAM user's password in ZooKeeper/Kafka.
2.  **Graceful Transition**: The system should support multiple active credentials per tenant during rotation (though Kafka's SCRAM implementation typically supports one active credential at a time). For a zero-downtime rotation, we would:
    -   Add a new credential for the tenant.
    -   Update the Gateway service to use the new credential.
    -   Revoke the old credential.

#### Credential Leak Impact and Mitigation
If a tenant's credentials (e.g., `tenant-acme`) are leaked:
-   **Impact**: The attacker can PRODUCE messages to `audit.tenant-acme.events` and CONSUME from it. They **cannot** access data from `tenant-globex` or any other tenant due to the strict ACLs enforced at the broker level.
-   **Mitigation**:
    -   **Immediate Revocation**: Admin can immediately remove the compromised SCRAM user or change the password.
    -   **Quota Protection**: The 1MB/s quota limits the volume of data an attacker can flood or exfiltrate.
    -   **Violation Logging**: Any attempt to use the leaked credentials against other topics will be blocked by ACLs and can be alerted on via broker logs.

#### Gaps for Enterprise Multi-Tenancy
While robust, this system has several gaps for a full enterprise-scale deployment:
1.  **Encryption at Rest**: Kafka topics and ZooKeeper data should be encrypted at rest using KMS/LUKS.
2.  **TLS/SSL for All Traffic**: Current setup uses SASL_PLAINTEXT. Production environments must use SASL_SSL to encrypt data in transit.
3.  **Identity Provider (IDP) Integration**: Instead of static SCRAM users, integrate with OIDC or LDAP for dynamic principal management.
4.  **Network Isolation**: Use VPC Peering or PrivateLink to ensure Kafka traffic never traverses the public internet.
5.  **Audit Logs for the Audit Log**: Enable Kafka's internal auditing to track which principals modified ACLs or accessed topics.
