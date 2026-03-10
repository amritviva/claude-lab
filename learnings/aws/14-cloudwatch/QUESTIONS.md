# 14 — CloudWatch: Exam-Style Questions

---

## Q1: Memory Monitoring

A SysOps administrator notices that EC2 instances in production are running out of memory, but CloudWatch shows no memory-related metrics. What should the administrator do?

- **A)** Enable detailed monitoring on the EC2 instances
- **B)** Install and configure the CloudWatch Agent on the instances
- **C)** Create a custom metric using the PutMetricData API from the application
- **D)** Enable Enhanced Monitoring on the instances

**Correct Answer: B**

**Why:** Memory utilization is NOT a default EC2 metric. The hypervisor (which provides default metrics) can see CPU, network, and disk I/O — but it can't see INSIDE the instance to check memory. The CloudWatch Agent is a field agent deployed inside the building to report what the external cameras can't see. It reports memory, disk space percentage, and application-level metrics.

- **A is wrong:** Detailed monitoring changes the interval from 5 minutes to 1 minute — it doesn't add NEW metrics. It's like checking the same cameras more frequently, not installing new cameras.
- **C is wrong:** While PutMetricData could work if you wrote custom code, the CloudWatch Agent is the standard, supported solution. You wouldn't hire a spy when the ministry has trained field agents ready to deploy.
- **D is wrong:** Enhanced Monitoring is for RDS, not EC2. Different service, different concept.

---

## Q2: Log Retention Cost

A company's CloudWatch Logs costs have been increasing steadily over the past year, even though their application traffic hasn't changed significantly. What is the MOST LIKELY cause?

- **A)** The log group retention is set to Never Expire, causing logs to accumulate indefinitely
- **B)** Detailed monitoring was accidentally enabled on all EC2 instances
- **C)** The CloudWatch Agent is sending duplicate log entries
- **D)** Cross-account log delivery is duplicating logs

**Correct Answer: A**

**Why:** CloudWatch Logs default retention is "Never Expire." The police archives keep growing forever unless you set a retention policy. If you never shred old case files, eventually the archive fills the entire building and the rent keeps going up. This is the #1 cause of surprise CloudWatch costs.

- **B is wrong:** Detailed monitoring costs more for metrics, but doesn't affect log storage costs. Different line items on the bill.
- **C is wrong:** While possible, duplicate entries would be an obvious bug, not a gradual increase over a year. The gradual growth pattern matches accumulation, not duplication.
- **D is wrong:** Cross-account delivery doesn't duplicate — it copies to a destination. The source logs would still accumulate regardless.

---

## Q3: Alarm Configuration

A developer creates a CloudWatch alarm with Period=60 seconds and Evaluation Periods=5. The alarm should trigger when CPU exceeds 80%. After deploying, the alarm shows INSUFFICIENT_DATA. What explains this?

- **A)** The EC2 instance has not been running long enough to generate 5 data points
- **B)** The developer forgot to enable detailed monitoring
- **C)** The alarm is misconfigured and should use a longer period
- **D)** CloudWatch alarms always start in INSUFFICIENT_DATA state and will transition after enough data is collected

**Correct Answer: D**

**Why:** Every CloudWatch alarm starts in INSUFFICIENT_DATA state — this is normal. It's like a new alert system that just got installed: it hasn't collected enough intelligence yet to decide if things are OK or not. Once enough data points are collected (5 periods of 60 seconds = 5 minutes), it will transition to either OK or ALARM.

- **A is wrong:** While technically the instance needs to be running, the question asks what EXPLAINS the state. The real explanation is that INSUFFICIENT_DATA is the default starting state for all alarms, not that the instance is too new.
- **B is wrong:** Basic monitoring (5-minute intervals) would still eventually generate data. The alarm would just take longer to evaluate with a 1-minute period, potentially missing some data points, but INSUFFICIENT_DATA at creation is the default state regardless.
- **C is wrong:** The configuration is valid. A 60-second period with 5 evaluation periods is a perfectly reasonable setup.

---

## Q4: Custom Metrics from Lambda

A developer needs to publish custom business metrics (orders processed per minute) from a Lambda function. The team wants to minimize API calls and operational overhead. What is the BEST approach?

- **A)** Call the PutMetricData API from within the Lambda function code
- **B)** Use CloudWatch Embedded Metric Format (EMF) by writing structured JSON to stdout
- **C)** Write metrics to a DynamoDB table and use a separate Lambda to push them to CloudWatch
- **D)** Install the CloudWatch Agent in the Lambda execution environment

**Correct Answer: B**

**Why:** Embedded Metric Format (EMF) lets you embed metric data directly in your log output as structured JSON. CloudWatch automatically extracts the metrics — no separate API call needed. It's like writing your surveillance report in a special format that the archives department automatically converts into statistics. Zero extra API calls, zero extra latency, zero extra cost for the PutMetricData call.

- **A is wrong:** While PutMetricData works, each API call adds latency to your Lambda execution and counts against API throttling limits. For a high-volume function, this is unnecessary overhead when EMF exists.
- **C is wrong:** This is a Rube Goldberg machine — overly complex for a simple requirement. Two Lambda functions and a DynamoDB table when a single log line would do.
- **D is wrong:** You can't install the CloudWatch Agent in Lambda. Lambda manages its own execution environment. The agent is for EC2 and on-premises servers.

---

## Q5: Cross-Account Monitoring

A company with 15 AWS accounts in an Organization wants to view CloudWatch metrics from all accounts on a single dashboard. What is the CORRECT approach?

- **A)** Create CloudWatch alarms in each account that forward data to a central SNS topic
- **B)** Enable cross-account functionality in CloudWatch settings and create a cross-account dashboard in the monitoring account
- **C)** Use CloudWatch Logs subscription filters to forward all metrics to a central account
- **D)** Deploy CloudWatch Agent in all accounts configured to push metrics to the central account

**Correct Answer: B**

**Why:** CloudWatch natively supports cross-account dashboards. You enable cross-account functionality in the CloudWatch settings (specify the monitoring account and source accounts), and then the monitoring account can pull metrics from any source account into its dashboards. It's like the war room in Ministry HQ getting live feeds from regional surveillance centers — built-in capability, no custom wiring needed.

- **A is wrong:** Alarms are for alerts, not dashboards. Forwarding alarm state to SNS doesn't give you metric visualization on a dashboard.
- **C is wrong:** Subscription filters are for LOGS, not metrics. Logs and metrics are different data types in CloudWatch.
- **D is wrong:** CloudWatch Agent publishes metrics to the account it's running in. You'd need custom configuration and cross-account IAM roles to push to a different account — possible but not the standard approach when native cross-account dashboards exist.

---

## Q6: Metric Filters

A team wants to get alerted when their application logs contain more than 10 "OutOfMemoryError" messages within 5 minutes. What is the correct sequence of CloudWatch components to set this up?

- **A)** Log Group → Subscription Filter → SNS Topic → Email
- **B)** Log Group → Metric Filter → CloudWatch Metric → CloudWatch Alarm → SNS Topic
- **C)** Log Group → Logs Insights Query → CloudWatch Alarm → SNS Topic
- **D)** Log Group → EventBridge Rule → Lambda → SNS Topic

**Correct Answer: B**

**Why:** This is the classic metric filter pipeline. You create a metric filter on the log group that matches "OutOfMemoryError" and increments a custom metric. Then you create an alarm on that metric (threshold: > 10 in 5 minutes). When the alarm fires, it triggers an SNS notification. It's like telling the archive clerk: "Every time you see the word 'OutOfMemoryError,' add a tally mark to this board. When the board hits 10 tallies in 5 minutes, pull the alarm."

- **A is wrong:** Subscription filters forward raw log data to destinations (Lambda, Kinesis, OpenSearch). They don't count occurrences or trigger alarms based on thresholds.
- **C is wrong:** Logs Insights is an interactive query tool — you run queries manually or on a schedule. It doesn't continuously monitor and can't directly trigger alarms on log patterns. It's an investigator, not a watchdog.
- **D is wrong:** EventBridge doesn't directly monitor CloudWatch Logs content. You'd need a metric filter first to create the metric, then potentially use EventBridge with the alarm state change — but that's adding complexity to option B, not replacing it.

---

## Q7: High-Resolution Metrics

A trading application requires sub-minute monitoring with 10-second alarm evaluation. Which statements are TRUE? (Select TWO)

- **A)** You must use custom metrics with high-resolution (1-second storage resolution) and detailed monitoring
- **B)** High-resolution custom metrics are stored at 1-second resolution for 3 hours, then aggregated
- **C)** You can create alarms with 10-second evaluation periods only on high-resolution metrics
- **D)** Detailed monitoring on EC2 provides 10-second resolution metrics
- **E)** High-resolution metrics cost the same as standard-resolution custom metrics

**Correct Answer: B, C**

**Why B:** High-resolution custom metrics (published with `StorageResolution=1`) are stored at 1-second granularity for 3 hours. After that, they're aggregated to 1-minute (kept 15 days), then 5-minute (63 days), then 1-hour (455 days). The intelligence agency keeps the high-detail surveillance footage for 3 hours, then creates summaries for long-term storage.

**Why C:** 10-second alarm evaluation periods are ONLY available for high-resolution metrics. Standard metrics can have minimum 60-second alarm periods. It's like having a quick-response team that can only be assigned to high-priority surveillance feeds.

- **A is wrong:** Detailed monitoring (1-minute EC2 metrics) is separate from high-resolution custom metrics (1-second). You don't need detailed monitoring to publish high-resolution custom metrics.
- **D is wrong:** Detailed monitoring provides 1-MINUTE resolution, not 10-second. It's more frequent than basic (5-minute) but nowhere near high-resolution.
- **E is wrong:** High-resolution metrics cost more than standard resolution. Higher precision = higher cost.

---

## Q8: Log Export to S3

A company needs to export CloudWatch Logs to S3 for long-term compliance storage. They require logs to arrive in S3 within 1 minute of being generated. What should they use?

- **A)** CloudWatch Logs S3 Export Task (CreateExportTask API)
- **B)** CloudWatch Logs Subscription Filter to Amazon Kinesis Data Firehose to S3
- **C)** CloudWatch Logs Subscription Filter directly to S3
- **D)** CloudWatch Agent configured to write directly to S3

**Correct Answer: B**

**Why:** Subscription Filter → Kinesis Data Firehose → S3 provides near-real-time delivery (Firehose buffers in 60-second intervals minimum). It's like having a courier service that picks up copies of police reports every minute and delivers them to the long-term archive warehouse.

- **A is wrong:** CreateExportTask is a BATCH operation — it exports historical logs, not real-time. It can take up to 12 hours to complete. It's like sending a moving truck to pick up old case files once a week, not a minute-by-minute courier.
- **C is wrong:** Subscription filters cannot deliver directly to S3. Valid destinations are: Lambda, Kinesis Data Streams, Kinesis Data Firehose, and OpenSearch.
- **D is wrong:** CloudWatch Agent sends logs TO CloudWatch, not FROM CloudWatch to S3. It's a one-way agent that reports to headquarters, not one that copies files to the archive.

---

## Q9: Composite Alarms

A SysOps admin receives too many false alarm notifications. Individual alarms for CPU, memory, and network often trigger independently during brief spikes, but the application only has real issues when multiple metrics spike simultaneously. What should they implement?

- **A)** Increase the evaluation period on all individual alarms to reduce sensitivity
- **B)** Create a composite alarm that triggers only when CPU AND memory AND network alarms are all in ALARM state
- **C)** Use anomaly detection alarms instead of static threshold alarms
- **D)** Increase the "Datapoints to Alarm" setting on each individual alarm

**Correct Answer: B**

**Why:** Composite alarms combine multiple alarms with AND/OR logic. This is exactly the "combined intelligence briefing" — the war room shouldn't go on full alert because one camera shows a spike. Only when MULTIPLE indicators confirm a problem should the alarm sound. This dramatically reduces false positives while catching real issues.

- **A is wrong:** Increasing evaluation periods makes ALL alarms slower to respond, including real incidents. You'd miss genuine problems just to avoid false alarms. It's like telling the surveillance team to check cameras less often — you'll miss actual crimes.
- **C is wrong:** Anomaly detection is good for metrics with varying baselines, but it doesn't solve the core problem of INDIVIDUAL metrics causing false alarms. You'd still get alerts for individual anomalies.
- **D is wrong:** Similar to A — "Datapoints to Alarm" (M of N) helps with individual alarm sensitivity, but doesn't address the correlation problem. Three alarms that each rarely fire can still collectively cause alert fatigue.

---

## Q10: Anomaly Detection

A company has a web application with predictable traffic patterns — high on weekdays from 9 AM to 5 PM, low on weekends. They want to be alerted about unusual traffic, but a static threshold alarm keeps triggering during normal peak hours. What should they use?

- **A)** Create two alarms with different thresholds: one for business hours and one for off-hours, using EventBridge to enable/disable them on schedule
- **B)** Use CloudWatch anomaly detection to create an alarm based on expected metric behavior
- **C)** Use metric math to normalize the request count by time of day before alarming
- **D)** Set the alarm to only evaluate during off-peak hours using a suppressor alarm

**Correct Answer: B**

**Why:** CloudWatch anomaly detection uses ML to learn the normal pattern of a metric, including time-of-day and day-of-week variations. It creates a dynamic band of expected values. When the metric goes outside this band, it's anomalous. It's like an AI surveillance system that learns "200 cars on the highway at 9 AM is normal, but 200 cars at 3 AM is suspicious." No manual threshold management needed.

- **A is wrong:** While technically workable, this is operationally complex — you'd need to maintain two alarms plus scheduling logic. And what about holidays, gradual traffic growth, or seasonal changes? Anomaly detection handles all of these automatically.
- **C is wrong:** Metric math can do arithmetic on metrics, but "normalizing by time of day" isn't a simple math expression. You'd need the historical baseline data that anomaly detection already builds for you.
- **D is wrong:** Alarm suppressor (part of composite alarms) can suppress notifications, but only evaluating during off-peak defeats the purpose — you want to detect anomalies DURING peak hours too (just not false positives from normal peaks).

---

## Q11: Subscription Filter Limits

A DevOps team has a critical log group that needs to stream to three destinations: OpenSearch for searching, Kinesis Data Firehose for S3 archival, and a Lambda function for real-time error alerting. What problem will they encounter and how should they solve it?

- **A)** No problem — CloudWatch supports unlimited subscription filters per log group
- **B)** CloudWatch allows only 2 subscription filters per log group — they should use a single Kinesis Data Stream as the filter destination, then fan out to all three destinations from there
- **C)** CloudWatch allows only 1 subscription filter per log group — they need to create separate log groups
- **D)** CloudWatch allows only 2 subscription filters per log group — they should remove one destination

**Correct Answer: B**

**Why:** CloudWatch Logs allows a maximum of 2 subscription filters per log group. With 3 destinations, they're over the limit. The solution: use one subscription filter to send to a Kinesis Data Stream, then have all three consumers (OpenSearch, Firehose→S3, Lambda) read from that stream. It's like having only 2 outgoing phone lines from the archive — send everything through one line to a switchboard, and the switchboard distributes to all recipients.

- **A is wrong:** There IS a limit — 2 subscription filters per log group. This is a commonly tested number.
- **C is wrong:** The limit is 2, not 1. And creating separate log groups would require application changes and duplicates data.
- **D is wrong:** Removing a destination doesn't solve the business requirement. The architectural solution (Kinesis fan-out) meets all three needs within the limit.

---

## Q12: CloudWatch Agent Troubleshooting

After installing the CloudWatch Agent on an EC2 instance, no custom metrics appear in CloudWatch. The agent log shows "AccessDeniedException." What is the MOST LIKELY cause?

- **A)** The CloudWatch Agent configuration file has incorrect metric definitions
- **B)** The EC2 instance's IAM role does not have the `cloudwatch:PutMetricData` permission
- **C)** The Security Group is blocking outbound traffic to the CloudWatch endpoint
- **D)** Detailed monitoring is not enabled on the instance

**Correct Answer: B**

**Why:** "AccessDeniedException" means the agent has connectivity (it reached the API) but was denied permission. The field agent made it to headquarters but was turned away at the door because they didn't have the right ID badge. The EC2 instance needs an IAM role with `cloudwatch:PutMetricData` (and `logs:PutLogEvents`, `logs:CreateLogGroup`, `logs:CreateLogStream` for logs).

- **A is wrong:** A misconfigured agent would produce different errors (invalid config, missing metric names), not an access denied error. The agent successfully parsed its config and tried to send data.
- **C is wrong:** If the Security Group blocked outbound traffic, you'd see a timeout or connection error, not an AccessDeniedException. Access denied means the request REACHED the service but was rejected by IAM.
- **D is wrong:** Detailed monitoring is for EC2's built-in metrics (CPU, network). It has nothing to do with the CloudWatch Agent or custom metrics. The agent operates independently of EC2's native monitoring.
