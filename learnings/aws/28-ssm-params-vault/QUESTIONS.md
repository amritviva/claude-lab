# Parameter Store & Secret Vault — Exam Questions

---

## Q1 (SAA-C03)
**A company stores database credentials in environment variables on EC2 instances. Security requires credentials to rotate every 90 days with zero application downtime. What should the architect recommend?**

A) Store credentials in Parameter Store SecureString with a CloudWatch Events rule to update every 90 days
B) Store credentials in the Secret Vault with automatic rotation enabled
C) Store credentials in an encrypted S3 bucket with a lifecycle policy
D) Use IAM database authentication instead of passwords

**Answer: B**

**Why (Technical):** The Secret Vault has built-in automatic rotation for RDS credentials via Lambda. It handles the rotation, updates the credential, and the application fetches the latest version with zero downtime.

**Why (Analogy):** The top-secret vault has armed guards who automatically change the lock combination every 90 days. The old key still works briefly (AWSPREVIOUS stage) while everyone switches to the new one. No one has to manually change anything.

**Why not A:** Parameter Store doesn't have built-in rotation. You'd need a custom Lambda + CloudWatch Events — reinventing what the Secret Vault does natively.
**Why not C:** S3 isn't designed for credential management. No rotation, no versioning stages, no SDK integration.
**Why not D:** IAM database auth works for MySQL/PostgreSQL on RDS but doesn't work for all engines.

---

## Q2 (DVA-C02)
**A developer is building a Lambda function that needs to read configuration values. The config includes a feature flag (string), a list of allowed origins (string list), and a database password. What's the most cost-effective approach?**

A) Store everything in the Secret Vault
B) Store everything in Parameter Store as SecureString
C) Store feature flag and origins in Parameter Store (String/StringList), database password in the Secret Vault
D) Store feature flag and origins in Parameter Store (String/StringList), database password in Parameter Store (SecureString)

**Answer: D**

**Why (Technical):** Feature flags and origins are non-sensitive — free String/StringList parameters. The DB password needs encryption but doesn't require auto-rotation, so SecureString in Parameter Store is sufficient and free.

**Why (Analogy):** Post the class schedule and visitor list on the notice board (free). Put the password in a locked drawer (SecureString — free). No need to rent space in the principal's safe ($0.40/month) when you don't need auto-rotation.

**Why not A:** $0.40/month per item for non-sensitive config. Paying for armed guards to watch a lunch menu.
**Why not B:** You can't store a StringList as SecureString. Also adds unnecessary KMS calls.
**Why not C:** Works but costs $0.40/month extra if auto-rotation isn't required.

---

## Q3 (SOA-C02)
**A SysOps administrator needs to ensure API keys stored in Parameter Store are rotated before they expire. The team must be notified 7 days before expiration. What should they configure?**

A) Enable automatic rotation on the parameters
B) Upgrade to Advanced tier and create parameter policies with expiration and notification
C) Create a CloudWatch alarm on parameter age
D) Migrate to the Secret Vault — Parameter Store doesn't support expiration

**Answer: B**

**Why (Technical):** Advanced tier Parameter Store supports parameter policies — set an expiration date and notification policy (notify via EventBridge 7 days before expiry).

**Why (Analogy):** Upgrade the notice board to premium. Stamp an expiry date on notices and set an alarm to ring 7 days early — "This API key is about to go stale!"

**Why not A:** Parameter Store doesn't have built-in automatic rotation.
**Why not C:** CloudWatch doesn't have a built-in "parameter age" metric.
**Why not D:** Parameter Store DOES support expiration via Advanced tier parameter policies.

---

## Q4 (DVA-C02)
**A Lambda function calls Parameter Store 1,000 times per minute to fetch the same 5 parameters. The function is being throttled. How should they reduce API calls?**

A) Increase the Parameter Store throughput limit
B) Use the AWS Parameters and Config Lambda Extension to cache values
C) Store parameters in environment variables instead
D) Switch to Advanced tier for higher TPS

**Answer: B**

**Why (Technical):** The Lambda Extension caches Parameter Store and Secret Vault values locally within the execution environment. Fetch once, serve from cache until TTL expires.

**Why (Analogy):** Instead of sending a messenger to the notice board 1,000 times a minute, photocopy the 5 notices and pin them to your desk. Only send the messenger back when photocopies get stale.

**Why not A:** Costs money and doesn't solve the root cause — redundant calls.
**Why not C:** Environment variables are static at deploy time. Parameter changes need redeployment.
**Why not D:** Higher TPS costs money. Caching is the right architectural fix.

---

## Q5 (SAA-C03)
**A multi-account organization needs to share a database password across 5 AWS accounts. The password must auto-rotate every 60 days. What's the best architecture?**

A) Store in Parameter Store with cross-account IAM roles
B) Store in the Secret Vault with a resource policy granting access to the 5 accounts
C) Store in Parameter Store and replicate via AWS RAM
D) Store one copy per account in each account's Secret Vault

**Answer: B**

**Why (Technical):** Secret Vault supports resource-based policies for cross-account access. One credential, one rotation schedule, one source of truth.

**Why (Analogy):** Put the password in the vault at UN headquarters. Give diplomatic access (resource policy) to 5 member countries. Guards auto-change the combination every 60 days. Everyone always gets the latest from one place.

**Why not A:** Parameter Store doesn't have built-in auto-rotation.
**Why not C:** AWS RAM doesn't support sharing Parameter Store parameters.
**Why not D:** 5 copies = 5 rotation schedules = drift risk.

---

## Q6 (DVA-C02)
**A CloudFormation template needs to reference an RDS password stored in the Secret Vault without hardcoding. What syntax should the developer use?**

A) `!Ref SecretArn`
B) `{{resolve:secretsmanager:my-secret:SecretString:password}}`
C) `!GetAtt SecretResource.Password`
D) `Fn::ImportValue: SecretPassword`

**Answer: B**

**Why (Technical):** CloudFormation dynamic references use `{{resolve:}}` syntax to pull values at deploy time. For the Secret Vault: `{{resolve:secretsmanager:secret-id:SecretString:json-key}}`.

**Why (Analogy):** Don't write the password on the blueprint. Write "go check the vault" — `{{resolve:secretsmanager:...}}`. When the Ministry of Infrastructure builds, they visit the vault and use the current password. Blueprint never contains the actual value.

**Why not A:** `!Ref` references CFN resources or parameters, not external vaults.
**Why not C:** `!GetAtt` gets attributes from CFN resources, not external credential values.
**Why not D:** `Fn::ImportValue` imports cross-stack outputs, not vault values.

---

## Q7 (SOA-C02)
**After enabling automatic rotation on an RDS credential, the application gets authentication failures every 30 days. What's the most likely cause?**

A) The rotation Lambda doesn't have permission to update the RDS password
B) The application is caching the old password and not fetching the new one
C) The Secret Vault is in a different region than RDS
D) The KMS key used to encrypt the credential has expired

**Answer: B**

**Why (Technical):** When the vault rotates a password, the value updates immediately. If the app cached the old password (connection pool, env variable), it won't pick up the new one.

**Why (Analogy):** The vault guards changed the lock combination (rotation worked). But your team photocopied the old combination. They need to go back to the vault for the new one.

**Why not A:** If Lambda lacked permission, rotation would fail — not succeed and then cause auth errors.
**Why not C:** Cross-region works fine via replication.
**Why not D:** KMS keys don't "expire" — they can be disabled, but that causes decryption errors, not auth failures.

---

## Q8 (SAA-C03)
**A company needs to store 50,000 configuration parameters for a microservices architecture. None are sensitive. Cost must be minimized.**

A) Secret Vault — one entry per parameter
B) Parameter Store Standard tier
C) Parameter Store Advanced tier
D) Store all parameters in a single S3 JSON file

**Answer: C**

**Why (Technical):** Standard tier supports only 10,000 parameters. With 50,000 needed, Advanced tier is required (100,000 max).

**Why (Analogy):** The standard notice board has 10,000 slots. You need 50,000. Upgrade to premium (Advanced) — 100,000 slots. No need for the top-secret vault ($0.40 each × 50,000 = $20,000/month) when nothing is sensitive.

**Why not A:** $20,000/month for non-sensitive config. Insane.
**Why not B:** Standard tier maxes out at 10,000 parameters.
**Why not D:** S3 doesn't provide parameter-level access control or integration with Lambda/ECS/CloudFormation.

---

## Q9 (DVA-C02)
**A developer needs the same database endpoint in both a Lambda function and an ECS task. The endpoint might change during blue/green deployments. Best approach?**

A) Hardcode the endpoint in both application configs
B) Store in Parameter Store, reference from Lambda env vars and ECS task definition
C) Store in the Secret Vault with cross-service access
D) Use Route 53 private hosted zone for DNS-based discovery

**Answer: B**

**Why (Technical):** Parameter Store is the standard for shared config. Lambda env vars and ECS `valueFrom` both support Parameter Store ARNs. Update one parameter, both services pick up the change.

**Why (Analogy):** Post the database address on the notice board. Both the Lambda kitchen and ECS shipping port read from the same notice. Change one notice, everyone gets the update.

**Why not A:** Hardcoding means redeploying both services on every endpoint change.
**Why not C:** An endpoint URL isn't a credential — no need for vault overhead.
**Why not D:** DNS works but adds TTL-based caching delays. Parameter Store is simpler.
