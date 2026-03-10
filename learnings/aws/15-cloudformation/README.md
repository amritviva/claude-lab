# 15 — CloudFormation: The Ministry of Infrastructure Planning

> **One-liner:** CloudFormation is the Ministry of Urban Planning — you submit blueprints, and it builds entire cities of infrastructure from them, every time, exactly the same.

---

## ELI10

Imagine you're the chief city planner. Instead of telling builders "go build a hospital here, then a road there" one by one, you draw a complete blueprint of the whole city — every building, road, pipe, and wire. You hand that blueprint to the Ministry of Infrastructure, and they build the entire city exactly as drawn. If you want the same city in another region, hand them the same blueprint. If something goes wrong during construction, they tear it all down and start fresh so you never end up with a half-built mess.

---

## The Concept

### Template = The Blueprint

A CloudFormation template is a YAML or JSON file describing your entire infrastructure. It has specific sections:

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "My city blueprint"

Parameters:        # Permit forms (user inputs at deploy time)
Mappings:          # Regional codebooks (lookup tables)
Conditions:        # Traffic signals (if/then logic)
Resources:         # The actual buildings (ONLY REQUIRED SECTION)
Outputs:           # Completion certificates (exported values)
Transform:         # Macro processors (e.g., AWS::Serverless)
Metadata:          # Notes on the blueprint
Rules:             # Validation rules for parameters
```

### Template Sections Deep Dive

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUDFORMATION TEMPLATE                        │
│                      (City Blueprint)                             │
│                                                                   │
│  ┌─────────────┐  "What size buildings do you want?"             │
│  │ Parameters   │  - InstanceType: t3.micro / t3.large           │
│  │ (Permit      │  - Environment: dev / staging / prod           │
│  │  Forms)      │  - DBPassword: NoEcho (hidden input)           │
│  └──────┬──────┘  Types: String, Number, List, AWS SSM param     │
│         │                                                         │
│  ┌──────▼──────┐  "Region-specific building codes"               │
│  │ Mappings     │  RegionMap:                                     │
│  │ (Regional    │    us-east-1:                                   │
│  │  Codebooks)  │      AMI: ami-12345                             │
│  └──────┬──────┘    ap-southeast-2:                               │
│         │              AMI: ami-67890                              │
│  ┌──────▼──────┐                                                  │
│  │ Conditions   │  "Build the pool ONLY if environment = prod"   │
│  │ (Traffic     │  IsProduction:                                  │
│  │  Signals)    │    !Equals [!Ref Environment, "prod"]          │
│  └──────┬──────┘                                                  │
│         │                                                         │
│  ┌──────▼──────┐  THE ACTUAL INFRASTRUCTURE                      │
│  │ Resources    │  - EC2 Instance (office building)               │
│  │ (Buildings)  │  - RDS Database (data warehouse)                │
│  │  *REQUIRED*  │  - S3 Bucket (storage facility)                │
│  └──────┬──────┘  - VPC, Subnets, Security Groups...             │
│         │                                                         │
│  ┌──────▼──────┐  "Here are the addresses of what we built"      │
│  │ Outputs      │  - VPC ID, Subnet IDs, Endpoint URLs           │
│  │ (Completion  │  - Can be EXPORTED for cross-stack references   │
│  │ Certificates)│  Export: Name: "prod-vpc-id"                   │
│  └─────────────┘                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Stack = One Construction Project

When you deploy a template, CloudFormation creates a **stack** — one complete construction project. The stack tracks every resource it created and manages their lifecycle.

```
Template (blueprint)
    │
    ├─→ Stack: dev-environment   (development city)
    ├─→ Stack: staging-environment (staging city)
    └─→ Stack: prod-environment  (production city)

Same blueprint, three different cities.
```

### StackSet = Franchise Rollout

Deploy the same blueprint across multiple accounts AND/OR regions simultaneously.

```
StackSet: "security-baseline"
    │
    ├─→ Account 111: us-east-1  ✓
    ├─→ Account 111: eu-west-1  ✓
    ├─→ Account 222: us-east-1  ✓
    ├─→ Account 222: eu-west-1  ✓
    └─→ Account 333: us-east-1  ✓

Like opening the same franchise in 5 locations simultaneously.
```

- Requires **Administrator role** in management account and **Execution role** in target accounts
- Or use **Service-managed** with AWS Organizations (auto-creates roles)
- Can auto-deploy to new accounts added to an OU

### Intrinsic Functions = Builder's Toolkit

```yaml
# !Ref = "What's the address of that building?"
SecurityGroupId: !Ref MySecurityGroup

# !GetAtt = "What's a specific detail about that building?"
Endpoint: !GetAtt MyRDS.Endpoint.Address

# !Sub = "Fill in the blanks in this sentence"
Name: !Sub "server-${Environment}-${AWS::Region}"

# !Join = "Glue these strings together"
Path: !Join ["/", ["", "api", "v1", "users"]]

# !Select = "Pick the Nth item from a list"
Subnet: !Select [0, !Ref SubnetList]

# !If = "Use this value IF condition is true, otherwise use that"
InstanceType: !If [IsProduction, "m5.xlarge", "t3.micro"]

# Fn::ImportValue = "Get the completion certificate from another stack"
VpcId: !ImportValue "shared-vpc-id"

# !FindInMap = "Look up the regional codebook"
AMI: !FindInMap [RegionMap, !Ref "AWS::Region", AMI]

# Pseudo Parameters (built-in variables):
# AWS::Region, AWS::AccountId, AWS::StackName, AWS::StackId, AWS::NoValue
```

---

## Creation, Update, and Deletion Lifecycle

### CreationPolicy + cfn-signal = Inspector Sign-Off

When CloudFormation creates an EC2 instance, it marks it "CREATE_COMPLETE" as soon as the instance launches. But is the application actually RUNNING? CreationPolicy makes CloudFormation WAIT for a signal before declaring success.

```
CloudFormation                    EC2 Instance
     │                                │
     │──── Launch Instance ──────────→│
     │                                │── Installing software...
     │     (WAITING for signal)       │── Configuring application...
     │                                │── Running health check...
     │←── cfn-signal --exit-code 0 ───│  "I'm ready!"
     │                                │
     │── CREATE_COMPLETE ✓            │
```

```yaml
Resources:
  MyInstance:
    Type: AWS::EC2::Instance
    CreationPolicy:
      ResourceSignal:
        Count: 1           # How many signals to wait for
        Timeout: PT15M     # Wait max 15 minutes (ISO 8601)
    Properties:
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          yum install -y aws-cfn-bootstrap
          # ... install your app ...
          /opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} \
            --resource MyInstance --region ${AWS::Region}
```

### Helper Scripts

```
┌────────────────────────────────────────────────────────────┐
│                  CFN HELPER SCRIPTS                         │
│                                                             │
│  cfn-init     = Construction crew following a checklist     │
│                 (install packages, create files, start      │
│                  services — defined in Metadata)            │
│                                                             │
│  cfn-signal   = Inspector's sign-off                        │
│                 (tell CloudFormation "I'm done")            │
│                                                             │
│  cfn-hup      = Building maintenance daemon                 │
│                 (detect metadata changes and re-run          │
│                  cfn-init — UPDATES without replacing)      │
│                                                             │
│  cfn-get-metadata = Read the construction checklist          │
│                     (fetch Metadata from CloudFormation)     │
└────────────────────────────────────────────────────────────┘
```

**cfn-init** uses the `AWS::CloudFormation::Init` metadata section:

```yaml
Metadata:
  AWS::CloudFormation::Init:
    config:
      packages:
        yum:
          httpd: []
      files:
        /var/www/html/index.html:
          content: "Hello World"
      services:
        sysvinit:
          httpd:
            enabled: true
            ensureRunning: true
```

**cfn-hup** = daemon that polls for metadata changes. When template metadata is updated, cfn-hup detects it and re-runs cfn-init. Like a maintenance worker who checks for blueprint updates every 15 minutes.

### UpdatePolicy = Renovation Strategy

Controls how Auto Scaling Groups handle updates:

```yaml
UpdatePolicy:
  AutoScalingRollingUpdate:
    MinInstancesInService: 2     # Keep at least 2 running
    MaxBatchSize: 1              # Replace 1 at a time
    PauseTime: PT10M             # Wait 10 min between batches
    WaitOnResourceSignals: true  # Wait for cfn-signal
    SuspendProcesses:
      - HealthCheck
      - ReplaceUnhealthy
```

**AutoScalingReplacingUpdate:** Replace the entire ASG (create new one, delete old). Used when you can't do rolling updates (e.g., changing VPC).

### DeletionPolicy = What Happens When You Demolish

```yaml
Resources:
  MyDatabase:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Snapshot     # Take a photo before demolishing
    # Options:
    # Delete   = Demolish completely (default for most resources)
    # Retain   = Leave the building standing, just remove from blueprint
    # Snapshot = Take a backup photo, then demolish (RDS, EBS, Redshift, Neptune, DocumentDB)
```

**Critical exam fact:** Default DeletionPolicy is `Delete` for most resources, but `Retain` for `AWS::RDS::DBCluster`.

---

## Change Sets = Council Proposal

Before modifying infrastructure, preview exactly what will change:

```
Current Stack                    Change Set Preview
┌────────────┐                  ┌──────────────────────────┐
│ EC2: t3.micro│  ──Propose──→  │ EC2: t3.large  (Modify)  │
│ RDS: db.t3   │  change to    │ RDS: db.t3     (No change)│
│ S3: my-bucket│  bigger EC2   │ S3: my-bucket  (No change)│
└────────────┘                  │ New ELB        (Add)      │
                                └──────────────────────────┘
                                     │
                                     ▼
                              Review → Execute or Delete
```

- **No risk preview** — see adds, modifies, removes before executing
- Some modifications cause **replacement** (e.g., changing EC2 subnet = new instance)
- Others cause **no interruption** (e.g., changing a tag)
- Some cause **interruption** (e.g., changing instance type = stop/start)

### Drift Detection = Surveyor Audit

Someone manually changed a Security Group via the console. CloudFormation doesn't know. Drift detection finds these discrepancies:

```
CloudFormation expects:          Actual state:
┌──────────────────┐            ┌──────────────────┐
│ SG: Port 80, 443 │            │ SG: Port 80, 443,│
│                   │  DRIFT!   │     8080          │
└──────────────────┘            └──────────────────┘
                                Someone added port 8080 manually!
```

Drift status: `IN_SYNC`, `DRIFTED`, `NOT_CHECKED`.

---

## Advanced Patterns

### Nested Stacks = Sub-Projects

```
┌──── Root Stack ─────────────────────────────────────┐
│                                                      │
│  ┌─── Nested: VPC Stack ────┐                       │
│  │  VPC, Subnets, IGW       │                       │
│  └──────────┬───────────────┘                       │
│             │ outputs VPC ID                         │
│  ┌──────────▼───────────────┐                       │
│  │ Nested: Application Stack│                       │
│  │  EC2, ALB, ASG           │                       │
│  └──────────┬───────────────┘                       │
│             │ outputs ALB DNS                        │
│  ┌──────────▼───────────────┐                       │
│  │ Nested: Database Stack   │                       │
│  │  RDS, Subnet Group       │                       │
│  └──────────────────────────┘                       │
└──────────────────────────────────────────────────────┘
```

- Nested stacks are COMPONENTS — reusable building blocks
- Root stack orchestrates everything
- Changes to nested stacks propagate through the root stack
- Use for: reusable infrastructure patterns (VPC, ECS cluster, monitoring)

### Cross-Stack References = Completion Certificates

Different from nested stacks — these are INDEPENDENT stacks sharing values:

```yaml
# Stack A: Network stack (EXPORTS a value)
Outputs:
  VpcId:
    Value: !Ref MyVPC
    Export:
      Name: "shared-vpc-id"    # Published completion certificate

# Stack B: Application stack (IMPORTS the value)
Resources:
  MyInstance:
    Type: AWS::EC2::Instance
    Properties:
      SubnetId: !ImportValue "shared-vpc-id"   # Uses the certificate
```

**Key rule:** You cannot delete Stack A if Stack B references its exports. The completion certificate is still in use.

### Custom Resources = Freelance Contractors

When CloudFormation doesn't support something natively, call a Lambda function:

```yaml
Resources:
  EmptyS3Bucket:
    Type: Custom::S3BucketCleanup
    Properties:
      ServiceToken: !GetAtt CleanupFunction.Arn  # Lambda ARN
      BucketName: !Ref MyBucket
```

CloudFormation sends Create/Update/Delete events to your Lambda. Your Lambda does the work and sends a response back. Use cases:
- Empty an S3 bucket before deletion
- Look up AMI IDs dynamically
- Register with third-party services
- Any action CloudFormation doesn't natively support

### Stack Roles = VIP Badge

Separate "who can deploy" from "what the template can create":

```
Developer (IAM user)
  - Has: cloudformation:CreateStack, iam:PassRole
  - Does NOT have: ec2:*, rds:*, etc.
  │
  └─→ Creates stack with --role-arn arn:aws:iam::123:role/CfnDeployRole
       │
       └─→ CfnDeployRole
            Has: ec2:*, rds:*, s3:*  (full infra permissions)
            Trust: cloudformation.amazonaws.com

Result: Developer can deploy infrastructure they can't directly access.
```

### Stack Policies = Construction Locks

Prevent updates to critical resources:

```json
{
  "Statement": [{
    "Effect": "Deny",
    "Action": "Update:Replace",
    "Principal": "*",
    "Resource": "LogicalResourceId/ProductionDatabase"
  }, {
    "Effect": "Allow",
    "Action": "Update:*",
    "Principal": "*",
    "Resource": "*"
  }]
}
```

Prevents accidental replacement of the production database during stack updates.

### Resource Import

Bring existing resources under CloudFormation management:

1. Add the resource to your template (with `DeletionPolicy: Retain`)
2. Use "Import resources" action
3. Provide the resource identifier (e.g., instance ID)
4. CloudFormation adopts the resource into the stack

---

## Rollback Behavior

```
Stack Creation:
  Success → CREATE_COMPLETE
  Failure → ROLLBACK (delete everything created) → ROLLBACK_COMPLETE
           Can disable: --disable-rollback (for debugging, resources stay)

Stack Update:
  Success → UPDATE_COMPLETE
  Failure → ROLLBACK to previous state → UPDATE_ROLLBACK_COMPLETE

Stack Delete:
  Failure → DELETE_FAILED (manual intervention needed)
           Usually: resource still has dependencies or DeletionPolicy=Retain
```

**Termination Protection:** Prevent accidental stack deletion. Must be explicitly disabled before delete.

---

## Architecture: CloudFormation Deployment Flow

```
Developer                     CloudFormation                AWS Services
    │                              │                            │
    │── Upload template ──────────→│                            │
    │   (S3 or direct)             │                            │
    │                              │── Validate template        │
    │                              │── Create Change Set        │
    │                              │                            │
    │←── Change Set preview ───────│                            │
    │                              │                            │
    │── Execute Change Set ───────→│                            │
    │                              │── Create/Update resources ─→│
    │                              │   (in dependency order)    │
    │                              │                            │
    │                              │←── Resource status ────────│
    │                              │                            │
    │                              │── Wait for signals?        │
    │                              │←── cfn-signal ─────────────│
    │                              │                            │
    │←── Stack events ─────────────│                            │
    │    CREATE_COMPLETE           │                            │
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- When to use nested stacks vs cross-stack references
- StackSets for multi-account/multi-region deployment
- DeletionPolicy: Snapshot for databases
- Change Sets for safe production updates
- Custom Resources for unsupported operations

### DVA-C02 (Developer)
- Template sections and which is required (Resources only)
- Intrinsic functions: !Ref, !GetAtt, !Sub, !Join, !Select, !If, Fn::ImportValue
- cfn-init metadata structure (packages, files, services)
- cfn-signal for CreationPolicy
- Pseudo parameters (AWS::Region, AWS::AccountId, etc.)
- Transforms: AWS::Serverless, AWS::Include

### SOA-C02 (SysOps)
- Drift detection — finding manual changes
- Stack policies — protecting critical resources
- Rollback behavior and troubleshooting failed stacks
- cfn-hup for in-place updates
- Termination protection
- Resource import (adopt existing resources)
- UpdatePolicy for ASG rolling/replacing updates
- Stack roles for permission separation

---

## Key Numbers

| Item | Value |
|------|-------|
| Template max size (direct) | **51,200 bytes** (51 KB) |
| Template max size (S3) | **1 MB** |
| Max resources per stack | **500** |
| Max stacks per account | **2000** (soft limit) |
| Max parameters per template | **200** |
| Max outputs per template | **200** |
| Max mappings per template | **200** |
| Max conditions per template | **200** |
| Stack name max length | **128 characters** |
| StackSet max concurrent accounts | **Configurable** |
| cfn-signal timeout | **Max PT12H** (12 hours) |
| Change Set expiry | **None** (persists until executed or deleted) |
| Nested stack depth | **Unlimited** (but practical limit ~5 levels) |
| Exports per account per region | **200** |
| Export name max length | **256 characters** |

---

## Cheat Sheet

- **Only REQUIRED section = Resources** — everything else is optional
- **Parameters** = runtime inputs. Use `AllowedValues`, `Default`, `NoEcho` (for passwords)
- **!Ref** on a resource returns its ID; on a parameter returns its value
- **!GetAtt** gets a specific attribute (e.g., `!GetAtt MyRDS.Endpoint.Address`)
- **DeletionPolicy: Retain** = keep resource when stack is deleted
- **DeletionPolicy: Snapshot** = backup then delete (RDS, EBS, Redshift)
- **Change Sets** = preview before apply (ALWAYS use in production)
- **Drift Detection** = find resources modified outside CloudFormation
- **Nested Stacks** = reusable components (reference via `AWS::CloudFormation::Stack`)
- **Cross-Stack** = independent stacks sharing values via Export/ImportValue
- **Cannot delete exporting stack** if another stack imports its value
- **cfn-init** = declarative setup (packages, files, services) in Metadata
- **cfn-signal** = tell CloudFormation "resource is ready"
- **cfn-hup** = daemon that detects metadata changes and re-runs cfn-init
- **Stack Roles** = CloudFormation assumes a role with more permissions than the deployer
- **Rollback** = automatic on failure (default). Disable with `--disable-rollback` for debugging
- **Termination Protection** = prevent accidental stack deletion
- **Resource Import** = adopt existing resources into a stack
- **Custom Resources** = Lambda-backed for unsupported operations
- **StackSets** = deploy same template across multiple accounts/regions
- **Template > 51KB** = must upload to S3 first
- **Transforms** = macros. `AWS::Serverless-2016-10-31` for SAM, `AWS::Include` for snippets
