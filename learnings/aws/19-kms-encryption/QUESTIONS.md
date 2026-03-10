# 19 — KMS & Encryption: Exam-Style Questions

---

## Q1: Envelope Encryption

A developer needs to encrypt a 10 MB file using KMS. They call `kms:Encrypt` with the file contents and receive an error. What is the issue and the correct approach?

- **A)** The file is too large — split it into 4 KB chunks and encrypt each chunk
- **B)** The `kms:Encrypt` API has a 4 KB limit — use `GenerateDataKey` to get a data encryption key, encrypt the file locally with the DEK, then store the encrypted DEK alongside the encrypted file
- **C)** KMS cannot encrypt files — use S3 server-side encryption instead
- **D)** The KMS key is too small — create a larger key size

**Correct Answer: B**

**Why:** KMS Encrypt API has a 4 KB limit on data size. This is by design — KMS is a KEY management service, not a data encryption service. For data larger than 4 KB, use envelope encryption: call `GenerateDataKey`, which returns a plaintext DEK and an encrypted DEK. Encrypt the file locally with the plaintext DEK. Store the encrypted file + encrypted DEK together. Discard the plaintext DEK. This is the locksmith making you a copy key — the master key stays in the vault.

- **A is wrong:** Encrypting 2,500 chunks of 4 KB each would require 2,500 KMS API calls — expensive, slow, and hits rate limits. Envelope encryption uses ONE API call.
- **C is wrong:** KMS absolutely can encrypt files — just not directly for files > 4 KB. GenerateDataKey is the mechanism for larger data.
- **D is wrong:** KMS key "size" isn't configurable in this way. The 4 KB limit is on the Encrypt API input, not the key strength.

---

## Q2: S3 Encryption Options

A company requires that all S3 objects be encrypted with a key they can audit and rotate on their own schedule. They want to use AWS-managed infrastructure (not client-side encryption). Which option should they use?

- **A)** SSE-S3 (AES-256)
- **B)** SSE-KMS with an AWS managed key (aws/s3)
- **C)** SSE-KMS with a Customer managed key
- **D)** SSE-C with a customer-provided key

**Correct Answer: C**

**Why:** Customer managed KMS keys give you full control: you define the key policy (who can use it), you can enable/disable rotation, you get CloudTrail audit logs of every use, and you can revoke access at any time. The key is still managed by KMS infrastructure (AWS-managed hardware), but YOU control the policy and lifecycle. It's like having your own named key at the national locksmith — the locksmith holds it, but you decide who gets copies.

- **A is wrong:** SSE-S3 uses keys managed entirely by AWS. You can't audit key usage, can't control rotation, and can't restrict key access.
- **B is wrong:** AWS managed keys (aws/s3) rotate automatically but you can't control the schedule, can't define the key policy, and have limited audit capability.
- **D is wrong:** SSE-C requires YOU to provide the key with every request and manage it entirely. This is "AWS-managed infrastructure for storage" but NOT for the key. Also, the question asks for AWS-managed infrastructure, which SSE-C partially violates (you manage the key).

---

## Q3: Cross-Account Encryption

Account A has an S3 bucket with SSE-KMS encryption using a Customer managed key. Account B needs to read objects from this bucket. Account B has an IAM policy allowing `s3:GetObject`. They still get Access Denied. Why?

- **A)** The S3 bucket policy doesn't allow Account B
- **B)** Account B also needs `kms:Decrypt` permission on Account A's KMS key, AND the key policy must allow Account B
- **C)** SSE-KMS encrypted objects cannot be shared across accounts
- **D)** Account B needs to use their own KMS key to decrypt

**Correct Answer: B**

**Why:** When you download an SSE-KMS encrypted object, S3 calls KMS to decrypt the data encryption key. This requires `kms:Decrypt` permission on the specific KMS key. For cross-account access, THREE things must align: (1) S3 bucket policy allows Account B, (2) Account B's IAM policy allows `s3:GetObject` AND `kms:Decrypt`, (3) the KMS key policy allows Account B. Miss any one, and you get Access Denied. It's like needing BOTH the warehouse entry badge AND the locksmith's permission to unlock the safe.

- **A is wrong:** While the bucket policy might also be an issue, the question states Account B already has `s3:GetObject`. The missing piece is KMS access.
- **C is wrong:** SSE-KMS encrypted objects CAN be shared — you just need to grant KMS access to the other account.
- **D is wrong:** The decryption must use the SAME key that encrypted the data. You can't decrypt with a different key. Account B needs access to Account A's key.

---

## Q4: Key Rotation

A security audit requires that all encryption keys be rotated annually. The company uses Customer managed KMS keys. What happens when automatic rotation is enabled?

- **A)** The old key is deleted and a new key with a new key ID is created
- **B)** New key material is generated but the key ID stays the same. Old key material is preserved for decrypting previously encrypted data.
- **C)** All data encrypted with the old key material must be re-encrypted with the new key material
- **D)** The key is disabled for 24 hours during rotation

**Correct Answer: B**

**Why:** KMS rotation is seamless. New key material is generated, but the key ID and ARN don't change. Old key material is kept — data encrypted before rotation can still be decrypted. KMS automatically selects the correct key material version based on the encryption context. Applications don't need any changes. It's like the locksmith cutting a new master key but keeping the old one in a drawer — old locks still work with the old key, new locks use the new key.

- **A is wrong:** The key ID stays the same. Deleting old key material would make previously encrypted data unrecoverable. That would be catastrophic.
- **C is wrong:** Re-encryption is NOT required. KMS tracks which key material version encrypted each DEK and uses the correct version for decryption.
- **D is wrong:** There's no downtime during rotation. The process is instantaneous and transparent.

---

## Q5: KMS Key Deletion

A developer accidentally schedules a Customer managed KMS key for deletion (7-day waiting period). This key encrypts a critical production database. What should they do IMMEDIATELY?

- **A)** Nothing — the key won't be deleted for 7 days
- **B)** Cancel the key deletion using the `CancelKeyDeletion` API, then disable the key instead if it's truly no longer needed
- **C)** Create a backup of the key material before the 7-day period expires
- **D)** Re-encrypt all data with a new key before the deletion completes

**Correct Answer: B**

**Why:** During the waiting period, the scheduled deletion CAN be cancelled. Call `CancelKeyDeletion` immediately — this is exactly what the waiting period is for. The key returns to "Disabled" state after cancellation (re-enable it for use). If the key is truly unneeded later, disable it instead of deleting — disabled keys can be re-enabled, deleted keys are GONE FOREVER.

- **A is wrong:** Doing nothing is reckless. The key IS being deleted in 7 days. If nobody cancels it, the production database becomes unreadable.
- **C is wrong:** KMS doesn't allow exporting key material (for keys generated by KMS). The key material NEVER leaves KMS. You can't back it up.
- **D is wrong:** While re-encrypting would work, it's a massive operation on a production database. Cancelling the deletion is instant and risk-free.

---

## Q6: KMS API Throttling

A Lambda function processes millions of S3 events per day. Each event triggers a `kms:Decrypt` call because the S3 objects are SSE-KMS encrypted. The team is seeing `ThrottlingException` errors from KMS. What are TWO valid solutions?

- **A)** Switch to SSE-S3 encryption (if KMS audit trail isn't required)
- **B)** Request a KMS API quota increase for the region
- **C)** Use SSE-C encryption to avoid KMS entirely
- **D)** Implement exponential backoff and retry with jitter in the Lambda code
- **E)** Cache the decrypted data encryption keys on the Lambda function

**Correct Answer: A, B**

**Why A:** If the compliance requirement doesn't mandate KMS-level audit trails, switching to SSE-S3 eliminates KMS API calls entirely. S3 manages encryption transparently with no API quota concerns.

**Why B:** KMS quotas are soft limits that can be increased. Requesting a higher limit is the standard solution when your workload legitimately needs more throughput.

- **C is wrong:** SSE-C requires YOU to manage and provide encryption keys with every request. This is a massive operational burden and doesn't scale for automated Lambda processing.
- **D is wrong:** Exponential backoff helps with transient errors but doesn't solve a fundamental throughput limit. If you're hitting the quota consistently, retries just delay the problem.
- **E is wrong:** Lambda doesn't cache DEKs across invocations by default. While the KMS SDK has built-in caching (and the S3 Encryption Client caches data keys), this is about S3 server-side decryption, which the Lambda doesn't control — S3 calls KMS internally.

---

## Q7: CloudHSM vs KMS

A healthcare company must encrypt patient data and their compliance team requires FIPS 140-2 Level 3 certified key storage. Which service should they use?

- **A)** KMS with Customer managed keys (FIPS 140-2 Level 2)
- **B)** CloudHSM (FIPS 140-2 Level 3)
- **C)** KMS with imported key material
- **D)** S3 SSE-S3 with bucket policies

**Correct Answer: B**

**Why:** CloudHSM provides FIPS 140-2 Level 3 certified hardware security modules — dedicated, single-tenant devices in your VPC. Level 3 includes tamper-evident physical security mechanisms and identity-based authentication. KMS is Level 2 (which doesn't include physical tamper resistance). When compliance explicitly requires Level 3, CloudHSM is the only answer. It's like the difference between a bank's general safe deposit room (KMS) and a private vault with biometric locks (CloudHSM).

- **A is wrong:** KMS is Level 2, the requirement is Level 3. No amount of configuration changes KMS's certification level.
- **C is wrong:** Importing key material into KMS doesn't change the underlying hardware certification. The HSMs backing KMS are still Level 2.
- **D is wrong:** SSE-S3 uses AWS-managed keys with no compliance certifications you can reference for FIPS requirements.

---

## Q8: Encryption Context

A developer uses KMS to encrypt sensitive documents. They want to add a layer of access control so that even if someone has `kms:Decrypt` permission, they can only decrypt documents they're authorized for. What should they use?

- **A)** KMS key policies with condition keys
- **B)** Encryption context — include document metadata (e.g., `department: finance`) in encrypt/decrypt calls, and use IAM conditions to restrict based on encryption context
- **C)** Create a separate KMS key for each document type
- **D)** Use grants to provide per-document access

**Correct Answer: B**

**Why:** Encryption context is a key-value pair passed during Encrypt and Decrypt calls. The SAME encryption context must be provided for both operations — if you encrypt with `{"department": "finance"}`, you must provide the same context to decrypt. You can then use IAM policy conditions to restrict: "This role can only call kms:Decrypt when the encryption context department = finance." It's like adding a combination lock ON TOP of the key lock — you need both the key and the right combination.

- **A is wrong:** Key policies control WHO can use the key, not fine-grained access per document. You'd need one key per department, which is option C (and doesn't scale well).
- **C is wrong:** Creating keys per document type is an operational nightmare. With thousands of document types, you'd have thousands of keys. Encryption context achieves the same granularity with one key.
- **D is wrong:** Grants provide temporary access to a key but don't differentiate between documents encrypted with the same key.

---

## Q9: Imported Key Material

A company has a regulatory requirement to generate their own key material in their on-premises HSM and use it within AWS KMS. What are the limitations?

- **A)** No limitations — imported key material works exactly like KMS-generated material
- **B)** Imported key material cannot be automatically rotated, you must rotate manually, and you can set an expiration date
- **C)** Imported key material can only be used with S3 encryption
- **D)** Imported key material provides FIPS 140-2 Level 3 certification

**Correct Answer: B**

**Why:** When you import key material:
- **No automatic rotation** — you must create a new key and import new material manually
- **Expiration date** — you can (optionally) set when the material expires. After expiry, the key can't encrypt/decrypt until you re-import material
- **Deletion** — you can delete JUST the key material (without deleting the key), then re-import later
- **Can't get it back** — if you delete the KMS key (not just material), the material is gone from KMS

It's like bringing your own master key to the national locksmith — they'll use it, but they can't duplicate it or automatically rotate it for you.

- **A is wrong:** Several limitations exist, most importantly no automatic rotation.
- **C is wrong:** Imported key material works with any KMS-integrated service, not just S3.
- **D is wrong:** Importing key material into KMS doesn't change KMS's FIPS certification level. The key material is now IN KMS hardware (Level 2).

---

## Q10: Symmetric vs Asymmetric

An application running OUTSIDE of AWS (on-premises) needs to encrypt data before sending it to S3. The on-premises system cannot make AWS API calls. What type of KMS key should be used?

- **A)** Symmetric KMS key — download the key and use it on-premises
- **B)** Asymmetric KMS key — download the public key and encrypt on-premises
- **C)** AWS managed key (aws/s3) — use it via the AWS SDK
- **D)** Client-side encryption with a locally generated key (no KMS involvement)

**Correct Answer: B**

**Why:** Asymmetric KMS keys have a public key that CAN be downloaded. The on-premises system encrypts data with the public key (no AWS API call needed). Only the private key (which stays in KMS) can decrypt. This is perfect for scenarios where the encryptor can't access AWS APIs. It's like the locksmith giving you a padlock (public key) — anyone can lock things with it, but only the locksmith has the key to open it.

- **A is wrong:** Symmetric key material NEVER leaves KMS. You can't download it. That's the fundamental security guarantee of KMS.
- **C is wrong:** AWS managed keys can't be downloaded or used outside KMS. And the system can't make AWS API calls, so it can't call KMS Encrypt.
- **D is wrong:** While this works, you lose KMS's key management, rotation, auditing, and access control. The question implies they WANT to use KMS (and it's the best practice).

---

## Q11: KMS + Lambda Environment Variables

A Lambda function has database credentials stored in environment variables encrypted with a Customer managed KMS key. The Lambda runs but fails with an AccessDeniedException when trying to decrypt the environment variables. What is the likely cause?

- **A)** Lambda doesn't support encrypted environment variables
- **B)** The Lambda function's execution role lacks `kms:Decrypt` permission on the Customer managed key
- **C)** The environment variables exceeded the 4 KB KMS limit
- **D)** The KMS key is in a different region than the Lambda function

**Correct Answer: B**

**Why:** Lambda encrypts environment variables with KMS. When using a Customer managed key, the Lambda execution role needs explicit `kms:Decrypt` permission on that key. With the default AWS managed key (aws/lambda), this permission is automatic. But when you switch to a Customer managed key, you must update both the IAM role (add kms:Decrypt) and the key policy (allow the Lambda role). The field agent has the right to enter the building but hasn't been given the key to the safe.

- **A is wrong:** Lambda absolutely supports encrypted environment variables — it's a core feature.
- **C is wrong:** Environment variables have a 4 KB total size limit, but this is a Lambda limit, not a KMS limit. The encryption of env vars uses envelope encryption internally, so the 4 KB KMS limit doesn't apply.
- **D is wrong:** Lambda and the KMS key must be in the same region (or use a multi-region key), but the error would be "key not found" rather than "AccessDeniedException."

---

## Q12: KMS Condition Keys

A security team wants to ensure that a specific KMS key can ONLY be used by S3 for server-side encryption — not directly by users or other services. What should they add to the key policy?

- **A)** A condition using `kms:CallerAccount` to restrict to the S3 service account
- **B)** A condition using `kms:ViaService` to restrict the key to only `s3.ap-southeast-2.amazonaws.com`
- **C)** Remove all IAM user permissions from the key policy
- **D)** Enable the key only during S3 operations using a Lambda trigger

**Correct Answer: B**

**Why:** `kms:ViaService` is a KMS condition key that restricts key usage to requests coming through a specific AWS service. Setting it to `s3.ap-southeast-2.amazonaws.com` means the key can ONLY be used when S3 is making the KMS call (during SSE-KMS encryption/decryption). Direct `kms:Encrypt` or `kms:Decrypt` calls from users or other services are denied. It's like telling the locksmith: "Only give the key to the S3 warehouse manager — nobody else."

- **A is wrong:** `kms:CallerAccount` restricts by AWS account, not by service. Users in the same account could still call KMS directly.
- **C is wrong:** Removing IAM user permissions would prevent management of the key. And service-linked roles or other mechanisms could still use it.
- **D is wrong:** KMS doesn't support Lambda triggers for key access decisions. Key policies and conditions are the mechanism for access control.
