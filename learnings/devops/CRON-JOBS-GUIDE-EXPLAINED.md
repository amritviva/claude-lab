# Cron Jobs Guide

## 📚 How Cron Jobs Work in Express/Node.js

### Concept Overview

**Cron jobs** are scheduled tasks that run automatically at specified times. In Node.js/Express:

1. **Same Process**: Cron jobs run in the same Node.js process as your Express app
2. **Background Tasks**: They execute in the background, independent of HTTP requests
3. **Scheduled Execution**: Tasks run based on cron expressions (e.g., "every day at 10 AM")
4. **Automatic**: Once registered, they run automatically - no manual intervention needed

### How It Works

```
┌─────────────────────────────────────┐
│   Node.js Process (Your Server)     │
│                                      │
│  ┌──────────────┐  ┌─────────────┐ │
│  │ Express App  │  │ Cron Jobs   │ │
│  │ (HTTP Server)│  │ (Scheduler) │ │
│  └──────────────┘  └─────────────┘ │
│         │                  │         │
│         │                  │         │
│    HTTP Requests    Scheduled Tasks  │
└─────────────────────────────────────┘
```

1. **Server Starts**: When your Express server starts, cron jobs are registered
2. **Scheduler Runs**: The `node-cron` library watches the clock
3. **Time Matches**: When the scheduled time arrives, the task function executes
4. **Task Completes**: The function runs (can be async), and the scheduler waits for the next occurrence

### Cron Expression Format

Cron expressions use 5 fields (or 6 with seconds):

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
* * * * *
```

**Examples:**

- `0 10 * * *` - Every day at 10:00 AM
- `0 */6 * * *` - Every 6 hours
- `0 9 * * 1-5` - Every weekday at 9:00 AM
- `30 14 * * *` - Every day at 2:30 PM
- `0 0 1 * *` - First day of every month at midnight

### Why This Approach?

**Pros:**

- ✅ Simple: No external services needed
- ✅ Integrated: Same codebase, same environment
- ✅ Easy to test: Can trigger manually via endpoints
- ✅ Shared logic: Cron jobs can call the same services as HTTP handlers

**Cons:**

- ⚠️ Single instance: If you run multiple server instances, each will run the cron job
- ⚠️ Process dependency: If the server crashes, cron jobs stop
- ⚠️ Not distributed: Not ideal for very high-scale systems

**For AWS App Runner:**

- App Runner runs a single container instance, so this approach works perfectly
- If you need distributed cron jobs later, consider AWS EventBridge

---

## 🚀 Current Implementation

### Registered Cron Jobs

#### 1. Daily Batch Payment Report

- **ID**: `daily-batch-report`
- **Schedule**: `0 09 * * *` (Every day at 9:00 AM)
- **What it does**:
    1. Calls the `get-batch` service for today's date
    2. Formats the batch payment data
    3. Sends notification to Slack/Email with the report
    4. Includes warnings if there are unsubmitted items

#### 2. Batch Reminder for Past Days (DIRECT_DEBIT)

- **IDs**:
    - `batch-reminder-past-days-1005` (10:05 AM)
    - `batch-reminder-past-days-1130` (11:30 AM)
- **Schedules**:
    - `5 10 * * *` (Every day at 10:05 AM)
    - `30 11 * * *` (Every day at 11:30 AM)
- **What it does**:
    1. Processes the past 3 days (configurable in code: `app/src/services/cron-jobs.ts`, constant `BATCH_REMINDER_DAYS_BACK`)
    2. For each date, sends SMS reminders for DIRECT_DEBIT payments via Lambda
    3. Tracks success/failure for each date
    4. Sends email notification with:
        - ✅ Green status for successful dates
        - ❌ Red status for failed dates
        - Summary of total successful vs failed
        - Easy-to-read format showing which days went OK and which had errors
- **Example**: If today is 2026-01-25 (with default 3 days):
    - Processes: 2026-01-24, 2026-01-23, 2026-01-22
    - Sends SMS for DIRECT_DEBIT for each of these dates
    - Reports results in email with colored status indicators
- **Note**: The same process runs at two different times (10:05 AM, 11:30 AM) to ensure reminders are sent
- **To change the number of days**: Edit `BATCH_REMINDER_DAYS_BACK` constant in `app/src/services/cron-jobs.ts`

---

## 📝 Adding New Cron Jobs

### Step 1: Create the Task Function

In `app/src/services/cron-jobs.ts`, add your task function:

```typescript
async function myNewTask(): Promise<void> {
    console.log("[CRON] Running my new task");

    try {
        // Your logic here
        const result = await someService.doSomething();

        // Send notification if needed
        await sendNotification({
            title: "My Task Completed",
            message: `Task completed successfully: ${result}`,
        });
    } catch (error) {
        console.error("[CRON] Task failed:", error);
        throw error; // Re-throw so cron manager tracks the error
    }
}
```

### Step 2: Register the Job

In the same file, add to `registerCronJobs()`:

```typescript
cronManager.registerJob({
    id: "my-new-task",
    name: "My New Task",
    schedule: "0 9 * * *", // 9 AM daily
    enabled: true,
    task: myNewTask,
    errorCount: 0,
});
```

### Step 3: Test It

1. **Manual trigger** (for testing):

    ```bash
    curl -X POST http://localhost:3000/api/v1/cron-jobs/my-new-task/trigger \
      -H "x-api-key: your-api-key"
    ```

2. **Check status**:
    ```bash
    curl http://localhost:3000/api/v1/cron-jobs/my-new-task/status \
      -H "x-api-key: your-api-key"
    ```

---

## 🔧 Configuration

### Environment Variables

Add to `app/.env` (local) or `infra/config/prod-env.json` (production):

```bash
# Email notifications are hardcoded in app/src/config.ts
# (EMAIL_NOTIFICATIONS_ENABLED, EMAIL_FROM, and EMAIL_RECIPIENTS are all in code, not in environment variables)

# Slack notifications (optional - currently disabled)
# SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Note: Batch reminder days back setting is in code (app/src/services/cron-jobs.ts), not in environment variables
```

### Setting Up Email (AWS SES)

**Email notifications use AWS SES (Simple Email Service).**

#### 1. Verify Email Addresses in SES

Before sending emails, you need to verify the sender email address:

1. Go to AWS Console → SES → Verified identities
2. Click "Create identity"
3. Choose "Email address"
4. Enter your `EMAIL_FROM` address (e.g., `noreply@yourdomain.com`)
5. Check your email and click the verification link

**Note**: In AWS SES sandbox mode, you can only send to verified email addresses. To send to any email:

- Request production access in SES console
- Or verify the recipient email addresses as well

#### 2. Configure IAM Permissions

**✅ Already configured!** The App Runner IAM role already has SES permissions in the CDK stack (`infra/lib/infra-stack.ts`).

The permissions are automatically added when you deploy:

- `ses:SendEmail`
- `ses:SendRawEmail`

**No manual configuration needed** - the CDK stack handles this automatically.

#### 3. For Local Development

If testing locally, ensure your AWS credentials have SES permissions:

- Use `AWS_PROFILE` environment variable
- Or configure AWS credentials in `~/.aws/credentials`

### Setting Up Slack Webhook (Optional - Currently Disabled)

Slack notifications are available but currently disabled. To enable:

1. Go to https://api.slack.com/apps
2. Create a new app or select existing
3. Go to "Incoming Webhooks"
4. Activate webhooks and create a new webhook
5. Copy the webhook URL to `SLACK_WEBHOOK_URL`

---

## 🧪 Testing Cron Jobs

### Method 1: Manual Trigger (Recommended)

Use the API endpoint to trigger jobs manually:

```bash
# Trigger the daily batch report
curl -X POST http://localhost:3000/api/v1/cron-jobs/daily-batch-report/trigger \
  -H "x-api-key: your-api-key"
```

### Method 2: Check Status

```bash
# Get all cron jobs
curl http://localhost:3000/api/v1/cron-jobs \
  -H "x-api-key: your-api-key"

# Get specific job status
curl http://localhost:3000/api/v1/cron-jobs/daily-batch-report/status \
  -H "x-api-key: your-api-key"
```

### Method 3: Temporarily Change Schedule

For testing, you can temporarily change the schedule in `cron-jobs.ts`:

```typescript
schedule: "*/5 * * * *", // Every 5 minutes (for testing)
```

**Remember to change it back!**

---

## 📊 Monitoring

### Logs

Cron jobs log to the console:

```
[CRON] Registered job: Daily Batch Payment Report (daily-batch-report) - Schedule: 0 10 * * *
[CRON] Executing job: Daily Batch Payment Report (daily-batch-report) at 2026-01-23T10:00:00.000Z
[CRON] Job Daily Batch Payment Report (daily-batch-report) completed successfully in 1234ms
```

### Status Endpoint

Check job status via API:

```json
{
    "ok": true,
    "jobId": "daily-batch-report",
    "exists": true,
    "enabled": true,
    "lastRun": "2026-01-23T10:00:00.000Z",
    "errorCount": 0
}
```

---

## 🎯 Best Practices

1. **Idempotent Tasks**: Make sure cron jobs can run multiple times safely
2. **Error Handling**: Always wrap tasks in try-catch and re-throw errors
3. **Logging**: Log start, completion, and errors
4. **Notifications**: Send notifications for both success and failure
5. **Testing**: Always test with manual trigger before relying on schedule
6. **Timezone**: Be aware of server timezone (App Runner uses UTC by default)

---

## 🔄 Shared Logic Pattern

Notice how we extract business logic into services:

```
HTTP Handler → Service ← Cron Job
     ↓           ↓         ↓
   HTTP      Business   Scheduled
  Request     Logic      Task
```

**Example:**

- `get-batch.handler.ts` (HTTP) → `batch-service.ts` ← `cron-jobs.ts` (Cron)

This allows:

- ✅ Same logic for HTTP and cron
- ✅ Easy testing
- ✅ Consistent behavior
- ✅ No code duplication

---

## 🚨 Troubleshooting

### Cron Job Not Running

1. **Check if enabled**: Look at job status via API
2. **Check logs**: Look for `[CRON]` messages in server logs
3. **Check timezone**: Server might be in different timezone than expected
4. **Check schedule**: Verify cron expression is correct

### Notifications Not Sending

1. **Check config**: Verify `SLACK_WEBHOOK_URL` or email settings
2. **Check logs**: Look for `[NOTIFICATION]` messages
3. **Test manually**: Trigger the job and check logs

### Job Failing

1. **Check error count**: Via status endpoint
2. **Check last error**: Status endpoint shows last error message
3. **Check logs**: Full stack trace in server logs

---

## 📚 Additional Resources

- [node-cron Documentation](https://github.com/node-cron/node-cron)
- [Cron Expression Generator](https://crontab.guru/)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
