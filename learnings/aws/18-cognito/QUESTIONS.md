# 18 — Cognito: Exam-Style Questions

---

## Q1: User Pool vs Identity Pool

A mobile app needs users to sign up with email and password, then upload photos directly to an S3 bucket. Which Cognito components are needed?

- **A)** User Pool only — it provides everything needed
- **B)** Identity Pool only — it handles sign-up and S3 access
- **C)** User Pool for authentication (sign-up/sign-in), then Identity Pool to exchange JWT for temporary AWS credentials for S3 access
- **D)** Neither — use IAM users for each mobile app user

**Correct Answer: C**

**Why:** You need BOTH offices. The User Pool (Visa Office) handles sign-up and sign-in, issuing JWT tokens. But JWT tokens can't be used to call AWS APIs directly — they're for your application, not AWS. The Identity Pool (Work Permit Office) exchanges the JWT for temporary AWS credentials (access key + secret key + session token) that the mobile app uses to upload to S3 directly. It's a two-step process: get your visa, then get your work permit.

- **A is wrong:** User Pool provides JWTs, but JWTs can't be used to call S3 PutObject. You need AWS credentials (STS temporary creds) for direct AWS API access.
- **B is wrong:** Identity Pool doesn't handle sign-up or sign-in. It only EXCHANGES tokens for AWS credentials. It needs a token from somewhere (User Pool, Google, Facebook, etc.).
- **D is wrong:** Creating IAM users for mobile app users doesn't scale and is a security anti-pattern. IAM users are for AWS operators, not application end users.

---

## Q2: JWT Token Types

A developer is building an API backend behind API Gateway with a Cognito Authorizer. Which JWT token should the mobile app send in the Authorization header?

- **A)** ID Token — it contains the user's identity
- **B)** Access Token — it's designed for API authorization
- **C)** Refresh Token — it's the most long-lived token
- **D)** Either ID Token or Access Token — both work with Cognito Authorizer

**Correct Answer: D**

**Why:** The Cognito Authorizer at API Gateway can validate BOTH ID tokens and Access tokens. However, they serve different purposes:
- **ID Token** → Use when your backend needs user identity claims (email, name, groups) — the Cognito Authorizer extracts these claims.
- **Access Token** → Use when you need scope-based authorization (fine-grained permissions).

Both are valid, and the Cognito Authorizer validates both. The choice depends on what your backend needs from the token.

- **A is wrong as "the only answer":** ID Token works, but it's not the only option.
- **B is wrong as "the only answer":** Access Token works, but it's not the only option.
- **C is wrong:** Refresh Tokens should NEVER be sent to APIs. They're only sent to Cognito itself to get new ID/Access tokens. Sending a refresh token to your API is a security risk — anyone who intercepts it can generate new tokens.

---

## Q3: Lambda Triggers — User Migration

A company is migrating from a legacy authentication system to Cognito. They have 500,000 users and don't want to force everyone to re-register. They also can't afford downtime for a bulk migration. What approach should they use?

- **A)** Export all users from the legacy system and bulk import into Cognito using the AdminCreateUser API
- **B)** Configure a User Migration Lambda trigger that authenticates users against the legacy system on their first sign-in
- **C)** Use Cognito federation to connect to the legacy system as an OIDC provider
- **D)** Send password reset emails to all 500,000 users asking them to create new Cognito accounts

**Correct Answer: B**

**Why:** The User Migration Lambda trigger enables lazy migration — users move to Cognito one by one, transparently, as they sign in. When a user tries to sign in and doesn't exist in Cognito, the Lambda trigger fires, checks the legacy system, and if the credentials are valid, creates the user in Cognito. The user doesn't even know the migration happened. Over time, all active users migrate naturally. Dormant users stay in the old system (no cost).

- **A is wrong:** Bulk import via AdminCreateUser doesn't preserve passwords (Cognito can't import password hashes from most legacy systems). All 500K users would need to reset their passwords. Also, this requires downtime coordination.
- **C is wrong:** Federation keeps the legacy system as the permanent identity provider. You'd be permanently dependent on it rather than migrating away.
- **D is wrong:** Asking 500K users to re-register has terrible user experience and low completion rates. Many users won't bother, and you'll lose customers.

---

## Q4: Pre-Token Generation Trigger

A developer needs to add a custom `department` claim to the JWT token based on data from a DynamoDB table (not stored in Cognito). What should they do?

- **A)** Add `department` as a custom attribute in the User Pool and populate it during sign-up
- **B)** Configure a Pre-Token Generation Lambda trigger that queries DynamoDB and adds the claim
- **C)** Configure a Post Authentication Lambda trigger to modify the token
- **D)** Parse the token on the client side and add the claim before sending to the API

**Correct Answer: B**

**Why:** Pre-Token Generation is the trigger that fires right before Cognito creates the JWT tokens. Your Lambda can add, modify, or suppress claims. It queries DynamoDB for the user's department and adds it to the token. The application receives a JWT with the `department` claim already included — no extra API calls needed. It's like a customs official stamping an extra visa category based on your employer's records.

- **A is wrong:** Custom attributes work, but the question says the data is in DynamoDB and changes dynamically. Custom attributes require explicit updates via Cognito API. Pre-Token Generation queries the latest data every time a token is generated.
- **C is wrong:** Post Authentication fires AFTER sign-in but BEFORE token generation. However, it doesn't have the ability to modify the token — it's for logging and side effects, not token customization.
- **D is wrong:** JWTs are SIGNED by Cognito. If you modify the token client-side, the signature is invalid and any verification will fail. You can't tamper with a signed JWT.

---

## Q5: Cognito Authorizer vs Lambda Authorizer

A company uses Cognito User Pool for authentication but also needs to check a custom database to verify the user's subscription is active before allowing API access. Which authorizer should they use at API Gateway?

- **A)** Cognito Authorizer — it handles all authentication and authorization
- **B)** Lambda Authorizer that validates the Cognito JWT AND checks the subscription database
- **C)** Both Cognito Authorizer and Lambda Authorizer in sequence
- **D)** IAM Authorizer with Cognito Identity Pool

**Correct Answer: B**

**Why:** The Cognito Authorizer only validates the JWT (signature, expiration, issuer). It doesn't do custom business logic like checking a subscription database. A Lambda Authorizer can do BOTH — validate the JWT AND query the subscription database. If the subscription is expired, the Lambda returns a deny policy. It's like having a custom border guard who checks both your visa AND whether your membership is paid up.

- **A is wrong:** Cognito Authorizer can't check external databases. It's a built-in validator with no custom logic capability.
- **C is wrong:** API Gateway doesn't support chaining two authorizers on the same method. It's one or the other.
- **D is wrong:** IAM Authorizer validates AWS SigV4 signatures, not JWT tokens. It's for machine-to-machine auth, not user authentication.

---

## Q6: Federation

A large enterprise wants their employees to sign into a web application using their corporate Active Directory credentials, without creating separate accounts in Cognito. What should they configure?

- **A)** Cognito User Pool with SAML 2.0 federation to Active Directory Federation Services (AD FS)
- **B)** Cognito Identity Pool with Active Directory as an identity provider
- **C)** AWS IAM Identity Center with Cognito
- **D)** Import all Active Directory users into the Cognito User Pool

**Correct Answer: A**

**Why:** SAML 2.0 federation lets Cognito accept "foreign passports" from AD FS. Employees authenticate with their corporate credentials (handled by AD FS), and Cognito issues its own JWT tokens. The app only deals with Cognito tokens — it doesn't need to know about Active Directory. The user's AD groups can be mapped to Cognito User Pool groups.

- **B is wrong:** Identity Pool is for exchanging tokens for AWS credentials, not for web application authentication. The question asks about signing into a web app, not accessing AWS resources.
- **C is wrong:** IAM Identity Center is for workforce access to the AWS console and business applications. It's not a building block for custom web application authentication.
- **D is wrong:** Importing users defeats the purpose of federation. Users would need separate passwords, and you'd need to keep Cognito in sync with AD — exactly what federation avoids.

---

## Q7: Unauthenticated Access

A mobile game wants to let users play and save progress without requiring sign-up. If they later create an account, their progress should carry over. How should this be implemented?

- **A)** Create a guest IAM user with limited permissions
- **B)** Use Cognito Identity Pool with unauthenticated access enabled, then merge identities when the user signs up
- **C)** Use a User Pool with auto-generated temporary accounts
- **D)** Store progress locally on the device with no cloud integration

**Correct Answer: B**

**Why:** Identity Pool supports unauthenticated (guest) identities. The guest gets an anonymous identity ID and temporary AWS credentials (mapped to a limited IAM role). Progress is saved to DynamoDB using this identity. When the user signs up (authenticates), Cognito can MERGE the guest identity with the new authenticated identity — all progress carries over. It's like playing on a temporary visitor pass, then getting a real membership card with all your visitor history attached.

- **A is wrong:** Creating IAM users per guest doesn't scale and is a security anti-pattern. IAM users are for AWS operators.
- **C is wrong:** User Pool requires sign-up (email, password). "Auto-generated temporary accounts" isn't a Cognito feature.
- **D is wrong:** Local-only storage means progress is lost if the user switches devices. The question implies cloud storage (save progress).

---

## Q8: Custom Auth Flow

A banking app requires OTP via SMS as the primary authentication method (no password). How should this be implemented in Cognito?

- **A)** Enable SMS-based MFA in the User Pool
- **B)** Implement a Custom Auth Flow using Define Auth Challenge, Create Auth Challenge, and Verify Auth Challenge Lambda triggers
- **C)** Use Cognito's built-in passwordless authentication
- **D)** Use SNS to send OTP and verify it in the application backend

**Correct Answer: B**

**Why:** Custom Auth Flow uses three Lambda triggers working together:
1. **Define Auth Challenge** — decides WHAT challenge to present (e.g., "send OTP")
2. **Create Auth Challenge** — generates the OTP and sends it via SNS
3. **Verify Auth Challenge** — checks if the user's response matches the OTP

This creates a fully custom, passwordless authentication flow within Cognito. You still get Cognito JWT tokens at the end.

- **A is wrong:** MFA is a SECOND factor — it requires a primary factor (password) first. The question asks for OTP as the PRIMARY (and only) method.
- **C is wrong:** While Cognito has been adding passwordless features, the exam-tested approach for custom passwordless flows is the Custom Auth Challenge pattern.
- **D is wrong:** Building OTP verification outside Cognito means you don't get Cognito tokens, user management, or integration with the rest of the Cognito ecosystem.

---

## Q9: Token Refresh

A user signed in 2 hours ago. Their ID and Access tokens have expired (default 1-hour validity). The app tries to call the API. What should happen?

- **A)** The user must sign in again — tokens can't be renewed
- **B)** The app uses the Refresh Token to get new ID and Access tokens from Cognito without requiring the user to sign in again
- **C)** The app sends the expired token and API Gateway accepts it with a grace period
- **D)** The Cognito Authorizer automatically refreshes the token when it detects expiration

**Correct Answer: B**

**Why:** The Refresh Token exists exactly for this scenario. It's the renewal stamp — the app sends it to Cognito's token endpoint, and Cognito returns fresh ID and Access tokens. The user doesn't need to re-enter their credentials. The Refresh Token has a much longer validity (default 30 days, up to 10 years). This is a standard OAuth 2.0 refresh flow.

- **A is wrong:** If users had to re-authenticate every hour, the UX would be terrible. Refresh Tokens solve this.
- **C is wrong:** API Gateway does NOT accept expired tokens. It strictly validates expiration. There's no grace period.
- **D is wrong:** The Cognito Authorizer doesn't refresh tokens. It only validates. Token refresh is the CLIENT's responsibility.

---

## Q10: Hosted UI Custom Domain

A company wants their Cognito sign-in page to appear at `auth.mycompany.com` instead of `mycompany.auth.us-east-1.amazoncognito.com`. What do they need?

- **A)** Create a Route 53 CNAME record pointing to the Cognito domain
- **B)** Configure a custom domain in the User Pool settings with an ACM certificate in us-east-1
- **C)** Deploy a CloudFront distribution in front of the Cognito hosted UI
- **D)** Use API Gateway custom domain to proxy the Cognito hosted UI

**Correct Answer: B**

**Why:** Cognito supports custom domains natively. You configure the domain in User Pool settings and provide an ACM certificate. The certificate MUST be in us-east-1 (because Cognito uses CloudFront behind the scenes, and CloudFront requires us-east-1 certificates). Then create a Route 53 alias record pointing to the Cognito custom domain.

- **A is wrong:** You can't just CNAME to the Cognito URL. You must configure the custom domain in Cognito first, which sets up the certificate and routing.
- **C is wrong:** You don't deploy your own CloudFront distribution. Cognito uses CloudFront internally for custom domains. Adding another CloudFront would add unnecessary complexity.
- **D is wrong:** API Gateway can't proxy Cognito's hosted UI. They're separate services with different architectures.

---

## Q11: Group-Based Authorization

A Cognito User Pool has three groups: Admins, Editors, and Viewers. A Lambda function behind API Gateway needs to check the user's group before allowing access. Where does the Lambda find the group information?

- **A)** Query the Cognito User Pool API using AdminGetUser to check group membership
- **B)** The `cognito:groups` claim in the JWT token already contains the user's groups
- **C)** Check the Identity Pool's role mapping for the user's group
- **D)** The group information is in the API Gateway request context, not the token

**Correct Answer: B**

**Why:** When a user is in Cognito groups, the group names are automatically included in the JWT token as the `cognito:groups` claim. The Lambda function decodes the JWT (which API Gateway passes in the request context after validation) and reads the groups. No extra API call needed — the information is already in the token. It's like the visa stamp already showing your visa category — the border guard doesn't need to call the visa office.

- **A is wrong:** While AdminGetUser works, it requires an extra API call on every request, adding latency and potentially hitting API rate limits. The token already has the information.
- **C is wrong:** Identity Pool role mapping is for AWS credential mapping, not application-level authorization. And the Lambda runs server-side with its own IAM role — it doesn't need the user's AWS credentials.
- **D is wrong:** API Gateway does include some Cognito claims in the request context, but the groups are in the JWT token itself. The Lambda should read the decoded token claims.

---

## Q12: Advanced Security

A Cognito-backed application detects that several user accounts are being accessed from unusual geographic locations after a third-party data breach. What Cognito feature would have proactively mitigated this?

- **A)** MFA enforcement on all users
- **B)** Cognito Advanced Security — adaptive authentication and compromised credential detection
- **C)** Shorter token validity periods
- **D)** Lambda Pre-Authentication trigger that checks IP geolocation

**Correct Answer: B**

**Why:** Cognito Advanced Security provides TWO features that address this scenario: (1) **Compromised credential detection** checks if a user's credentials appear in known breach databases and can block sign-in or force password change. (2) **Adaptive authentication** detects unusual sign-in patterns (new device, new location) and can require MFA or block the sign-in based on risk score. Both would have caught this attack proactively.

- **A is wrong:** MFA helps but doesn't detect compromised credentials or unusual patterns. If the attacker has the MFA device (e.g., SIM swapping), MFA alone isn't enough. Also, forcing MFA on all users impacts UX when it's not needed.
- **C is wrong:** Shorter token validity means tokens expire faster, but it doesn't prevent the INITIAL sign-in with stolen credentials. Once authenticated, the attacker has fresh tokens.
- **D is wrong:** A custom geolocation check is possible but requires building and maintaining the logic yourself. Advanced Security does this natively with ML-based risk scoring that's more sophisticated than simple geo-checking.
