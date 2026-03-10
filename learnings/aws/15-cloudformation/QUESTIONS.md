# 15 — CloudFormation: Exam-Style Questions

---

## Q1: Required Template Section

A developer is writing their first CloudFormation template. Which section is the ONLY required section in a CloudFormation template?

- **A)** Parameters
- **B)** Resources
- **C)** Outputs
- **D)** AWSTemplateFormatVersion

**Correct Answer: B**

**Why:** Resources is the only required section. It's the buildings in the blueprint — without buildings, there's no city to build. A valid template can be as minimal as just a Resources section with one resource. Everything else (Parameters, Mappings, Conditions, Outputs) is optional.

- **A is wrong:** Parameters are optional inputs — the blueprint works fine with hardcoded values.
- **C is wrong:** Outputs are completion certificates — nice to have but not required.
- **D is wrong:** AWSTemplateFormatVersion is optional. If omitted, CloudFormation uses the latest supported version.

---

## Q2: DeletionPolicy

A company stores critical financial data in an RDS database managed by CloudFormation. They need to ensure the database data is preserved even if the stack is accidentally deleted. What DeletionPolicy should they use?

- **A)** DeletionPolicy: Retain
- **B)** DeletionPolicy: Snapshot
- **C)** DeletionPolicy: Delete
- **D)** Both A and B would preserve the data, but B is more cost-effective

**Correct Answer: D**

**Why:** Both Retain and Snapshot preserve data, but they work differently. **Retain** leaves the entire RDS instance running (ongoing compute + storage costs). **Snapshot** takes a final backup and then deletes the instance (you only pay for snapshot storage, much cheaper). For financial data, Snapshot gives you the backup without the running cost of a live database you're not using. It's like taking a photo of the building's contents before demolishing it vs leaving the entire building standing but empty.

- **A is wrong:** While Retain works, it leaves the full RDS instance running, incurring unnecessary costs. The question asks for the best approach.
- **B is wrong:** Snapshot alone is correct, but the question is testing whether you understand the difference. D is the complete answer.
- **C is wrong:** Delete would destroy the database and all data permanently. Never use this for critical data.

---

## Q3: Cross-Stack References

A team has a VPC stack that exports its VPC ID. An application stack imports this value using Fn::ImportValue. The network team tries to delete the VPC stack but gets an error. Why?

- **A)** The VPC stack has termination protection enabled
- **B)** Another stack is importing the VPC stack's exported value, so it cannot be deleted
- **C)** The VPC contains running EC2 instances from the application stack
- **D)** The VPC stack has a DeletionPolicy: Retain on the VPC resource

**Correct Answer: B**

**Why:** CloudFormation prevents you from deleting a stack that has exports being consumed by other stacks. The completion certificate is still in use — you can't shred it while someone else relies on it. To delete the VPC stack, you must first update the application stack to remove the Fn::ImportValue reference.

- **A is wrong:** Termination protection would also prevent deletion, but the question describes a cross-stack reference scenario. The error message would specifically mention the export dependency.
- **C is wrong:** CloudFormation stacks are independent — the application stack's EC2 instances being in the VPC doesn't prevent the VPC stack from being deleted at the CloudFormation level (though the actual AWS deletion might fail due to dependencies).
- **D is wrong:** DeletionPolicy: Retain would keep the VPC resource but would NOT prevent the stack itself from being deleted. It controls the resource, not the stack.

---

## Q4: cfn-signal and CreationPolicy

A SysOps admin launches a CloudFormation stack with an EC2 instance that installs a complex application via UserData. The instance launches successfully, but the application fails to install. CloudFormation still marks the stack as CREATE_COMPLETE. How should the admin ensure CloudFormation waits for successful installation?

- **A)** Add a health check in the Auto Scaling Group
- **B)** Add a CreationPolicy with ResourceSignal and use cfn-signal in the UserData script
- **C)** Add a WaitCondition resource after the EC2 instance
- **D)** Enable detailed monitoring on the EC2 instance

**Correct Answer: B**

**Why:** CreationPolicy tells CloudFormation: "Don't mark this resource as complete until it signals back." cfn-signal is the tool the instance uses to say "I'm ready" (exit code 0) or "I failed" (exit code 1). It's the inspector sign-off system — the construction isn't approved until the inspector gives the thumbs up. Without it, CloudFormation only knows the instance launched, not whether the application inside is working.

- **A is wrong:** Auto Scaling Group health checks are for ongoing monitoring, not initial deployment verification. Also, the question doesn't mention an ASG — it's a standalone EC2 instance.
- **C is wrong:** WaitCondition is an older mechanism that works similarly but is less integrated. CreationPolicy + cfn-signal is the modern, recommended approach. Both work, but B is the best answer for new implementations.
- **D is wrong:** Detailed monitoring sends metrics to CloudWatch more frequently. It has nothing to do with CloudFormation deployment signaling.

---

## Q5: Change Sets

A DevOps engineer needs to modify a production CloudFormation stack by changing an EC2 instance type from t3.micro to t3.large. Before applying, they want to understand the impact. What should they do?

- **A)** Update the stack directly — CloudFormation will show events in real time
- **B)** Create a Change Set, review the proposed changes, then execute it
- **C)** Delete the stack and recreate it with the new instance type
- **D)** Use drift detection to check if the change is safe

**Correct Answer: B**

**Why:** Change Sets are the council proposal system — you submit the proposed changes, CloudFormation analyzes them and tells you exactly what will happen (add, modify, remove, replace). You review the preview, and only then decide to execute or discard. For this case, it would show: EC2 instance will be MODIFIED with some interruption (instance type change requires stop/start).

- **A is wrong:** Updating directly in production is reckless. You won't know the impact until resources are already changing. What if the instance type change causes a replacement instead of an in-place modification?
- **C is wrong:** Deleting and recreating causes downtime and data loss. This is never the right approach for a simple instance type change in production.
- **D is wrong:** Drift detection finds changes made OUTSIDE CloudFormation. It doesn't preview future changes. It's an audit of the past, not a preview of the future.

---

## Q6: Drift Detection

After a CloudFormation stack has been running for months, a developer suspects someone manually modified a Security Group through the AWS Console. How can they verify this?

- **A)** Check CloudTrail logs for Security Group modifications
- **B)** Run drift detection on the CloudFormation stack
- **C)** Delete and recreate the stack to reset all resources to template state
- **D)** Compare the running Security Group rules with the template manually

**Correct Answer: B**

**Why:** Drift detection is the surveyor audit — it compares what CloudFormation THINKS the resource looks like (from the template) with what the resource ACTUALLY looks like (current state). It will show exactly which properties drifted and what the expected vs actual values are. It's purpose-built for this exact scenario.

- **A is wrong:** CloudTrail would show WHO made changes and WHEN, but it doesn't compare current state to the CloudFormation template. You'd need to manually correlate the events. Drift detection does this automatically.
- **C is wrong:** Recreating the stack is the nuclear option. Drift detection is non-destructive — it only reads and compares, it doesn't change anything.
- **D is wrong:** Manual comparison works but doesn't scale. With hundreds of resources, drift detection automates the comparison across the entire stack.

---

## Q7: Nested Stacks vs Cross-Stack References

A company has shared infrastructure (VPC, subnets) used by 10 different application stacks. The network team manages the VPC independently. Which approach should they use?

- **A)** Nested stacks — include the VPC template as a nested stack in each application template
- **B)** Cross-stack references — the VPC stack exports values, application stacks import them
- **C)** Copy the VPC resource definition into each of the 10 application templates
- **D)** Use a single monolithic template containing the VPC and all 10 applications

**Correct Answer: B**

**Why:** Cross-stack references are for INDEPENDENT stacks that need to share values. The VPC has its own lifecycle (managed by the network team) and the applications have their own lifecycles (managed by app teams). The VPC stack exports its VPC ID and subnet IDs as completion certificates, and each application stack imports what it needs. Like sharing building addresses — the buildings are independently constructed but need to know each other's locations.

- **A is wrong:** Nested stacks are COMPONENTS within a parent stack — they share a lifecycle. If Application Stack #3 updates, you wouldn't want to touch the VPC. Nested stacks would create 10 separate VPCs (one per parent stack), not share one.
- **C is wrong:** This would create 10 separate VPCs — duplicated infrastructure, not shared.
- **D is wrong:** A monolithic template violates separation of concerns. Updating one application would risk the VPC and all other applications. Plus, you'd likely hit the 500-resource limit.

---

## Q8: Stack Roles

A junior developer needs to deploy a CloudFormation template that creates EC2 instances and RDS databases, but the developer's IAM policy only allows CloudFormation actions. How can this work without giving the developer direct EC2/RDS permissions?

- **A)** The developer cannot deploy this template without EC2/RDS permissions
- **B)** Use a CloudFormation Stack Role — the developer passes a role ARN that has EC2/RDS permissions
- **C)** Use a Custom Resource to create the EC2 and RDS resources via Lambda
- **D)** Have an admin deploy the template on the developer's behalf

**Correct Answer: B**

**Why:** Stack Roles separate "who can deploy" from "what gets built." The developer needs `cloudformation:CreateStack` and `iam:PassRole` permissions. They pass a role ARN (`--role-arn`) to CloudFormation. CloudFormation assumes that role (which has EC2/RDS permissions) to create the actual resources. It's like a VIP badge — the developer hands the badge to the construction crew, and the crew uses it to access restricted areas the developer personally can't enter.

- **A is wrong:** Stack Roles exist exactly for this purpose. It's a core CloudFormation feature for permission separation.
- **C is wrong:** This is overengineering. Custom Resources add complexity and Lambda code to maintain. Stack Roles solve this natively.
- **D is wrong:** This doesn't scale and defeats the purpose of self-service deployment.

---

## Q9: StackSets

A company with 50 AWS accounts needs to deploy a security baseline (GuardDuty, Config, CloudTrail) to every account and every active region. They also want this baseline automatically deployed to any NEW accounts. What should they use?

- **A)** A CloudFormation template deployed manually in each account
- **B)** AWS CloudFormation StackSets with service-managed permissions and auto-deployment to OUs
- **C)** AWS CodePipeline deploying to each account sequentially
- **D)** A Lambda function that assumes roles in each account and deploys the template

**Correct Answer: B**

**Why:** StackSets are the franchise rollout system — same blueprint deployed across multiple accounts and regions. With service-managed permissions (through AWS Organizations), StackSets automatically creates the needed roles. The "auto-deployment" feature means when a new account joins an OU, the stack is automatically deployed. One blueprint → 50 accounts × N regions, automatically maintained.

- **A is wrong:** Manual deployment across 50 accounts is unscalable and error-prone. And it doesn't handle new accounts automatically.
- **C is wrong:** CodePipeline is for application CI/CD, not multi-account infrastructure baseline deployment. You'd need complex cross-account pipeline configurations.
- **D is wrong:** This is essentially building a poor version of StackSets from scratch. Why reinvent the wheel?

---

## Q10: Rollback Behavior

A CloudFormation stack update fails midway — 3 of 5 resources were updated successfully, but the 4th resource fails. What happens by default?

- **A)** The stack remains in a partially updated state with 3 resources updated
- **B)** CloudFormation automatically rolls back ALL resources to their previous state
- **C)** CloudFormation completes the remaining 2 resources and marks the 4th as failed
- **D)** The stack is automatically deleted

**Correct Answer: B**

**Why:** CloudFormation's default behavior on update failure is automatic rollback — it reverts ALL resources to their previous state, including the 3 that were successfully updated. The city planners don't leave a half-renovated building. If the renovation plan fails, they restore everything to how it was before. The stack ends in `UPDATE_ROLLBACK_COMPLETE` state.

- **A is wrong:** CloudFormation NEVER leaves a stack in a partially updated state by default. That would be dangerous — some resources at version 1, others at version 2.
- **C is wrong:** CloudFormation doesn't skip failed resources and continue. A failure halts the update and triggers rollback.
- **D is wrong:** Stack deletion only happens on CREATION failure (by default). Update failure triggers rollback, not deletion. Your previous working state is preserved.

---

## Q11: Custom Resources

A developer needs to empty an S3 bucket before CloudFormation can delete it (CloudFormation can't delete non-empty buckets). What should they add to the template?

- **A)** A DeletionPolicy: ForceDelete on the S3 bucket
- **B)** A Custom Resource backed by a Lambda function that empties the bucket on delete events
- **C)** A CloudFormation WaitCondition that pauses for manual bucket cleanup
- **D)** An EventBridge rule that triggers a Lambda when the stack enters DELETE_IN_PROGRESS

**Correct Answer: B**

**Why:** Custom Resources are freelance contractors — they handle jobs CloudFormation can't do natively. The Lambda receives Create, Update, and Delete events from CloudFormation. On the Delete event, the Lambda empties the bucket (deletes all objects), then signals success. CloudFormation then proceeds to delete the now-empty bucket. This is one of the most common Custom Resource use cases.

- **A is wrong:** There is no `ForceDelete` DeletionPolicy. The valid options are Delete, Retain, and Snapshot.
- **C is wrong:** WaitCondition pauses the stack, but someone still needs to manually empty the bucket. This is fragile and doesn't automate the process.
- **D is wrong:** An EventBridge rule would trigger OUTSIDE CloudFormation's control. CloudFormation wouldn't know to wait for the Lambda to finish before trying to delete the bucket. The timing would be a race condition.

---

## Q12: cfn-hup

After deploying a CloudFormation stack with EC2 instances, the operations team wants to update the application configuration on running instances WITHOUT replacing them. The new configuration is in the AWS::CloudFormation::Init metadata. What enables this?

- **A)** CloudFormation automatically detects metadata changes and updates instances
- **B)** The cfn-hup daemon must be running on the instances to detect metadata changes and re-run cfn-init
- **C)** The instances must be terminated and new ones launched by the Auto Scaling Group
- **D)** A CodeDeploy deployment group should push the new configuration

**Correct Answer: B**

**Why:** cfn-hup is the building maintenance daemon — it runs on the instance and periodically checks CloudFormation for metadata changes. When it detects a change, it re-runs cfn-init to apply the new configuration in place. Without cfn-hup, updating metadata in the template does nothing to running instances — the blueprint changes but the existing buildings don't know about it.

- **A is wrong:** CloudFormation does NOT automatically push metadata changes to running instances. It only manages resources at the AWS API level. What happens inside the instance is the instance's responsibility (via cfn-hup).
- **C is wrong:** Terminating and replacing instances works but causes downtime and isn't what was asked. The question specifically says "WITHOUT replacing them."
- **D is wrong:** CodeDeploy is a separate service for application deployments. While it could update configuration, it's not integrated with CloudFormation metadata. cfn-hup is the built-in mechanism for this exact use case.
