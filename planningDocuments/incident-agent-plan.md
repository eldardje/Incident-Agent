# Incident Response Agent — Full Project Plan

> **Stack:** Next.js 14 · Python Lambdas · AWS (Lambda, API Gateway, ECS, DynamoDB, Secrets Manager, CloudWatch, SNS, SES) · LangChain + Claude · n8n · Clerk · Terraform · GitHub Actions
>
> **Timeline:** 8 Weeks · 5–10 hrs/week · Dev → Staging → Prod
>
> **Repos:** `incident-response-agent` (separate repo from Career Platform)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Business Purpose & Real-World Use Cases](#2-business-purpose--real-world-use-cases)
3. [User Roles & Permissions](#3-user-roles--permissions)
4. [System Architecture](#4-system-architecture)
5. [Repository Structure](#5-repository-structure)
6. [Phase 1 — Infrastructure Foundation](#6-phase-1--infrastructure-foundation)
7. [Phase 2 — Agent Lambdas](#7-phase-2--agent-lambdas)
8. [Phase 3 — Config UI](#8-phase-3--config-ui)
9. [Phase 4 — Incident Dashboard](#9-phase-4--incident-dashboard)
10. [Phase 5 — Polish, Deploy & v2 Stubs](#10-phase-5--polish-deploy--v2-stubs)
11. [CI/CD Pipeline Design](#11-cicd-pipeline-design)
12. [LangChain + Claude Integration](#12-langchain--claude-integration)
13. [n8n Incident Router Workflow](#13-n8n-incident-router-workflow)
14. [Environment Strategy](#14-environment-strategy)
15. [v2 SaaS Roadmap](#15-v2-saas-roadmap)
16. [Cost Breakdown](#16-cost-breakdown)
17. [Resume Bullets](#17-resume-bullets)

---

## 1. Project Overview

The Incident Response Agent is a configurable, full-stack AI-powered incident management platform. It watches for CloudWatch alarms, pulls the relevant logs, and uses **LangChain + Claude** to generate a plain-English incident summary, root cause analysis, and an ordered list of remediation steps — then routes the findings to the right people via **n8n**.

The platform is designed with two audiences in mind:

- **Self-hosters** — DevOps engineers who want to deploy it quickly with a `.env` file and get AI-powered incident analysis into their Slack in under an hour
- **Teams** — Engineering organizations that want a shared dashboard with role-based access, incident lifecycle management, and a configurable notification setup via a web UI

The core engineering insight is the **Normalizer → Analyzer → n8n Router** pipeline. The Normalizer Lambda translates raw CloudWatch payloads into a clean internal schema. The Analyzer Lambda runs the AI analysis without caring where the alarm came from. And n8n handles all routing and delivery decisions without a single line of custom notification code.

This architecture is designed to be extensible: adding a new input source (Datadog, Grafana, PagerDuty) in v2 only requires writing a new normalizer function. Adding a new notification output (Teams, OpsGenie) only requires adding a new n8n node.

---

## 2. Business Purpose & Real-World Use Cases

This section explains the real business value the Incident Response Agent provides. These are the scenarios you should describe in interviews when asked "why did you build this?" and "what problem does it solve?"

---

### 2.1 The Problem: Alert Fatigue and Slow Diagnosis

Modern engineering teams monitor hundreds of metrics across dozens of services. When something goes wrong at 2 AM, the on-call engineer gets paged with a raw CloudWatch alarm:

```
ALARM: "HighCPUUtilization"
Threshold: CPUUtilization > 80 for 5 minutes
Current Value: 94.3%
Alarm ARN: arn:aws:cloudwatch:us-east-1:...
```

That alarm tells the engineer *something is wrong* but not *why*, not *what's affected*, and not *what to do first*. The engineer has to:

1. Log into AWS console
2. Navigate to CloudWatch Logs
3. Filter logs for the right time window
4. Read through potentially thousands of log lines
5. Form a hypothesis about the root cause
6. Decide on a remediation action

At 2 AM, under pressure, with incomplete context, this process can take 15–30 minutes just to diagnose — before any fix is even started. This is what the industry calls **Mean Time to Diagnosis (MTTD)** and it directly impacts **Mean Time to Resolution (MTTR)**, which is one of the four DORA metrics used to measure engineering team performance.

---

### 2.2 What the Agent Does Instead

When the same `HighCPUUtilization` alarm fires, here is what happens with the Incident Response Agent:

**Within 60 seconds, the on-call engineer receives a Slack message:**

```
🔴 CRITICAL INCIDENT — Immediate Action Required

Title: High CPU Utilization — web-prod-cluster
Triggered: 2:14 AM MST | Source: CloudWatch | Account: 123456789

AI SUMMARY
The web-prod ECS cluster is experiencing sustained CPU saturation at 94.3%.
Log analysis indicates a spike in database connection pool exhaustion beginning
at 2:09 AM, coinciding with a deployment at 2:07 AM. 847 requests timed out
in the 5-minute window preceding the alarm.

ROOT CAUSE
Probable cause: the new deployment introduced an N+1 query pattern in the
/api/jobs endpoint. Connection pool is maxed at 10 connections with 40+
concurrent requests queuing. Database CPU is normal — this is an application-
level connection management issue.

FIX SUGGESTIONS (in order of priority)
1. Roll back the 2:07 AM deployment using: aws ecs update-service --task-definition previous-revision
2. If rollback is not possible, increase DB pool max_connections to 25 in the task definition
3. Add connection pool monitoring to prevent recurrence

AFFECTED SERVICES: web-api, job-search-service, user-auth-service

[View Full Incident →]
```

**The engineer now knows:** what happened, why it happened, what's affected, and exactly what to do — in 60 seconds, without logging into a single console.

---

### 2.3 Real-World Business Scenarios

The following scenarios illustrate how different types of engineering teams would use the agent and what business value they would derive.

---

#### Scenario A: E-Commerce Platform — Black Friday Traffic Spike

**Company type:** Mid-size e-commerce company, 8-person engineering team

**Situation:** At 9:03 AM on Black Friday, a `HighErrorRate` CloudWatch alarm fires on the checkout service. The error rate hits 12% — normally 0.02%.

**Without the agent:**
- On-call engineer gets paged
- Spends 20 minutes reading logs manually
- Identifies that a third-party payment gateway is returning 503s
- Another 10 minutes to communicate the issue to the team and stakeholders
- Total time before a status page update: 35 minutes
- **Business impact: ~$180,000 in lost revenue** (industry average: ~$5,000/minute for mid-size e-commerce during peak)

**With the agent:**

The Analyzer Lambda fetches logs from `/aws/lambda/checkout-service` for the 10-minute window around the alarm. Claude identifies the pattern:

```
AI SUMMARY
12% error rate on the checkout service beginning at 09:03 AM. Log analysis
shows 94% of errors are HTTP 503 responses from api.payment-gateway.com,
first seen at 09:01 AM. All other checkout service components (cart, inventory,
user auth) are responding normally. This is an upstream third-party dependency
failure, not an internal issue.

ROOT CAUSE
Payment gateway outage or rate limiting. The checkout service is not
implementing circuit breaker logic — failed requests are retrying immediately,
amplifying load on the failing gateway.

FIX SUGGESTIONS
1. Enable maintenance mode on checkout — show "payment processing temporarily
   unavailable" instead of error pages
2. Check payment gateway status page: status.payment-gateway.com
3. Implement exponential backoff retry logic (prevent retry storms)
4. Consider failover to secondary payment provider if outage exceeds 5 minutes
```

Slack notification received 55 seconds after alarm. Engineer enables maintenance mode in 3 minutes. **Total MTTD: under 2 minutes.** **Estimated revenue saved vs. baseline: ~$160,000.**

---

#### Scenario B: SaaS Platform — Database Connection Exhaustion

**Company type:** B2B SaaS startup, 4-person engineering team, no dedicated DevOps

**Situation:** At 11:45 PM, a `DatabaseConnectionsHigh` alarm fires. The on-call engineer is a frontend developer who has never debugged a database connection issue.

**Without the agent:**
- Engineer gets paged, has no idea where to start
- Spends 45 minutes reading AWS docs and Stack Overflow
- Escalates to the CTO at 12:30 AM
- Root cause found at 1:15 AM: a background job introduced in yesterday's deploy is not closing database connections
- Fix deployed at 1:45 AM
- **Total downtime: 2 hours | Business impact: customer SLA breach, potential churn**

**With the agent:**

```
AI SUMMARY
RDS PostgreSQL connection count reached 95/100 maximum connections at 11:45 PM.
Log analysis of the past 30 minutes shows a gradual linear increase in active
connections starting at 11:12 PM. No corresponding increase in web traffic.
A deploy was recorded at 11:10 PM.

ROOT CAUSE
A background job introduced in the 11:10 PM deployment is opening database
connections but not releasing them. The pg connection pool in the affected
Lambda function appears to be initialized outside the handler function,
creating a new pool per Lambda invocation rather than reusing a warm pool.

FIX SUGGESTIONS
1. Immediately: run this query to identify the long-running connections:
   SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
   FROM pg_stat_activity WHERE state != 'idle' ORDER BY duration DESC LIMIT 20;
2. Kill runaway connections: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction';
3. Roll back the 11:10 PM deployment
4. Fix: move pg Pool initialization inside the Lambda handler or use RDS Proxy
```

The non-specialist engineer follows the exact SQL queries provided by Claude, kills the runaway connections, and rolls back the deployment. **MTTD: 3 minutes. MTTR: 22 minutes vs. 2 hours.**

---

#### Scenario C: Fintech Company — Lambda Timeout Cascade

**Company type:** Fintech startup processing payment transactions, 12-person team

**Situation:** At 3:17 PM on a Tuesday, a `LambdaTimeoutErrors` alarm fires on the `process-transactions` Lambda. The error rate is 34%.

**Business stakes:** Every timed-out Lambda invocation represents a failed transaction. At $150 average transaction value and 200 transactions/minute, this is **$30,000/minute in failed revenue**.

**With the agent:**

```
AI SUMMARY
The process-transactions Lambda is timing out at a 34% rate beginning at 3:15 PM.
Log analysis shows all timeouts occurring on calls to the external fraud-detection
API (api.fraud-check.io). The fraud detection API response time increased from
a baseline of 120ms to 8,200ms at approximately 3:13 PM, causing Lambda functions
configured with a 10-second timeout to approach their limit.

ROOT CAUSE
External fraud detection service degradation. The Lambda timeout is set to 10
seconds which is insufficient buffer when the upstream API is experiencing latency.
The Lambda is also not implementing a request timeout — it waits the full duration
before failing.

FIX SUGGESTIONS
1. IMMEDIATE: Increase Lambda timeout from 10s to 30s via AWS Console to
   stop the current bleeding (this buys time while the real fix is deployed)
2. Add an HTTP request timeout of 5 seconds to the fraud API call with a
   fallback to allow-with-manual-review if the API is unavailable
3. Implement a circuit breaker: after 5 consecutive timeouts, bypass fraud
   check and queue for manual review
4. Alert the fraud detection vendor: their status page shows no incident —
   contact their support line directly

REQUIRES IMMEDIATE ACTION: YES
ESTIMATED IMPACT: ~$30,000/minute in transaction failures
```

The n8n workflow sees `requires_immediate_action: true` and simultaneously posts to Slack AND sends a high-priority email to the engineering lead and CTO. The Lambda timeout is increased in 4 minutes. A proper circuit breaker is deployed in the next sprint.

---

#### Scenario D: Healthcare Platform — Memory Leak Detection

**Company type:** Healthcare tech company, patient scheduling SaaS

**Situation:** Over 6 hours, ECS container memory usage on the `scheduling-api` service creeps from 40% to 89%. A `HighMemoryUtilization` alarm fires.

**Business context:** If this service goes down, hospitals cannot schedule patients. The consequences are regulatory, reputational, and potentially patient-safety related.

**With the agent:**

```
AI SUMMARY
ECS container memory has been climbing linearly from 40% to 89% over 6 hours
on the scheduling-api service. This pattern is characteristic of a memory leak
rather than a traffic spike — there is no corresponding increase in request volume.
The leak rate is approximately 8% per hour, suggesting the service will OOM
in approximately 1.5 hours if no action is taken.

ROOT CAUSE
Log analysis shows an increasing number of "EventEmitter memory leak detected"
Node.js warnings beginning 6 hours ago, coinciding with a dependency update
to a WebSocket library. The WebSocket library is likely creating event listeners
that are not being removed when connections close.

FIX SUGGESTIONS
1. IMMEDIATE: Restart the ECS task now to restore normal memory — this is
   a safe operation as the service is stateless. Use:
   aws ecs stop-task --cluster scheduling-cluster --task <task-id>
   ECS will automatically start a replacement task.
2. Set up ECS memory-based auto-restart: add container health check that
   restarts tasks at 85% memory as a temporary safeguard
3. Root fix: pin the WebSocket library to the previous version and audit
   removeEventListener calls in connection close handlers
4. Add memory trend alerting: alarm at 70% to give more response time
```

The service is restarted in 3 minutes. The memory leak is triaged and a hotfix is deployed the next morning. **Zero patient-facing downtime.**

---

#### Scenario E: Startup Engineering Team — 2 AM Disk Space Alert

**Company type:** Early-stage startup, 2 engineers, no dedicated on-call

**Situation:** At 2:47 AM, a `DiskSpaceHigh` alarm fires. Neither engineer has set up centralized logging. They don't know where to look.

**With the agent:**

```
AI SUMMARY
EBS volume disk usage on web-server-prod has reached 91% (45.5GB of 50GB used).
At the current fill rate of ~200MB/day, the disk will reach 100% capacity in
approximately 22 days. However, log analysis shows an unusual spike of 8GB
written in the past 12 hours — 40x the normal rate — which is the primary cause
of the sudden alarm.

ROOT CAUSE
The application debug logging level was changed to DEBUG in yesterday's deployment
(visible in the deploy log at 2:15 PM). Debug-level logging is generating
approximately 650MB/hour of logs vs. the normal 16MB/hour at INFO level.

FIX SUGGESTIONS
1. IMMEDIATE: Change LOG_LEVEL environment variable from DEBUG back to INFO
   in the ECS task definition and force a new deployment — this stops the
   bleeding immediately
2. Clear existing debug logs: sudo journalctl --vacuum-size=1G
3. Set up log rotation: ensure /etc/logrotate.d/ is configured for application logs
4. Long term: add disk usage trending alert at 70% to catch this earlier
```

The 2 AM call takes 8 minutes instead of 45. The engineers go back to sleep.

---

### 2.4 The Business Case for AI-Powered Incident Response

| Metric | Without Agent | With Agent | Improvement |
|---|---|---|---|
| Mean Time to Diagnosis | 15–30 min | 1–3 min | **85–90% reduction** |
| On-call engineer skill required | Senior/specialist | Any engineer | **Democratized** |
| Incidents escalated unnecessarily | ~40% | ~10% | **75% reduction** |
| Context switching cost (engineer woken up) | High | Lower | **Reduced burnout** |
| Post-incident documentation | Manual, inconsistent | Auto-generated | **100% coverage** |

The core value proposition: **Claude reads logs faster than humans, never panics, and always provides an ordered remediation plan.** For engineering leaders, this means smaller MTTR numbers on their DORA metrics dashboard. For engineers, it means fewer 2 AM calls that last 2 hours.

---

## 3. User Roles & Permissions

### v1 Roles (Built Now)

| Feature | Engineer | Admin |
|---|---|---|
| View incident list | ✅ | ✅ |
| View incident detail + AI analysis | ✅ | ✅ |
| Acknowledge incident | ✅ | ✅ |
| Assign incident to team member | ✅ | ✅ |
| Add comment / note | ✅ | ✅ |
| Trigger re-analysis | ✅ | ✅ |
| Resolve / close incident | ✅ | ✅ |
| View settings (read only) | ✅ | ✅ |
| Edit notification config | ❌ | ✅ |
| Edit CloudWatch config | ❌ | ✅ |
| Invite team members | ❌ | ✅ |
| Change user roles | ❌ | ✅ |
| Deactivate users | ❌ | ✅ |

### v2 Roles (Stubbed, Not Enforced in v1)

| Role | Purpose |
|---|---|
| **Admin** | Full platform control (v1 admin maps to this) |
| **Team Owner** | Manages their team's config and membership |
| **Engineer / On-Call** | Full incident interaction (v1 engineer maps to this) |
| **Read-Only / Viewer** | Stakeholders and managers — view only |

Roles are stored in Clerk `publicMetadata`. The `shared/roles.py` file defines all 4 roles now — only admin and engineer are enforced in middleware, but the full ROLES dict is there for v2 activation.

---

## 4. System Architecture

### End-to-End Flow

```
CloudWatch Alarm
       │
       ▼
   SNS Topic
       │
       ├──────────────────────────┐
       ▼                          ▼
API Gateway                n8n Webhook
(/webhook endpoint)        (notification router)
       │                          │
       ▼                          │
Normalizer Lambda                 │
       │                          │
       │  Writes incident         │
       │  to DynamoDB             │
       │  status: 'open'          │
       ▼                          │
API Gateway response              │
       │                          │
       └──────────────────────────┘
                    │ (n8n receives SNS payload)
                    ▼
         n8n: Extract incident_id
                    │
                    ▼
         n8n: HTTP Request →
         Analyzer Lambda
                    │
                    │  Fetches CloudWatch logs
                    │  Runs LangChain chain
                    │  Updates DynamoDB
                    │  status: 'analyzed'
                    │  Returns IncidentAnalysis
                    │
                    ▼
         n8n: IF requires_immediate_action
                    │
              ┌─────┴──────┐
              ▼            ▼
          URGENT         STANDARD
              │            │
    Slack (Block Kit)     SES Email
    + SES Email           (digest only)
              │
              ▼
    n8n: PATCH incident
    status → 'notified'
              │
              ▼
          DynamoDB
```

### Component Responsibilities

| Component | Responsibility | Does NOT do |
|---|---|---|
| **CloudWatch** | Detect metric anomalies, publish to SNS | Analyze, route, notify |
| **SNS** | Fan-out to API Gateway + n8n webhook | Any logic |
| **Normalizer Lambda** | Translate raw CloudWatch payload → internal schema | AI analysis, notification |
| **Analyzer Lambda** | Fetch logs, run LangChain + Claude, store results | Routing, notification |
| **n8n** | Route by severity, send Slack + email | AI analysis, data storage |
| **Config API Lambda** | CRUD for user configuration | Incident processing |
| **DynamoDB** | Store incidents, config, audit events | Processing logic |
| **Secrets Manager** | Store webhook URLs, API keys | Processing logic |
| **Next.js UI** | Config setup flow + incident dashboard | Backend processing |

---

## 5. Repository Structure

```
incident-response-agent/
│
├── .github/
│   └── workflows/
│       ├── pr-checks.yml           # pylint, pytest, terraform plan
│       └── deploy.yml              # terraform apply, lambda deploy, ECS deploy
│
├── infrastructure/
│   ├── main.tf                     # provider, backend config
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── lambda/                 # normalizer, analyzer, config-api
│       ├── api_gateway/            # HTTP API for webhooks + config API
│       ├── dynamodb/               # incidents, config, audit tables
│       ├── secrets_manager/        # Slack webhook, SES creds
│       ├── ecs/                    # n8n + Next.js UI containers
│       ├── sns/                    # CloudWatch alarm subscription
│       └── cloudwatch/             # test alarm + log groups
│
├── lambdas/
│   ├── normalizer/
│   │   ├── handler.py
│   │   ├── requirements.txt
│   │   └── tests/
│   │       └── test_normalizer.py
│   ├── analyzer/
│   │   ├── handler.py
│   │   ├── log_fetcher.py          # CloudWatch Logs Insights queries
│   │   ├── requirements.txt
│   │   └── tests/
│   │       └── test_analyzer.py
│   └── config_api/
│       ├── handler.py              # GET/POST /config, test endpoints
│       ├── requirements.txt
│       └── tests/
│           └── test_config_api.py
│
├── shared/                         # imported by all lambdas
│   ├── langchain_client.py         # ChatAnthropic + PydanticOutputParser
│   ├── models.py                   # IncidentAnalysis Pydantic model
│   ├── config_loader.py            # .env vs DynamoDB config source
│   ├── roles.py                    # ROLES dict (all 4 roles defined)
│   └── audit.py                    # log_action() stub (v2 ready)
│
├── ui/                             # Next.js 14
│   ├── Dockerfile
│   └── app/
│       ├── (auth)/
│       ├── dashboard/              # incident list + stats
│       ├── incidents/[id]/         # detail + actions + timeline
│       ├── setup/
│       │   ├── cloudwatch/         # step 1: connect input source
│       │   └── notifications/      # step 2: configure outputs
│       └── admin/
│           ├── users/              # team management
│           ├── settings/           # current config view
│           └── audit/              # v2 stub with banner
│
└── n8n/
    └── workflows/
        └── incident-router.json    # exportable n8n workflow
```

---

## 6. Phase 1 — Infrastructure Foundation

**Weeks 1–2 | ~12 hours**

### 6.1 Terraform Infrastructure

Reuses the OIDC provider and S3 Terraform state backend already set up for the Career Platform. This is intentional — both projects use the same AWS account and the same GitHub Actions deploy role.

**DynamoDB Tables:**

```hcl
# incidents table
resource "aws_dynamodb_table" "incidents" {
  name         = "incidents-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"

  attribute { name = "incident_id" type = "S" }
  attribute { name = "org_id"      type = "S" }  # v2 multi-tenant key
  attribute { name = "status"      type = "S" }
  attribute { name = "triggered_at" type = "S" }

  # GSI for querying by org + status (v2 ready)
  global_secondary_index {
    name            = "org-status-index"
    hash_key        = "org_id"
    range_key       = "status"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}

# config table
resource "aws_dynamodb_table" "config" {
  name         = "incident-config-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "org_id"  # 'default' in v1
}

# audit table (stubbed - populated in v1, UI in v2)
resource "aws_dynamodb_table" "audit" {
  name         = "incident-audit-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "org_id"
  range_key    = "event_id"
}
```

---

## 7. Phase 2 — Agent Lambdas

**Weeks 3–4 | ~20 hours**

### 7.1 Normalizer Lambda

Receives the raw CloudWatch SNS payload and produces a clean, typed incident record.

**Input** (raw CloudWatch alarm SNS notification):
```json
{
  "AlarmName": "HighCPUUtilization-web-prod",
  "AlarmDescription": "CPU > 80% for 5 consecutive minutes",
  "AWSAccountId": "123456789012",
  "NewStateValue": "ALARM",
  "NewStateReason": "Threshold Crossed: 1 datapoint [94.3 (01/15/24 02:14:00)] was greater than the threshold (80.0).",
  "StateChangeTime": "2024-01-15T02:14:32.123+0000",
  "Region": "US East (N. Virginia)",
  "AlarmArn": "arn:aws:cloudwatch:us-east-1:123456789012:alarm:HighCPUUtilization-web-prod",
  "OldStateValue": "OK",
  "Trigger": {
    "MetricName": "CPUUtilization",
    "Namespace": "AWS/ECS",
    "Threshold": 80.0,
    "ComparisonOperator": "GreaterThanThreshold"
  }
}
```

**Output** (internal incident schema stored in DynamoDB):
```json
{
  "incident_id": "a3f8c2d1-7b4e-4f9a-b2c1-8e5d3f2a1b7c",
  "org_id": "default",
  "source": "cloudwatch",
  "severity": "high",
  "title": "High CPU Utilization — web-prod",
  "description": "CPU utilization exceeded 80% threshold. Current value: 94.3%",
  "alarm_name": "HighCPUUtilization-web-prod",
  "metric_name": "CPUUtilization",
  "namespace": "AWS/ECS",
  "threshold": 80.0,
  "current_value": 94.3,
  "triggered_at": "2024-01-15T02:14:32Z",
  "region": "us-east-1",
  "account_id": "123456789012",
  "status": "open",
  "raw_payload": "{ ... }",
  "expires_at": 1737590400
}
```

**Severity mapping logic:**
```python
def derive_severity(metric_name: str, current_value: float, threshold: float) -> str:
    overage_pct = (current_value - threshold) / threshold * 100

    # Critical metrics regardless of overage
    critical_metrics = ["ErrorRate", "5XXError", "FailedTransactions"]
    if any(m in metric_name for m in critical_metrics):
        return "critical"

    # Severity based on how far over threshold
    if overage_pct >= 50:   return "critical"  # 120% of threshold
    if overage_pct >= 25:   return "high"       # 100-125% of threshold
    if overage_pct >= 10:   return "medium"     # threshold to 110%
    return "low"
```

---

### 7.2 Analyzer Lambda — LangChain + Claude

This is the core AI component. It fetches real logs and runs a two-stage LangChain chain for higher quality analysis.

**`shared/models.py`**
```python
from pydantic import BaseModel, Field
from typing import List

class IncidentAnalysis(BaseModel):
    summary: str = Field(
        description="2-3 sentence plain English description of what happened and its scope"
    )
    root_cause: str = Field(
        description="The most probable technical root cause based on the log evidence"
    )
    severity_assessment: str = Field(
        description="Assessment of blast radius and user-facing impact"
    )
    affected_services: List[str] = Field(
        description="List of services or components that appear affected based on logs"
    )
    fix_suggestions: List[str] = Field(
        description="Ordered list of remediation steps, most impactful and fastest first. Include exact CLI commands where applicable."
    )
    estimated_impact: str = Field(
        description="Estimated user-facing impact (e.g. '~12% of checkout requests failing')"
    )
    requires_immediate_action: bool = Field(
        description="True if this is a P1/P2 incident requiring immediate human response"
    )
```

**Two-stage chain for higher quality output:**
```python
def get_analysis_chain():
    llm = ChatAnthropic(
        model="claude-sonnet-4-20250514",
        temperature=0,
        callbacks=[CloudWatchCallbackHandler()]
    )

    # Stage 1: Summarize raw logs into key events (prevents context window issues)
    log_summary_prompt = PromptTemplate(
        template="""Analyze these CloudWatch log lines from the 15 minutes
surrounding an alarm trigger. Extract the key events, errors, and patterns
that are relevant to diagnosing the incident. Be concise and technical.

LOG LINES:
{raw_logs}

Provide a structured summary of: error patterns, frequency, affected operations,
any stack traces, and timeline of events.""",
        input_variables=["raw_logs"]
    )

    # Stage 2: Full incident analysis using the log summary + alarm details
    analysis_prompt = PromptTemplate(
        template="""You are a senior SRE analyzing a production incident.
You have access to a CloudWatch alarm and a summary of the relevant logs.
Provide a structured incident analysis.

ALARM DETAILS:
- Alarm Name: {alarm_name}
- Metric: {metric_name} in {namespace}
- Threshold: {threshold}
- Current Value: {current_value}
- Triggered at: {triggered_at}
- AWS Region: {region}

LOG SUMMARY:
{log_summary}

{format_instructions}

Be specific. Include exact CLI commands in fix suggestions where applicable.
Prioritize fixes by speed of impact — what stops the bleeding first.""",
        input_variables=["alarm_name", "metric_name", "namespace", "threshold",
                        "current_value", "triggered_at", "region", "log_summary"],
        partial_variables={"format_instructions": parser.get_format_instructions()}
    )

    log_summary_chain = log_summary_prompt | llm | StrOutputParser()
    analysis_chain    = analysis_prompt    | llm | parser

    return log_summary_chain, analysis_chain
```

**CloudWatch Logs Insights query:**
```python
def fetch_relevant_logs(log_groups: list, triggered_at: datetime) -> str:
    client = boto3.client('logs')

    start_time = triggered_at - timedelta(minutes=10)
    end_time   = triggered_at + timedelta(minutes=5)

    query = """
    fields @timestamp, @message, @logStream
    | filter @message like /ERROR/ or @message like /Exception/ or @message like /WARN/
    | sort @timestamp desc
    | limit 100
    """

    # Run query against all configured log groups
    for log_group in log_groups:
        response = client.start_query(
            logGroupName=log_group,
            startTime=int(start_time.timestamp()),
            endTime=int(end_time.timestamp()),
            queryString=query
        )
        # poll until complete, collect results
```

---

## 8. Phase 3 — Config UI

**Weeks 5–6 | ~15 hours**

### 8.1 Setup Flow

The setup flow is a 2-step wizard that walks a new user through connecting their CloudWatch source and configuring their notification outputs.

**Step 1: Connect CloudWatch (`/setup/cloudwatch`)**

Form fields:
- SNS Topic ARN — validated against the pattern `arn:aws:sns:[region]:[account]:[name]`
- AWS Region — dropdown of all AWS regions
- CloudWatch Log Groups — multi-input (add/remove rows), e.g. `/aws/lambda/my-function`, `/aws/ecs/my-cluster`

After saving, display a copy-ready code block with the exact CLI command to subscribe the SNS topic to the n8n webhook URL:

```bash
# Copy and run this command to connect your CloudWatch alarm to the agent:
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:your-alarm-topic \
  --protocol https \
  --notification-endpoint https://your-alb-domain.com/n8n/webhook/incident-trigger
```

**Step 2: Notification Outputs (`/setup/notifications`)**

Two toggle cards:

**Slack card:**
```
[ Slack ]  ●───────────────── ON

Webhook URL: [https://hooks.slack.com/services/...    ]
Channel:     [#incidents                               ]

[ Test Connection ]  ✅ Test message sent to #incidents
```

**Email card:**
```
[ Email (SNS/SES) ]  ●──────────── ON

Recipients:
  oncall@company.com  [×]
  engineering@company.com  [×]
  [+ Add recipient]

[ Test Connection ]  ✅ Test email sent
```

---

### 8.2 Config API Lambda

The backend for the Config UI. All sensitive values (webhook URLs, email credentials) are stored in Secrets Manager — the GET /config endpoint never returns raw secret values, only a boolean indicating they are configured.

**Endpoints:**
```
GET  /config           → returns { cloudwatch: { sns_arn, log_groups }, outputs: { slack: { enabled, channel }, email: { enabled, recipients } } }
POST /config           → saves to DynamoDB + Secrets Manager
POST /config/test/slack  → sends real Slack test message
POST /config/test/email  → sends real SES test email
GET  /users            → admin only, lists Clerk users
POST /users/invite     → admin only, sends Clerk invitation
```

---

## 9. Phase 4 — Incident Dashboard

**Weeks 6–7 | ~18 hours**

### 9.1 Incident List View

```
┌────────────────────────────────────────────────────────────────────────┐
│  🔴 3 Open   🟡 2 Acknowledged   ✅ 12 Resolved Today   MTTA: 4.2 min  │
├────────────────────────────────────────────────────────────────────────┤
│  [All ▼] [Critical ▼] [Last 7 days ▼] [🔍 Search incidents...]        │
├─────┬──────────────────────────────┬───────────┬────────────┬──────────┤
│ SEV │ TITLE                        │ STATUS    │ TRIGGERED  │ NOTIFIED │
├─────┼──────────────────────────────┼────────────┼───────────┼──────────┤
│ 🔴  │ High CPU — web-prod          │ ● Open    │ 2 min ago  │ 📨 📧    │
│ 🟠  │ Lambda Timeout — checkout    │ ✅ Resolved│ 1 hr ago   │ 📨       │
│ 🟡  │ Disk Space — worker-node-3   │ ○ Ack'd   │ 3 hrs ago  │ 📧       │
└─────┴──────────────────────────────┴────────────┴───────────┴──────────┘
```

---

### 9.2 Incident Detail View

The most important page in the application. Every field from the `IncidentAnalysis` Pydantic model is displayed clearly.

```
┌─────────────────────────────────────────────────────────────────────┐
│ 🔴 IMMEDIATE ACTION REQUIRED                                        │
├─────────────────────────────────────────────────────────────────────┤
│ High CPU Utilization — web-prod-cluster           ● OPEN            │
│ CloudWatch  ·  us-east-1  ·  Triggered 2:14 AM MST                 │
├─────────────────────────────────────────────────────────────────────┤
│ AI ANALYSIS                                      [Re-analyze ↺]     │
│                                                                     │
│ SUMMARY                                                             │
│ The web-prod ECS cluster is experiencing sustained CPU saturation   │
│ at 94.3%. Log analysis indicates a spike in database connection     │
│ pool exhaustion beginning at 2:09 AM, coinciding with a            │
│ deployment at 2:07 AM. 847 requests timed out in the preceding     │
│ 5-minute window.                                                    │
│                                                                     │
│ ROOT CAUSE                                                          │
│ Probable N+1 query pattern introduced in the 2:07 AM deployment    │
│ on the /api/jobs endpoint. Connection pool is maxed at 10          │
│ connections with 40+ concurrent requests queuing.                  │
│                                                                     │
│ AFFECTED SERVICES                                                   │
│ [web-api] [job-search-service] [user-auth-service]                 │
│                                                                     │
│ ESTIMATED IMPACT                                                    │
│ ~34% of API requests failing with 503 timeout errors               │
│                                                                     │
│ FIX SUGGESTIONS                                                     │
│ 1. Roll back the 2:07 AM deployment:                               │
│    aws ecs update-service --task-definition previous-revision      │
│ 2. If rollback not possible: increase DB pool max_connections to 25 │
│ 3. Add connection pool monitoring to prevent recurrence             │
├─────────────────────────────────────────────────────────────────────┤
│ ACTIONS                                                             │
│ [Acknowledge] [Assign to ▼] [Add Comment] [Resolve]                │
├─────────────────────────────────────────────────────────────────────┤
│ ACTIVITY TIMELINE                                                   │
│                                                                     │
│ 2:14 AM  🔴 Incident created · CloudWatch alarm triggered           │
│ 2:15 AM  📨 Notified via Slack + Email                              │
│ 2:16 AM  👤 Acknowledged by Eldar Djedovic                         │
│ 2:18 AM  💬 "Rolling back deployment now" — Eldar Djedovic         │
│ 2:22 AM  ✅ Resolved by Eldar Djedovic · MTTR: 8 minutes           │
└─────────────────────────────────────────────────────────────────────┘
```

### 9.3 Incident Actions

All five actions update DynamoDB and add an event to the activity timeline:

| Action | Who | DynamoDB update | Timeline entry |
|---|---|---|---|
| **Acknowledge** | Engineer+ | `status = 'acknowledged'`, `acknowledge_at`, `acknowledged_by` | "Acknowledged by [user]" |
| **Assign** | Engineer+ | `assigned_to = user_id` | "Assigned to [user] by [user]" |
| **Add Comment** | Engineer+ | New item in `comments` list | "[user]: [comment text]" |
| **Re-analyze** | Engineer+ | Triggers Analyzer Lambda, updates all AI fields | "Re-analysis triggered by [user]" |
| **Resolve** | Engineer+ | `status = 'resolved'`, `resolved_at`, `resolution_time_minutes` | "Resolved by [user] · MTTR: N minutes" |

---

## 10. Phase 5 — Polish, Deploy & v2 Stubs

**Weeks 7–8 | ~10 hours**

### v2 Architecture Stubs

These are baked into the codebase from day one so that building v2 (multi-tenant SaaS) requires extending code, not rewriting it.

**`shared/roles.py`** — all 4 roles defined, only 2 enforced:
```python
ROLES = {
    "admin": [
        "manage_users", "manage_config", "view_incidents",
        "acknowledge", "comment", "resolve", "assign", "reanalyze"
    ],
    "engineer": [
        "view_incidents", "acknowledge", "comment",
        "resolve", "assign", "reanalyze"
    ],
    # v2 roles — defined but not yet enforced in middleware
    "team_owner": [
        "manage_team_users", "manage_team_config", "view_incidents",
        "acknowledge", "comment", "resolve", "assign", "reanalyze"
    ],
    "viewer": [
        "view_incidents"
    ]
}
```

**`shared/audit.py`** — fully implemented, UI is v2:
```python
import boto3, uuid
from datetime import datetime, timezone

def log_action(user_id: str, action: str, resource_id: str, org_id: str = "default"):
    """
    Logs an audit event to DynamoDB.
    Table exists and is being written to in v1.
    The Admin Audit Log UI page is a v2 feature.
    """
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(f"incident-audit-{os.environ['ENVIRONMENT']}")
    table.put_item(Item={
        "org_id":      org_id,
        "event_id":    str(uuid.uuid4()),
        "user_id":     user_id,
        "action":      action,
        "resource_id": resource_id,
        "timestamp":   datetime.now(timezone.utc).isoformat()
    })
```

**`org_id` on every DynamoDB record** — enables multi-tenancy with no schema migration:
```python
# Every incident record includes:
{
    "incident_id": "...",
    "org_id": "default",  # In v2: actual org UUID
    ...
}
```

---

## 11. CI/CD Pipeline Design

```yaml
# pr-checks.yml — runs on every PR
jobs:
  lint:
    - pylint lambdas/ shared/ --fail-under=8.0
    - black --check lambdas/ shared/
    - mypy lambdas/ shared/ --ignore-missing-imports

  test:
    - pytest lambdas/ shared/ -v --tb=short
    - All tests use moto mocks — zero real AWS calls
    - Coverage report uploaded to Actions summary

  terraform:
    - terraform fmt -check
    - terraform validate
    - terraform plan → posted as PR comment

# deploy.yml — runs on merge to main
jobs:
  infra:
    - terraform apply (staging workspace)

  lambdas:
    - For each Lambda (normalizer, analyzer, config-api):
      pip install -t dist/ -r requirements.txt
      zip -r function.zip dist/ handler.py
      aws lambda update-function-code --zip-file function.zip

  ui:
    - docker build ui/ --tag $ECR_URL:$SHA
    - docker push $ECR_URL:$SHA
    - aws ecs update-service --force-new-deployment

  prod-gate:
    - environment: production
    - required-reviewers: [eldardje]
    - Runs same 3 jobs against prod workspace after approval
```

---

## 12. LangChain + Claude Integration

### Why LangChain Over Raw Claude API

| | Raw Claude API | LangChain + Claude |
|---|---|---|
| Output parsing | Brittle string/regex parsing | Pydantic type validation — schema violations raise exceptions |
| Prompt management | Strings scattered in code | PromptTemplate objects — versioned, testable |
| Retry logic | Manual implementation | Built-in with configurable backoff |
| Testing | Must mock HTTP calls | Mock the chain with a fixture |
| Model swapping | Find/replace model string | Change one constructor argument |
| Token tracking | Parse response headers manually | Callback handler pattern |
| Chaining | Manual pass-through code | LCEL pipe operator: `prompt | llm | parser` |

### Token Usage Tracking

Every AI call logs to CloudWatch via the callback handler:
```json
{
  "incident_id": "a3f8c2d1...",
  "model": "claude-sonnet-4-20250514",
  "prompt_tokens": 2847,
  "completion_tokens": 412,
  "total_tokens": 3259,
  "latency_ms": 3421,
  "chain_step": "analysis"
}
```

This enables cost tracking per incident over time.

---

## 13. n8n Incident Router Workflow

**Import file:** `n8n/workflows/incident-router.json`

| Node | Type | Configuration |
|---|---|---|
| Webhook Trigger | Webhook | POST, receives SNS payload |
| Extract incident_id | Set | Parse incident_id from SNS Message JSON |
| Invoke Analyzer | HTTP Request | POST to Analyzer Lambda URL, timeout 60s |
| Parse Analysis | Set | Extract requires_immediate_action, severity, title, summary, fix_suggestions[0] |
| Route by Severity | IF | `requires_immediate_action == true` |
| Slack — Urgent | Slack | Block Kit card, #incidents channel, red severity bar |
| Email — Urgent | SES | HTML template, on-call address from config |
| Email — Standard | SES | HTML template, team digest address |
| Update Status | HTTP Request | PATCH /incidents/:id status → 'notified' |
| Error Handler | Slack | Alert to #alerts-meta on any node failure |

**Slack Block Kit message structure:**
```json
{
  "blocks": [
    {
      "type": "header",
      "text": { "type": "plain_text", "text": "🔴 CRITICAL INCIDENT" }
    },
    {
      "type": "section",
      "text": { "type": "mrkdwn", "text": "*High CPU — web-prod*\n2:14 AM MST · CloudWatch · us-east-1" }
    },
    {
      "type": "section",
      "fields": [
        { "type": "mrkdwn", "text": "*Summary*\n The web-prod ECS cluster is experiencing sustained CPU saturation..." },
        { "type": "mrkdwn", "text": "*Root Cause*\nProbable N+1 query pattern..." }
      ]
    },
    {
      "type": "actions",
      "elements": [
        { "type": "button", "text": { "type": "plain_text", "text": "View Incident →" }, "url": "https://app.incidentagent.com/incidents/a3f8c2d1" }
      ]
    }
  ]
}
```

---

## 14. Environment Strategy

| Environment | Trigger | ECS Scale | Notes |
|---|---|---|---|
| **dev** | Feature branch push | 0 tasks (manual only) | Local SAM for Lambda testing |
| **staging** | Merge to main | 0 overnight / 1 daytime | Scheduled scaling 8pm–8am |
| **prod** | Manual approval | 1 task minimum always | Deletion protection, circuit breaker |

**Self-hosting with `.env`:**
```bash
# For engineers who want to self-host without the UI
CONFIG_SOURCE=env

# Input sources
CLOUDWATCH_SNS_ARN=arn:aws:sns:us-east-1:123456789012:my-alarms
CLOUDWATCH_LOG_GROUPS=/aws/lambda/my-api,/aws/ecs/my-cluster

# Notification outputs
SLACK_ENABLED=true
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
EMAIL_ENABLED=true
EMAIL_RECIPIENTS=oncall@company.com,eng@company.com

# AI
ANTHROPIC_API_KEY=sk-ant-...
```

---

## 15. v2 SaaS Roadmap

These are the next features after v1 ships. Mention these in interviews to show product thinking.

| Feature | Description | Engineering approach |
|---|---|---|
| **Multi-tenant orgs** | Multiple teams, each with their own incidents and config | `org_id` already on all records — add orgs table, update middleware |
| **Audit log UI** | View all actions taken on incidents | Table exists and is being written to — just build the UI |
| **API keys** | Programmatic access for CI/CD integration | Add api_keys DynamoDB table, API key auth middleware |
| **Datadog input** | Accept alerts from Datadog webhooks | Add datadog normalizer function to `lambdas/normalizer/sources/` |
| **Grafana/Prometheus** | Accept Alertmanager webhooks | Same normalizer pattern |
| **Microsoft Teams** | Output to Teams channels | Add Teams node to n8n workflow |
| **Team Owner role** | Per-team config management | ROLES dict already has team_owner defined |
| **Viewer role** | Read-only access for stakeholders | ROLES dict already has viewer defined |
| **SLA tracking** | Track incidents against response SLA targets | Add sla_target to config, calculate breach risk in real time |
| **Runbook integration** | Link incidents to runbook pages | Add runbook_url field, display in incident detail |

---

## 16. Cost Breakdown

| Service | Staging | Prod | Notes |
|---|---|---|---|
| ECS Fargate (n8n + UI) | ~$3/mo | ~$8/mo | Staging scales to 0 overnight |
| Lambda (3 functions) | <$1/mo | ~$1/mo | Low invocation count |
| API Gateway | <$1/mo | ~$1/mo | $1/million requests |
| DynamoDB (3 tables) | <$1/mo | ~$1/mo | Pay-per-request |
| Secrets Manager | ~$1/mo | ~$1/mo | $0.40/secret/month |
| SES (email) | <$1/mo | <$1/mo | $0.10/1,000 emails |
| CloudWatch (logs) | <$1/mo | ~$1/mo | |
| **Total** | **~$7/mo** | **~$13/mo** | |

Combined with Career Platform: **~$46/month total** — within the $50 budget.

---

## 17. Resume Bullets

```
Built a configurable full-stack AI incident response platform on AWS (Lambda,
API Gateway, ECS, DynamoDB, Secrets Manager, CloudWatch) with a Next.js setup
UI and incident dashboard — ingesting CloudWatch alarms, analyzing logs using
a two-stage LangChain chain with Claude (claude-sonnet-4-20250514) to generate
plain-English incident summaries, root cause analysis, and prioritized remediation
steps, then routing notifications via n8n to Slack and email based on AI-assessed
severity.

Designed the platform for multi-tenant SaaS extensibility from day one — every
DynamoDB record includes an org_id field, a shared roles.py defines all four planned
roles (admin, engineer, team owner, viewer), and an audit logging function writes
to a live DynamoDB table with the UI deferred to v2 — enabling SaaS expansion
without a schema migration.

Implemented end-to-end CI/CD with GitHub Actions — Pylint enforcement (min score
8.0), Pytest with moto AWS mocks (zero real API calls in CI), Terraform plan on
every PR, and automated Lambda + ECS deployments on merge with a manual approval
gate for production.
```
