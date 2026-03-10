# 18 — Cognito: The Visa Office

> **One-liner:** Cognito is the country's visa and immigration office — User Pools issue visas (authentication), Identity Pools issue temporary work permits (AWS credentials).

---

## ELI10

Imagine you're visiting a country. First, you go to the **Visa Office (User Pool)** — you fill out forms, show your passport, get verified, and receive a visa stamp (JWT token) that says who you are. But the visa only lets you walk around the country — it doesn't let you drive government vehicles or enter military bases. For that, you take your visa to the **Work Permit Office (Identity Pool)**, which checks your visa and gives you a temporary work permit (AWS credentials) that lets you access specific government resources. Some visitors don't even need to apply for a visa themselves — they bring a foreign passport from Google or Facebook (federation), and the visa office accepts it.

---

## The Concept

### The Two Halves

```
┌────────────────────────────────────────────────────────────────────┐
│                         COGNITO                                     │
│                    (Visa & Immigration)                              │
│                                                                      │
│  ┌─────────────────────────┐     ┌─────────────────────────┐       │
│  │      USER POOL          │     │     IDENTITY POOL        │       │
│  │   (Visa Office)         │     │   (Work Permit Office)   │       │
│  │                         │     │                           │       │
│  │  Purpose: WHO are you?  │     │  Purpose: WHAT can you   │       │
│  │  (Authentication)       │     │  access in AWS?           │       │
│  │                         │     │  (Authorization for AWS)  │       │
│  │  Output: JWT tokens     │     │  Output: Temporary AWS    │       │
│  │  (ID, Access, Refresh)  │     │  credentials (via STS)    │       │
│  │                         │     │                           │       │
│  │  Use: Sign up, sign in, │     │  Use: S3 upload, DynamoDB │       │
│  │  user management        │     │  query from mobile app    │       │
│  └────────────┬────────────┘     └──────────┬──────────────┘       │
│               │                              │                       │
│               │    JWT Token                 │  AWS Credentials      │
│               └──────────────────────────────┘                       │
│                                                                      │
│  Common flow: User Pool issues JWT → Identity Pool exchanges for    │
│  AWS credentials → User accesses AWS resources directly             │
└────────────────────────────────────────────────────────────────────┘
```

### User Pool = Visa Application Center

The User Pool handles everything about user identity:

```
┌────────────────────────── USER POOL ──────────────────────────┐
│                                                                │
│  SIGN UP:                                                      │
│  ├── Email/phone verification                                 │
│  ├── Custom attributes (department, employeeId)               │
│  ├── Password policies (min length, require symbols)          │
│  └── Self-service or admin-created accounts                    │
│                                                                │
│  SIGN IN:                                                      │
│  ├── Username + password                                       │
│  ├── Email + password                                          │
│  ├── Phone + password                                          │
│  └── Custom auth flows (Lambda triggers)                       │
│                                                                │
│  MFA:                                                          │
│  ├── SMS-based                                                 │
│  ├── TOTP (authenticator app)                                  │
│  └── Optional or required per user                             │
│                                                                │
│  FEDERATION:                                                    │
│  ├── Social: Google, Facebook, Apple, Amazon                   │
│  ├── SAML 2.0 (enterprise SSO — Okta, AD FS)                 │
│  └── OIDC (OpenID Connect providers)                           │
│                                                                │
│  OUTPUT: 3 JWT tokens                                          │
│  ├── ID Token      = Who you are (claims: email, name, groups) │
│  ├── Access Token   = What you can do (scopes, permissions)    │
│  └── Refresh Token  = Renew without re-login (30 day default) │
└────────────────────────────────────────────────────────────────┘
```

### JWT Tokens Deep Dive

```
┌──────────────────────────────────────────────────────────────┐
│                    THREE JWT TOKENS                            │
│                                                                │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────┐  │
│  │  ID Token     │  │ Access Token  │  │  Refresh Token    │  │
│  │               │  │               │  │                    │  │
│  │ "Your visa    │  │ "Your entry   │  │ "Your renewal     │  │
│  │  card with    │  │  permissions  │  │  stamp — come     │  │
│  │  your photo"  │  │  badge"       │  │  back without     │  │
│  │               │  │               │  │  re-applying"     │  │
│  │ Contains:     │  │ Contains:     │  │                    │  │
│  │ - sub (userId)│  │ - scope       │  │ Validity:          │  │
│  │ - email       │  │ - client_id   │  │ Default 30 days    │  │
│  │ - name        │  │ - groups      │  │ Range: 60min-10yr  │  │
│  │ - groups      │  │ - token_use:  │  │                    │  │
│  │ - custom attrs│  │   "access"    │  │ Used to get new    │  │
│  │               │  │               │  │ ID + Access tokens │  │
│  │ Validity:     │  │ Validity:     │  │ without re-login   │  │
│  │ Default 1 hour│  │ Default 1 hour│  │                    │  │
│  │ Range: 5m-1d  │  │ Range: 5m-1d  │  │                    │  │
│  └──────────────┘  └───────────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────────┘

WHERE TO SEND EACH TOKEN:
- ID Token     → Your own backend (verify user identity)
- Access Token → API Gateway (Cognito Authorizer checks this)
- Refresh Token → Cognito only (exchange for new tokens)
```

### Identity Pool = Temporary Work Permit Office

Identity Pools trade identity tokens for AWS credentials:

```
Mobile App                 Identity Pool                AWS Resources
    │                          │                            │
    │── JWT from User Pool ───→│                            │
    │   OR Google token        │                            │
    │   OR SAML assertion      │                            │
    │                          │── STS AssumeRole ─────────→│
    │                          │   (mapped to IAM role)     │
    │                          │                            │
    │←── Temp AWS Creds ───────│                            │
    │    (AccessKey,           │                            │
    │     SecretKey,           │                            │
    │     SessionToken)        │                            │
    │                          │                            │
    │── Direct AWS API call ───┼────────────────────────────→│
    │   (S3, DynamoDB, etc.)   │                            │
```

**Two types of identities:**
- **Authenticated** → Gets the "authenticated" IAM role (more permissions)
- **Unauthenticated (guest)** → Gets the "unauthenticated" IAM role (limited permissions)

**Role mapping:** You can map different groups to different IAM roles:
- Admin group → AdminRole (full access)
- User group → UserRole (limited access)
- Guest → GuestRole (read-only)

### User Pool vs Identity Pool Decision Tree

```
                "I need user authentication"
                          │
               ┌──────────┴──────────┐
               │                      │
    Need sign-up/sign-in?     Need AWS API access
    Need JWT tokens?          from client-side?
    Need user management?     (S3 upload, DynamoDB query)
               │                      │
          USER POOL              IDENTITY POOL
               │                      │
               │    Often used        │
               └───── TOGETHER ───────┘

    API Gateway + Lambda backend → User Pool only (JWT auth)
    Mobile app accessing S3 directly → Both (User Pool + Identity Pool)
    Guest access to S3 → Identity Pool only (unauthenticated role)
```

---

## Cognito + API Gateway

```
Client              API Gateway           Lambda
  │                     │                    │
  │── Request + ───────→│                    │
  │   JWT token         │                    │
  │   (Authorization    │── Verify JWT ──→   │
  │    header)          │   (Cognito         │
  │                     │    Authorizer)     │
  │                     │                    │
  │                     │── If valid ────────→│
  │                     │   Forward request  │
  │                     │   with claims      │
  │                     │                    │
  │←── Response ────────│←── Response ───────│
```

**Two authorizer types:**
1. **Cognito Authorizer** — built-in, validates User Pool JWT automatically
2. **Lambda Authorizer** — custom logic, can validate any token type

**Cognito Authorizer** checks:
- Token signature (signed by User Pool)
- Token expiration
- Token issuer (iss claim = User Pool URL)
- Optionally: scopes (defined in Access Token)

---

## Lambda Triggers = Custom Processing at Each Step

```
┌──────────────────────────────────────────────────────────────────┐
│                  LAMBDA TRIGGER POINTS                             │
│                                                                    │
│  SIGN-UP FLOW:                                                     │
│  ├── Pre Sign-Up         → Validate/modify before creating user   │
│  │                         (auto-confirm, block domains)           │
│  └── Post Confirmation   → Send welcome email, create DB record   │
│                                                                    │
│  SIGN-IN FLOW:                                                     │
│  ├── Pre Authentication  → Custom validation before sign-in       │
│  │                         (check blacklist, rate limit)           │
│  ├── Post Authentication → Log sign-in, update last-login          │
│  ├── Pre Token Generation→ Add/remove claims from JWT              │
│  │                         (add custom data to tokens)             │
│  └── Token Generation    → Customize ID and Access tokens          │
│                                                                    │
│  CUSTOM AUTH:                                                      │
│  ├── Define Auth Challenge → What challenge to present?            │
│  ├── Create Auth Challenge → Generate the challenge (OTP, CAPTCHA) │
│  └── Verify Auth Challenge → Check the user's answer               │
│                                                                    │
│  OTHER:                                                            │
│  ├── Custom Message      → Customize verification emails/SMS      │
│  ├── User Migration      → Import users on-the-fly from old system│
│  └── Custom Email Sender → Send via SES instead of default Cognito│
└──────────────────────────────────────────────────────────────────┘
```

### User Migration Trigger

Migrate users from a legacy system WITHOUT a bulk import:

```
Old System                Cognito User Pool              Lambda
    │                          │                            │
    │                          │←── User tries to sign in  │
    │                          │    (user not found)        │
    │                          │                            │
    │                          │── Trigger Migration ──────→│
    │                          │   Lambda                   │
    │                          │                            │
    │←─── Lambda checks ──────┼────────────────────────────│
    │     old system           │                            │
    │──── User found! ────────→│                            │
    │     Return credentials   │                            │
    │                          │── Create user in pool ────→│
    │                          │   (transparent to user)    │
    │                          │                            │
```

Next time the user signs in, they exist in Cognito directly. Lazy migration — users move over one by one as they sign in.

---

## User Pool Groups = Visa Categories

```
User Pool: MyApp
├── Group: Admins     → IAM Role: AdminRole    → Priority: 1
├── Group: Managers   → IAM Role: ManagerRole  → Priority: 2
├── Group: Staff      → IAM Role: StaffRole    → Priority: 3
└── Group: Users      → IAM Role: UserRole     → Priority: 4

A user can be in multiple groups.
Priority determines which IAM role is used (lowest number wins).
Group membership appears in the JWT token (cognito:groups claim).
```

---

## Hosted UI = Pre-Built Visa Application Form

Cognito provides a hosted sign-in/sign-up page out of the box:

```
https://<your-domain>.auth.<region>.amazoncognito.com/login
  ?client_id=abc123
  &response_type=code
  &scope=openid+email+profile
  &redirect_uri=https://myapp.com/callback
```

- **Customizable:** Logo, CSS, custom domain
- **Supports:** Sign up, sign in, forgot password, MFA, federation
- **OAuth 2.0 flows:** Authorization Code, Implicit, Client Credentials
- **Good for:** Quick MVPs, internal tools, anywhere you don't need a fully custom UI

---

## Federation = Accept Foreign Passports

```
┌─────────────────────────────────────────────────────┐
│           FEDERATION OPTIONS                          │
│                                                       │
│  SOCIAL IDENTITY PROVIDERS:                           │
│  ├── Google   → OpenID Connect                       │
│  ├── Facebook → OAuth 2.0                            │
│  ├── Apple    → OpenID Connect                       │
│  └── Amazon   → OAuth 2.0                            │
│                                                       │
│  ENTERPRISE IDENTITY PROVIDERS:                       │
│  ├── SAML 2.0  → Active Directory, Okta, OneLogin   │
│  └── OIDC      → Any OpenID Connect provider         │
│                                                       │
│  Flow:                                                │
│  1. User clicks "Sign in with Google"                │
│  2. Redirected to Google → authenticates             │
│  3. Google returns token to Cognito                  │
│  4. Cognito maps Google user to User Pool user       │
│  5. Cognito issues its own JWT tokens                │
│  6. App receives Cognito JWTs (uniform format)       │
│                                                       │
│  Key: Cognito normalizes all providers into one      │
│  consistent token format for your app.               │
└─────────────────────────────────────────────────────┘
```

---

## Advanced Security Features

- **Adaptive authentication:** Risk-based authentication — if sign-in looks unusual (new device, new IP, new country), require MFA or block
- **Compromised credentials detection:** Check if username/password appears in public breach databases
- **Advanced security metrics:** Dashboard of risky sign-ins, compromised credentials, auth events
- **Cost:** Additional per-MAU charge for advanced security

---

## Architecture: Full Cognito Authentication Flow

```
┌─────────┐     ┌──────────────┐     ┌─────────────┐     ┌────────────┐
│  Mobile  │     │   Cognito    │     │ API Gateway │     │   Lambda   │
│  App     │     │  User Pool   │     │             │     │  Backend   │
│          │     │              │     │             │     │            │
│ Sign Up ─┼────→│ Create User  │     │             │     │            │
│          │     │ Verify Email │     │             │     │            │
│          │     │              │     │             │     │            │
│ Sign In ─┼────→│ Authenticate │     │             │     │            │
│          │←────┤ Return JWTs  │     │             │     │            │
│          │     │              │     │             │     │            │
│ API Call─┼─────┼──────────────┼────→│ Cognito     │     │            │
│ + JWT    │     │              │     │ Authorizer  │     │            │
│          │     │              │     │ validates   │────→│ Process    │
│          │     │              │     │ JWT         │     │ request    │
│          │←────┼──────────────┼─────┼─────────────┼─────┤ Return     │
│          │     │              │     │             │     │ response   │
└─────────┘     └──────────────┘     └─────────────┘     └────────────┘

For direct AWS access (S3, DynamoDB from mobile):
┌─────────┐     ┌──────────┐     ┌───────────────┐     ┌──────────┐
│  Mobile  │────→│ Identity │────→│  STS          │────→│  S3      │
│  App     │ JWT │  Pool    │     │  AssumeRole   │     │  DynamoDB│
│          │←────┤          │←────┤  Temp Creds   │     │          │
│          │creds│          │     │               │     │          │
│          │─────┼──────────┼─────┼───────────────┼────→│  Direct  │
│          │     │          │     │               │     │  Access  │
└─────────┘     └──────────┘     └───────────────┘     └──────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- User Pool vs Identity Pool — when to use each
- Cognito + API Gateway (Cognito Authorizer)
- Federation with SAML for enterprise SSO
- Identity Pool for mobile app accessing S3/DynamoDB directly
- Guest (unauthenticated) access via Identity Pool

### DVA-C02 (Developer)
- JWT token types (ID vs Access vs Refresh)
- Lambda triggers — which trigger for which use case
- Custom auth flows (Define/Create/Verify Auth Challenge)
- Pre-token generation trigger (add custom claims)
- User migration trigger (lazy migration from legacy systems)
- OAuth 2.0 flows (Authorization Code, Implicit, Client Credentials)

### SOA-C02 (SysOps)
- User Pool configuration (password policy, MFA, email verification)
- Advanced security features (adaptive auth, compromised credential detection)
- Custom domain setup for hosted UI
- User pool federation configuration
- CloudWatch metrics for Cognito (sign-in success/failure rates)
- Token validity configuration

---

## Key Numbers

| Item | Value |
|------|-------|
| ID Token default validity | **1 hour** (range: 5 min to 1 day) |
| Access Token default validity | **1 hour** (range: 5 min to 1 day) |
| Refresh Token default validity | **30 days** (range: 60 min to 10 years) |
| Max user pools per account | **1,000** (soft limit) |
| Max app clients per user pool | **300** |
| Max groups per user pool | **300** |
| Max identity providers per user pool | **300** |
| Custom attributes per user pool | **50** |
| Username max length | **128 characters** |
| Password max length | **256 characters** |
| Lambda trigger timeout | **No timeout override — standard Lambda limits apply** |
| User migration trigger | **Invoked only on sign-in, not on sign-up** |

---

## Cheat Sheet

- **User Pool = authentication (who are you?) → JWT tokens**
- **Identity Pool = authorization for AWS (what AWS resources can you access?) → temp AWS credentials**
- **3 JWT tokens:** ID (identity claims), Access (permissions/scopes), Refresh (renew without re-login)
- **Cognito Authorizer** at API Gateway validates JWT — built-in, no Lambda needed
- **Lambda Authorizer** = custom validation logic (any token type, any provider)
- **ID Token** goes to your backend. **Access Token** goes to API Gateway. **Refresh Token** stays with the client.
- **Federation:** Social (Google, Facebook) + Enterprise (SAML, OIDC). Cognito normalizes all to its own JWTs.
- **User Migration trigger** = lazy migration. Users move from legacy to Cognito one-by-one as they sign in.
- **Pre-token generation trigger** = add custom claims to JWT (department, permissions, etc.)
- **Custom auth flow:** Define → Create → Verify Auth Challenge (3 Lambda triggers)
- **Groups** have priority — lowest number wins when user is in multiple groups
- **Hosted UI** = quick sign-in/sign-up page with custom domain support
- **Advanced security** = risk-based auth + compromised credential detection (extra cost)
- **Identity Pool roles:** Authenticated role (logged-in users) + Unauthenticated role (guests)
- **Refresh Token** default 30 days, max 10 years. ID/Access default 1 hour, max 1 day.
- **Cognito ≠ IAM Identity Center** — Cognito is for app users, IAM Identity Center is for workforce (employees accessing AWS console)
- **Custom attributes are immutable** once created — can't change the name or type
- **App client** = the entry point for your application. Each client can have different auth flows, scopes, and settings.
