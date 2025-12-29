# Error Handling Guide - PostgreSQL to Snowflake Dynamic Ingestion

## Overview

The PostgreSQL to Snowflake Dynamic Ingestion pipeline now includes **comprehensive error handling** to ensure reliability, traceability, and quick recovery from failures.

## Error Handling Features

### ✅ What's Included

1. **Error Logging Table** - Centralized tracking of all pipeline executions and errors
2. **Success/Failure Transitions** - Separate handling paths for successful and failed runs
3. **Email Notifications** - Automatic alerts for both success and failure scenarios
4. **Execution Tracking** - Each run is logged with timestamps and execution details
5. **Continue on Failure** - Pipeline doesn't stop if one table fails (configurable)

## Architecture

```
Start
  ↓
Create Error Log Table (if not exists)
  ↓
Table Iterator (loops 100 tables)
  ├── SUCCESS → Pipeline Success Summary → Send Success Notification
  └── FAILURE → Log Pipeline Failure → Send Failure Notification
```

## Components

### 1. Create Error Log Table

**Purpose**: Creates a permanent error logging table to track all pipeline executions

**Table**: `PIPELINE_ERROR_LOG` (configurable via variable)

**Schema**:
```sql
CREATE TABLE IF NOT EXISTS PIPELINE_ERROR_LOG (
  ERROR_ID NUMBER(38,0) IDENTITY(1,1) PRIMARY KEY,
  PIPELINE_NAME VARCHAR(500),
  TABLE_NAME VARCHAR(255),
  ERROR_MESSAGE VARCHAR(16777216),
  ERROR_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  EXECUTION_ID VARCHAR(255)
);
```

**Location**: `${target_database}.${target_schema}.${error_log_table}`

### 2. Log Pipeline Failure

**Trigger**: When iterator fails (any table fails and breakOnFailure is true, or critical error occurs)

**Action**: Inserts failure record into error log table

**SQL**:
```sql
INSERT INTO PIPELINE_ERROR_LOG
(PIPELINE_NAME, TABLE_NAME, ERROR_MESSAGE, EXECUTION_ID)
SELECT 
  'PostgreSQL to Snowflake - Dynamic Ingestion',
  'PIPELINE_FAILURE',
  'Pipeline failed during table iteration',
  TO_VARCHAR(CURRENT_TIMESTAMP);
```

### 3. Send Failure Notification

**Trigger**: After logging pipeline failure

**Action**: Sends email alert to configured recipients

**Email Details**:
- **Subject**: `[ALERT] PostgreSQL to Snowflake Pipeline Failed`
- **Content**: Error details and instructions to check log table
- **Recipients**: Configured in `error_notification_email` variable

### 4. Pipeline Success Summary

**Trigger**: When all tables complete successfully

**Action**: Inserts success record into error log table

**SQL**:
```sql
INSERT INTO PIPELINE_ERROR_LOG
(PIPELINE_NAME, TABLE_NAME, ERROR_MESSAGE, EXECUTION_ID)
SELECT 
  'PostgreSQL to Snowflake - Dynamic Ingestion',
  'PIPELINE_SUCCESS',
  'Pipeline completed successfully',
  TO_VARCHAR(CURRENT_TIMESTAMP);
```

### 5. Send Success Notification

**Trigger**: After logging successful completion

**Action**: Sends success confirmation email

**Email Details**:
- **Subject**: `[SUCCESS] PostgreSQL to Snowflake Pipeline Completed`
- **Content**: Success confirmation and summary
- **Recipients**: Configured in `error_notification_email` variable

## Configuration

### Required Variables

| Variable | Type | Description | Default | Required |
|----------|------|-------------|---------|----------|
| `error_notification_email` | TEXT | Email address for notifications | `` | ✅ Yes |
| `error_log_table` | TEXT | Name of error logging table | `PIPELINE_ERROR_LOG` | No |

### Email Configuration

**Components to Configure**:
1. Send Failure Notification
2. Send Success Notification

**Required SMTP Settings** (for both components):

| Setting | Example | Description |
|---------|---------|-------------|
| `toRecipients` | `admin@company.com` | Recipient email address(es) |
| `senderAddress` | `etl-alerts@company.com` | From email address |
| `smtpUsername` | `smtp_user` | SMTP server username |
| `smtpPassword` | `smtp_password_secret` | Secret reference for SMTP password |
| `smtpHostname` | `smtp.gmail.com` | SMTP server hostname |
| `smtpPort` | `587` | SMTP port (usually 587 or 465) |
| `enableSslTls` | `No` | Enable SSL/TLS |
| `enableStartTls` | `Yes` | Enable StartTLS |

**Common SMTP Configurations**:

#### Gmail
```yaml
smtpHostname: smtp.gmail.com
smtpPort: 587
enableSslTls: No
enableStartTls: Yes
```

#### Outlook/Office 365
```yaml
smtpHostname: smtp.office365.com
smtpPort: 587
enableSslTls: No
enableStartTls: Yes
```

#### SendGrid
```yaml
smtpHostname: smtp.sendgrid.net
smtpPort: 587
enableSslTls: No
enableStartTls: Yes
```

## Error Log Table Queries

### View All Errors

```sql
SELECT 
  ERROR_ID,
  PIPELINE_NAME,
  TABLE_NAME,
  ERROR_MESSAGE,
  ERROR_TIMESTAMP
FROM PIPELINE_ERROR_LOG
WHERE TABLE_NAME = 'PIPELINE_FAILURE'
ORDER BY ERROR_TIMESTAMP DESC;
```

### View Today's Execution

```sql
SELECT 
  ERROR_ID,
  TABLE_NAME,
  ERROR_MESSAGE,
  ERROR_TIMESTAMP
FROM PIPELINE_ERROR_LOG
WHERE DATE(ERROR_TIMESTAMP) = CURRENT_DATE()
ORDER BY ERROR_TIMESTAMP DESC;
```

### Check Success/Failure Ratio

```sql
SELECT 
  CASE 
    WHEN TABLE_NAME = 'PIPELINE_SUCCESS' THEN 'Success'
    WHEN TABLE_NAME = 'PIPELINE_FAILURE' THEN 'Failure'
    ELSE 'Other'
  END AS STATUS,
  COUNT(*) AS COUNT,
  MIN(ERROR_TIMESTAMP) AS FIRST_OCCURRENCE,
  MAX(ERROR_TIMESTAMP) AS LAST_OCCURRENCE
FROM PIPELINE_ERROR_LOG
WHERE DATE(ERROR_TIMESTAMP) >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY STATUS
ORDER BY STATUS;
```

### Pipeline Execution History (Last 30 Days)

```sql
SELECT 
  DATE(ERROR_TIMESTAMP) AS EXECUTION_DATE,
  CASE 
    WHEN TABLE_NAME = 'PIPELINE_SUCCESS' THEN 'SUCCESS'
    WHEN TABLE_NAME = 'PIPELINE_FAILURE' THEN 'FAILURE'
  END AS STATUS,
  ERROR_TIMESTAMP,
  ERROR_MESSAGE
FROM PIPELINE_ERROR_LOG
WHERE TABLE_NAME IN ('PIPELINE_SUCCESS', 'PIPELINE_FAILURE')
  AND DATE(ERROR_TIMESTAMP) >= DATEADD(day, -30, CURRENT_DATE())
ORDER BY ERROR_TIMESTAMP DESC;
```

## Error Scenarios

### Scenario 1: Single Table Fails

**Current Behavior**: `breakOnFailure = No`

- Pipeline continues processing remaining tables
- Failed table is skipped
- Success notification sent (partial success)
- Individual table failure not logged in current implementation

**To Track Individual Failures**: Add per-table error logging (future enhancement)

### Scenario 2: Critical Pipeline Failure

**Examples**:
- PostgreSQL connection lost
- Snowflake warehouse suspended
- Network timeout

**Behavior**:
- Iterator fails
- Failure transition triggered
- Error logged to table
- Failure notification sent

### Scenario 3: All Tables Succeed

**Behavior**:
- Iterator completes successfully
- Success transition triggered
- Success logged to table
- Success notification sent

## Best Practices

### 1. Set Up Monitoring Dashboard

Create a Snowflake view for easy monitoring:

```sql
CREATE OR REPLACE VIEW PIPELINE_MONITORING AS
SELECT 
  DATE(ERROR_TIMESTAMP) AS RUN_DATE,
  COUNT(DISTINCT ERROR_TIMESTAMP) AS TOTAL_RUNS,
  SUM(CASE WHEN TABLE_NAME = 'PIPELINE_SUCCESS' THEN 1 ELSE 0 END) AS SUCCESSFUL_RUNS,
  SUM(CASE WHEN TABLE_NAME = 'PIPELINE_FAILURE' THEN 1 ELSE 0 END) AS FAILED_RUNS,
  ROUND(SUM(CASE WHEN TABLE_NAME = 'PIPELINE_SUCCESS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS SUCCESS_RATE
FROM PIPELINE_ERROR_LOG
WHERE TABLE_NAME IN ('PIPELINE_SUCCESS', 'PIPELINE_FAILURE')
GROUP BY DATE(ERROR_TIMESTAMP)
ORDER BY RUN_DATE DESC;
```

### 2. Configure Email Rules

- **Failure emails**: High priority, immediate action required
- **Success emails**: Optional, can be filtered to digest
- Consider using different recipients for different alert types

### 3. Regular Table Maintenance

**Archive old logs**:
```sql
-- Archive logs older than 90 days
CREATE TABLE PIPELINE_ERROR_LOG_ARCHIVE AS
SELECT * FROM PIPELINE_ERROR_LOG
WHERE ERROR_TIMESTAMP < DATEADD(day, -90, CURRENT_DATE());

-- Delete archived logs
DELETE FROM PIPELINE_ERROR_LOG
WHERE ERROR_TIMESTAMP < DATEADD(day, -90, CURRENT_DATE());
```

### 4. Test Error Handling

**Test failure scenario**:
1. Temporarily add a non-existent table to `tables_to_load`
2. Run pipeline
3. Verify failure notification received
4. Check error log table for failure record
5. Remove test table and re-run

## Troubleshooting

### Email Notifications Not Sending

**Check**:
1. SMTP credentials are correct
2. SMTP hostname and port are correct
3. Firewall allows outbound SMTP traffic
4. Secret reference for password is valid
5. Sender email is authorized

**Test SMTP**:
- Run Send Failure/Success Notification component standalone
- Check component execution logs for SMTP errors

### Error Log Table Not Created

**Check**:
1. `target_database` and `target_schema` variables are set
2. Snowflake user has CREATE TABLE permission
3. Database and schema exist

**Manual Creation**:
```sql
CREATE TABLE IF NOT EXISTS YOUR_DB.YOUR_SCHEMA.PIPELINE_ERROR_LOG (
  ERROR_ID NUMBER(38,0) AUTOINCREMENT PRIMARY KEY,
  PIPELINE_NAME VARCHAR(500),
  TABLE_NAME VARCHAR(255),
  ERROR_MESSAGE VARCHAR(16777216),
  ERROR_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  EXECUTION_ID VARCHAR(255)
);
```

### Errors Not Logged

**Check**:
1. Insert permissions on error log table
2. SQL syntax in Log components
3. Component execution logs

## Future Enhancements

### Planned Features

1. **Per-Table Error Logging**
   - Track which specific tables failed
   - Log row counts and execution time per table
   - Add retry logic for failed tables

2. **Slack/Teams Integration**
   - Alternative to email notifications
   - Real-time alerts to team channels

3. **Advanced Metrics**
   - Track data volume loaded
   - Monitor pipeline performance trends
   - Alert on anomalies

4. **Automatic Retry**
   - Retry failed tables automatically
   - Exponential backoff strategy
   - Max retry limit

## Summary

### Error Handling Capabilities

✅ **Logging**: Centralized error log table tracks all executions  
✅ **Notifications**: Email alerts for both success and failure  
✅ **Traceability**: Timestamps and execution IDs for audit trail  
✅ **Resilience**: Continue on failure mode (configurable)  
✅ **Monitoring**: SQL queries for operational insights  

### Configuration Checklist

- [ ] Set `error_notification_email` variable
- [ ] Configure SMTP settings in both notification components
- [ ] Test failure notification
- [ ] Test success notification
- [ ] Verify error log table created
- [ ] Set up monitoring queries/dashboard

---

**Version**: 1.0  
**Last Updated**: 2025-12-25  
**Pipeline**: PostgreSQL to Snowflake - Dynamic Ingestion  
**Error Handling**: Comprehensive (Logging + Notifications)
