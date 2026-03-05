# Cron Job & Notification Flow - EXPLAINED

This document explains the complete flow of how cron jobs run and send notifications (Email + n8n/Slack).

---

## Overview Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              SERVER STARTUP                                   │
│                                                                              │
│   server.ts                                                                  │
│      │                                                                       │
│      └──► registerCronJobs()  ──► cron-manager.ts registers all jobs         │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ (node-cron waits for scheduled time)
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                           CRON JOB TRIGGERS                                   │
│                                                                              │
│   cron-manager.ts                                                            │
│      │                                                                       │
│      └──► executeJob(jobId) ──► calls job.task() function                    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                           TASK EXECUTION                                      │
│                                                                              │
│   cron-jobs.ts                                                               │
│      │                                                                       │
│      ├──► runBatchReminderPastDays("DIRECT_DEBIT")                           │
│      │       │                                                               │
│      │       ├──► sendBatchReminder() ──► AWS Lambda (sends SMS)             │
│      │       │                                                               │
│      │       └──► sendNotification() ──► Email + n8n (report)                │
│      │                                                                       │
│      └──► runBatchReminderToday("CREDIT_CARD")                               │
│              │                                                               │
│              ├──► sendBatchReminder() ──► AWS Lambda (sends SMS)             │
│              │                                                               │
│              └──► sendNotification() ──► Email + n8n (report)                │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                         NOTIFICATION DELIVERY                                 │
│                                                                              │
│   notification-service.ts                                                    │
│      │                                                                       │
│      └──► sendNotification() runs in PARALLEL:                               │
│              │                                                               │
│              ├──► sendEmailNotification() ──► AWS SES ──► Email inbox        │
│              │                                                               │
│              ├──► sendN8nNotification() ──► n8n webhook ──► Slack            │
│              │                                                               │
│              └──► sendSlackNotification() ──► Slack webhook (disabled)       │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Files Involved

| File | Purpose |
|------|---------|
| `app/src/server.ts` | Entry point - calls `registerCronJobs()` on startup |
| `app/src/services/cron-jobs.ts` | Defines cron job tasks and schedules |
| `app/src/services/cron-manager.ts` | Manages cron scheduling (start/stop/trigger) |
| `app/src/services/batch-reminder-service.ts` | Business logic to call Lambda for SMS |
| `app/src/services/notification-service.ts` | Sends notifications to Email/Slack/n8n |
| `app/src/config.ts` | Configuration (webhook URLs, email settings) |

---

## Detailed Flow: Batch Reminder SMS Report (DIRECT_DEBIT)

### Step 1: Server Starts

**File:** `app/src/server.ts`

```typescript
import { registerCronJobs } from "./services/cron-jobs";

// Register cron jobs when server starts
registerCronJobs();
```

### Step 2: Cron Jobs Registered

**File:** `app/src/services/cron-jobs.ts`

```typescript
export function registerCronJobs(): void {
    // Only in production!
    if (process.env.NODE_ENV !== "production") {
        console.log("[CRON] Skipping cron job registration (not production)");
        return;
    }

    cronManager.registerJob({
        id: "batch-reminder-past-days-1005",
        name: "Batch Reminder for Past Days (DIRECT_DEBIT) - 10:05 AM",
        schedule: "5 10 * * *",  // 10:05 AM
        timezone: "Australia/Sydney",
        enabled: true,
        task: batchReminderPastDaysTask,  // ◄── This function will be called
        errorCount: 0,
    });
}
```

### Step 3: Cron Manager Schedules Job

**File:** `app/src/services/cron-manager.ts`

```typescript
registerJob(job: CronJob): void {
    this.jobs.set(job.id, job);
    
    if (job.enabled) {
        this.startJob(job.id);  // ◄── Creates node-cron task
    }
}

startJob(jobId: string): void {
    const task = cron.schedule(
        job.schedule,           // "5 10 * * *"
        async () => {
            await this.executeJob(jobId);  // ◄── Called at 10:05 AM Sydney
        },
        { timezone: job.timezone }  // "Australia/Sydney"
    );
}
```

### Step 4: At 10:05 AM Sydney - Job Executes

**File:** `app/src/services/cron-manager.ts`

```typescript
private async executeJob(jobId: string): Promise<void> {
    const job = this.jobs.get(jobId);
    
    console.log(`[CRON] Executing job: ${job.name} at ${new Date().toISOString()}`);
    
    await job.task();  // ◄── Calls batchReminderPastDaysTask()
}
```

### Step 5: Task Function Runs

**File:** `app/src/services/cron-jobs.ts`

```typescript
async function batchReminderPastDaysTask(): Promise<void> {
    return runBatchReminderPastDays("DIRECT_DEBIT");
}

async function runBatchReminderPastDays(paymentMethod): Promise<void> {
    // 1. Calculate dates (past 4 days)
    const dates = ["2026-01-22", "2026-01-21", "2026-01-20", "2026-01-19"];
    
    // 2. For each date, call Lambda to send SMS
    for (const debitDate of dates) {
        const result = await sendBatchReminder(debitDate, paymentMethod);
        results.push(result);
    }
    
    // 3. Send notification report (Email + n8n)
    await sendNotification({
        title: "Batch Reminder SMS Report - 2026-01-23",
        message: "Processed 4 days...",
        data: { results, summary }
    });
}
```

### Step 6: Lambda Called for SMS

**File:** `app/src/services/batch-reminder-service.ts`

```typescript
export async function sendBatchReminder(debitDate, paymentMethod): Promise<Result> {
    const command = new InvokeCommand({
        FunctionName: getLambdaName("SEND_BATCH_REMINDER"),
        Payload: JSON.stringify({
            arguments: { debitDate, paymentMethod }
        }),
    });
    
    const result = await lambdaClient.send(command);
    
    return {
        ok: result.StatusCode === 200,
        debitDate,
        paymentMethod,
        lambdaResponse: result
    };
}
```

### Step 7: Notification Sent (Email + n8n)

**File:** `app/src/services/notification-service.ts`

```typescript
export async function sendNotification(options): Promise<void> {
    // All channels run in PARALLEL (Promise.allSettled)
    await Promise.allSettled([
        sendSlackNotification(options),   // Disabled (no URL configured)
        sendEmailNotification(options),   // ◄── AWS SES
        sendN8nNotification(options),     // ◄── n8n webhook → Slack
    ]);
}
```

### Step 7a: Email via AWS SES

```typescript
export async function sendEmailNotification(options): Promise<void> {
    const sesClient = getAwsClient<SESClient>(SESClient);
    
    const command = new SendEmailCommand({
        Source: "noreply@the-hub.ai",
        Destination: { ToAddresses: ["amrit.regmi@vivaleisure.com.au"] },
        Message: {
            Subject: { Data: options.title },
            Body: {
                Text: { Data: options.message },
                Html: { Data: formatEmailAsHtml(options) }
            }
        }
    });
    
    await sesClient.send(command);
}
```

### Step 7b: n8n Webhook → Slack

```typescript
export async function sendN8nNotification(options): Promise<void> {
    const webhookUrl = config.notifications.n8nWebhookUrl;
    
    const payload = {
        title: options.title,
        message: options.message,
        data: options.data,
        timestamp: new Date().toISOString(),
        environment: config.nodeEnv
    };
    
    await axios.post(webhookUrl, payload);
    // n8n receives this → formats nice Slack message → sends to Slack channel
}
```

---

## Registered Cron Jobs

| Job ID | Schedule | Timezone | Task |
|--------|----------|----------|------|
| `daily-batch-report` | 8:00 AM | Sydney | Daily payment report |
| `batch-reminder-past-days-1005` | 10:05 AM | Sydney | DIRECT_DEBIT past 4 days |
| `batch-reminder-past-days-1130` | 11:30 AM | Sydney | DIRECT_DEBIT past 4 days |
| `batch-reminder-today-credit` | 10:10 AM | Sydney | CREDIT_CARD today only |

---

## External Services Called

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   AWS Lambda    │     │    AWS SES      │     │      n8n        │
│                 │     │                 │     │                 │
│ Sends SMS to    │     │ Sends email to  │     │ Forwards to     │
│ customers       │     │ recipients      │     │ Slack channel   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        ▲                       ▲                       ▲
        │                       │                       │
        │                       │                       │
┌───────┴───────────────────────┴───────────────────────┴───────────┐
│                        Express App (App Runner)                    │
│                                                                    │
│   cron-jobs.ts  →  batch-reminder-service.ts  →  Lambda           │
│                 →  notification-service.ts    →  SES + n8n        │
└────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Required

**File:** `app/src/config.ts`

```typescript
notifications: {
    n8nWebhookUrl: process.env.N8N_WEBHOOK_URL || "",   // n8n webhook
    slackWebhookUrl: process.env.SLACK_WEBHOOK_URL || "", // Direct Slack (disabled)
    email: {
        enabled: true,
        from: "noreply@the-hub.ai",
        recipients: ["amrit.regmi@vivaleisure.com.au"],
    },
}
```

**Environment Variables:**
- `N8N_WEBHOOK_URL` - n8n webhook URL (sends to Slack)
- `SLACK_WEBHOOK_URL` - Direct Slack webhook (currently not used)

---

## Manual Trigger (for testing)

You can manually trigger any cron job via API:

```bash
POST /api/v1/cron-jobs/{jobId}/trigger

# Example:
curl -X POST https://minihub-api.viva-sls.com/api/v1/cron-jobs/batch-reminder-past-days-1005/trigger \
  -H "x-api-key: your-api-key"
```

---

## Summary

1. **Server starts** → `registerCronJobs()` called
2. **Cron manager** schedules jobs with `node-cron`
3. **At scheduled time** → cron manager executes the task function
4. **Task function** → calls business logic (Lambda for SMS)
5. **After business logic** → calls `sendNotification()`
6. **Notification service** → sends to Email (SES) + n8n (Slack) in parallel
7. **n8n** → receives webhook, formats message, sends to Slack channel
