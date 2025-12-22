# Deployment Guide
# Marketing Analytics Data Warehouse - Production Deployment

**Project:** Multi-Source Marketing & Sales Analytics Platform  
**Platform:** Matillion + Snowflake  
**Version:** 1.0  
**Date:** 2025-12-21  
**Estimated Time:** 3 hours

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Phase 1: Snowflake Setup](#phase-1-snowflake-setup-45-min)
4. [Phase 2: Git Configuration](#phase-2-git-configuration-30-min)
5. [Phase 3: Matillion Setup](#phase-3-matillion-setup-30-min)
6. [Phase 4: Database Objects](#phase-4-create-database-objects-10-min)
7. [Phase 5: Initial Data Load](#phase-5-initial-data-load-15-min)
8. [Phase 6: Validation](#phase-6-validation-30-min)
9. [Phase 7: Scheduling](#phase-7-scheduling-15-min)
10. [Rollback Plan](#rollback-plan)
11. [Post-Deployment](#post-deployment)

---

## 1. Overview

### 1.1 Deployment Summary

**What We're Deploying:**
- 31 database objects (6 stages + 6 sequences + 6 bronze + 6 ODS + 7 gold)
- 3 Matillion pipelines (1 orchestration + 2 transformations)
- Monitoring and alerting configuration
- Scheduled daily execution

**Timeline:**

| Phase | Duration | Critical? |
|-------|----------|----------|
| 1. Snowflake Setup | 45 min | Yes |
| 2. Git Configuration | 30 min | Yes |
| 3. Matillion Setup | 30 min | Yes |
| 4. Create Database Objects | 10 min | Yes |
| 5. Initial Data Load | 15 min | Yes |
| 6. Validation | 30 min | Yes |
| 7. Scheduling | 15 min | Yes |
| **Total** | **3 hours** | |

**Risk Level:** 🟢 LOW  
- Comprehensive testing completed in DEV
- Rollback plan ready
- No impact on existing systems

---

## 2. Prerequisites

### 2.1 Access Requirements

☑️ **Snowflake:**
- ACCOUNTADMIN role (or SECURITYADMIN + SYSADMIN)
- Ability to create databases, schemas, warehouses
- Ability to create roles and grant privileges

☑️ **Matillion:**
- Admin access to Matillion Data Productivity Cloud
- Ability to create projects and manage Git connections

☑️ **Git:**
- Repository admin access (GitHub/GitLab/Bitbucket)
- Ability to create Personal Access Tokens (PATs)
- Write access to main/master branch

☑️ **Source Data:**
- Parquet files ready for upload
- Access to upload files to Snowflake stages

### 2.2 Pre-Deployment Checklist

- [ ] Snowflake account credentials verified
- [ ] Matillion project created
- [ ] Git repository access confirmed
- [ ] Source data files validated
- [ ] Deployment window scheduled (low-traffic period)
- [ ] Stakeholders notified
- [ ] Backup/rollback plan reviewed
- [ ] Team availability confirmed (2-3 people recommended)

### 2.3 Required Information

Gather these before starting:

**Snowflake:**
- Account URL: `https://<account>.snowflakecomputing.com`
- Account name: `_________________`
- Region: `_________________`
- Admin username: `_________________`
- Admin password: `_________________` (secure)

**Git:**
- Repository URL: `_________________`
- Personal Access Token: `_________________` (secure)
- Branch name: `main` or `master`

**Email:**
- Alert recipients: `_________________`

---

## Phase 1: Snowflake Setup (45 min)

### Step 1.1: Create Databases (5 min)

```sql
-- Connect as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Create databases
CREATE DATABASE IF NOT EXISTS MTLN_PROD
    COMMENT = 'Marketing Analytics Data Warehouse - Production';

CREATE DATABASE IF NOT EXISTS MTLN_DEV
    COMMENT = 'Marketing Analytics Data Warehouse - Development';

-- Verify
SHOW DATABASES LIKE 'MTLN%';
```

**Expected Output:** 2 databases created

---

### Step 1.2: Create Schemas (5 min)

```sql
-- Production schemas
USE DATABASE MTLN_PROD;

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Internal stages for Parquet file landing';

CREATE SCHEMA IF NOT EXISTS BRONZE
    DATA_RETENTION_TIME_IN_DAYS = 14
    COMMENT = 'Raw relational tables (as-is from source)';

CREATE SCHEMA IF NOT EXISTS SILVER
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Clean operational data store (ODS)';

CREATE SCHEMA IF NOT EXISTS GOLD
    COMMENT = 'Analytics-ready star schema (views)';

-- Verify
SHOW SCHEMAS IN DATABASE MTLN_PROD;
```

**Expected Output:** 4 schemas in MTLN_PROD

---

### Step 1.3: Create Warehouses (10 min)

```sql
-- ETL Warehouse (for data loading/transformation)
CREATE WAREHOUSE IF NOT EXISTS MTLN_ETL_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Matillion ETL/ELT pipelines';

-- Reporting Warehouse (for BI tools & analysts)
CREATE WAREHOUSE IF NOT EXISTS MTLN_REPORTING_WH
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'Warehouse for business user queries and BI tools';

-- Verify
SHOW WAREHOUSES LIKE 'MTLN%';
```

**Sizing Rationale:**
- **ETL:** MEDIUM (sufficient for 15-min daily load)
- **Reporting:** LARGE + auto-scaling (handles 50+ concurrent users)

---

### Step 1.4: Create Roles (10 min)

```sql
-- Role hierarchy:
-- ACCOUNTADMIN (Snowflake default)
--   └─ MTLN_ADMIN
--       ├─ MTLN_DEV_ROLE
--       ├─ MTLN_ETL_ROLE
--       └─ MTLN_REPORTING_ROLE

-- Admin role
CREATE ROLE IF NOT EXISTS MTLN_ADMIN
    COMMENT = 'Admin role for marketing analytics DW';

GRANT ROLE MTLN_ADMIN TO ROLE ACCOUNTADMIN;

-- Development role
CREATE ROLE IF NOT EXISTS MTLN_DEV_ROLE
    COMMENT = 'Development role - full access to DEV database';

GRANT ROLE MTLN_DEV_ROLE TO ROLE MTLN_ADMIN;

-- ETL role (for Matillion)
CREATE ROLE IF NOT EXISTS MTLN_ETL_ROLE
    COMMENT = 'ETL role for Matillion pipelines';

GRANT ROLE MTLN_ETL_ROLE TO ROLE MTLN_ADMIN;

-- Reporting role (for business users)
CREATE ROLE IF NOT EXISTS MTLN_REPORTING_ROLE
    COMMENT = 'Read-only role for business users and BI tools';

GRANT ROLE MTLN_REPORTING_ROLE TO ROLE MTLN_ADMIN;

-- Verify
SHOW ROLES LIKE 'MTLN%';
```

---

### Step 1.5: Grant Privileges (15 min)

```sql
-- ====================
-- MTLN_ADMIN (Full Control)
-- ====================
USE ROLE ACCOUNTADMIN;

GRANT USAGE ON DATABASE MTLN_PROD TO ROLE MTLN_ADMIN;
GRANT USAGE ON DATABASE MTLN_DEV TO ROLE MTLN_ADMIN;
GRANT ALL ON SCHEMA MTLN_PROD.RAW TO ROLE MTLN_ADMIN;
GRANT ALL ON SCHEMA MTLN_PROD.BRONZE TO ROLE MTLN_ADMIN;
GRANT ALL ON SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_ADMIN;
GRANT ALL ON SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_ADMIN;
GRANT ALL ON ALL TABLES IN SCHEMA MTLN_PROD.BRONZE TO ROLE MTLN_ADMIN;
GRANT ALL ON ALL TABLES IN SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_ADMIN;
GRANT ALL ON ALL VIEWS IN SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_ADMIN;
GRANT ALL ON FUTURE TABLES IN SCHEMA MTLN_PROD.BRONZE TO ROLE MTLN_ADMIN;
GRANT ALL ON FUTURE TABLES IN SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_ADMIN;
GRANT ALL ON FUTURE VIEWS IN SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_ADMIN;
GRANT USAGE ON WAREHOUSE MTLN_ETL_WH TO ROLE MTLN_ADMIN;
GRANT USAGE ON WAREHOUSE MTLN_REPORTING_WH TO ROLE MTLN_ADMIN;

-- ====================
-- MTLN_ETL_ROLE (Matillion)
-- ====================
GRANT USAGE ON DATABASE MTLN_PROD TO ROLE MTLN_ETL_ROLE;
GRANT USAGE ON SCHEMA MTLN_PROD.RAW TO ROLE MTLN_ETL_ROLE;
GRANT USAGE ON SCHEMA MTLN_PROD.BRONZE TO ROLE MTLN_ETL_ROLE;
GRANT USAGE ON SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_ETL_ROLE;
GRANT USAGE ON SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_ETL_ROLE;

-- Write access to RAW/BRONZE/SILVER
GRANT CREATE STAGE ON SCHEMA MTLN_PROD.RAW TO ROLE MTLN_ETL_ROLE;
GRANT CREATE TABLE ON SCHEMA MTLN_PROD.BRONZE TO ROLE MTLN_ETL_ROLE;
GRANT CREATE TABLE ON SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_ETL_ROLE;
GRANT CREATE SEQUENCE ON SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_ETL_ROLE;
GRANT CREATE VIEW ON SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_ETL_ROLE;

-- Future grants
GRANT ALL ON FUTURE STAGES IN SCHEMA MTLN_PROD.RAW TO ROLE MTLN_ETL_ROLE;
GRANT ALL ON FUTURE TABLES IN SCHEMA MTLN_PROD.BRONZE TO ROLE MTLN_ETL_ROLE;
GRANT ALL ON FUTURE TABLES IN SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_ETL_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_ETL_ROLE;

-- Warehouse access
GRANT USAGE ON WAREHOUSE MTLN_ETL_WH TO ROLE MTLN_ETL_ROLE;
GRANT OPERATE ON WAREHOUSE MTLN_ETL_WH TO ROLE MTLN_ETL_ROLE;

-- ====================
-- MTLN_REPORTING_ROLE (Business Users)
-- ====================
GRANT USAGE ON DATABASE MTLN_PROD TO ROLE MTLN_REPORTING_ROLE;
GRANT USAGE ON SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_REPORTING_ROLE;
GRANT USAGE ON SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_REPORTING_ROLE;

-- Read-only access
GRANT SELECT ON ALL VIEWS IN SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_REPORTING_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_REPORTING_ROLE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA MTLN_PROD.GOLD TO ROLE MTLN_REPORTING_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA MTLN_PROD.SILVER TO ROLE MTLN_REPORTING_ROLE;

-- Warehouse access
GRANT USAGE ON WAREHOUSE MTLN_REPORTING_WH TO ROLE MTLN_REPORTING_ROLE;
```

**Checkpoint:** ✅ Snowflake environment ready

---

## Phase 2: Git Configuration (30 min)

### Step 2.1: Create Git Repository (10 min)

1. Go to GitHub/GitLab/Bitbucket
2. Create new repository: `marketing-analytics-dw`
3. Initialize with README
4. Set default branch: `main`

### Step 2.2: Generate Personal Access Token (10 min)

**GitHub:**
1. Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Name: `Matillion Marketing Analytics DW`
4. Scopes: ☑️ `repo` (full control)
5. Generate token
6. 🔒 **Copy and save securely** (won't be shown again)

**GitLab:**
1. User Settings → Access Tokens
2. Name: `Matillion Marketing Analytics DW`
3. Scopes: ☑️ `write_repository`
4. Create token
5. 🔒 **Copy and save securely**

### Step 2.3: Configure Branch Protection (10 min)

**GitHub:**
1. Repository → Settings → Branches
2. Add rule for `main` branch
3. Enable:
   - ☑️ Require pull request before merging
   - ☑️ Require approvals (1 minimum)
   - ☑️ Dismiss stale reviews
4. Save changes

**Checkpoint:** ✅ Git repository ready

---

## Phase 3: Matillion Setup (30 min)

### Step 3.1: Create Snowflake Connection (10 min)

1. Log in to Matillion Data Productivity Cloud
2. Navigate to **Connections**
3. Click **+ New Connection**
4. Select **Snowflake**

**Connection Details:**
- **Name:** `Snowflake_Prod_Marketing_Analytics`
- **Account:** `<your-account>` (without `.snowflakecomputing.com`)
- **Warehouse:** `MTLN_ETL_WH`
- **Database:** `MTLN_PROD`
- **Schema:** `SILVER` (default)
- **Role:** `MTLN_ETL_ROLE`
- **Authentication:** Username/Password
- **Username:** `<matillion-service-account>`
- **Password:** `<secure-password>`

5. Click **Test Connection**
6. If successful, click **Save**

### Step 3.2: Configure Git Integration (10 min)

1. In Matillion, navigate to **Project Settings**
2. Click **Git Integration**
3. Configure:
   - **Repository URL:** `https://github.com/<org>/marketing-analytics-dw.git`
   - **Branch:** `main`
   - **Authentication:** Personal Access Token
   - **Token:** `<paste-your-PAT>`
4. Click **Connect**
5. Enable:
   - ☑️ Auto-fetch on project open
   - ☑️ Auto-push on commit

### Step 3.3: Import Project Files (10 min)

1. Clone repository locally
2. Copy pipeline files to repository
3. Commit and push:

```bash
git add .
git commit -m "Initial commit: Marketing Analytics DW pipelines"
git push origin main
```

4. In Matillion, click **Pull from Git**
5. Verify pipelines imported successfully

**Checkpoint:** ✅ Matillion configured

---

## Phase 4: Create Database Objects (10 min)

### Step 4.1: Run DDL Pipeline

1. Open Matillion project
2. Navigate to pipelines
3. Open: `Create All Tables - Master DDL.orch.yaml`
4. Click **Run**

**Expected Duration:** 5 minutes

**Creates:**
- 6 Internal Stages (RAW schema)
- 6 Sequences (SILVER schema)
- 6 Bronze Tables (BRONZE schema)
- 6 Silver/ODS Tables (SILVER schema)
- 7 Gold Views (GOLD schema)

### Step 4.2: Verify Objects Created

```sql
USE ROLE MTLN_ADMIN;
USE DATABASE MTLN_PROD;

-- Check stages
SHOW STAGES IN SCHEMA RAW;
-- Expected: 6 stages

-- Check sequences
SHOW SEQUENCES IN SCHEMA SILVER;
-- Expected: 6 sequences

-- Check Bronze tables
SHOW TABLES IN SCHEMA BRONZE;
-- Expected: 6 tables

-- Check Silver tables
SHOW TABLES IN SCHEMA SILVER;
-- Expected: 6 tables

-- Check Gold views
SHOW VIEWS IN SCHEMA GOLD;
-- Expected: 7 views
```

**Checkpoint:** ✅ 31 objects created

---

## Phase 5: Initial Data Load (15 min)

### Step 5.1: Upload Source Files

```sql
-- Upload Parquet files to stages
USE ROLE MTLN_ETL_ROLE;
USE DATABASE MTLN_PROD;
USE SCHEMA RAW;

-- Upload via Snowflake UI or SnowSQL
PUT file:///path/to/campaigns_20251221.parquet @mtln_stage_campaigns;
PUT file:///path/to/customers_20251221.parquet @mtln_stage_customers;
PUT file:///path/to/products_20251221.parquet @mtln_stage_products;
PUT file:///path/to/sales_20251221.parquet @mtln_stage_sales;
PUT file:///path/to/performance_20251221.parquet @mtln_stage_performance;
PUT file:///path/to/channels_20251221.parquet @mtln_stage_channels;

-- Verify files uploaded
LIST @mtln_stage_campaigns;
-- Repeat for all stages
```

### Step 5.2: Run Master Pipeline

1. In Matillion, open: `Master Pipeline - RAW to Gold.orch.yaml`
2. Click **Run**

**Expected Duration:** 10 minutes

**Loads:**
- Bronze tables from RAW stages
- Silver/ODS tables from Bronze
- Gold views automatically reflect Silver data

**Checkpoint:** ✅ Data loaded

---

## Phase 6: Validation (30 min)

### Step 6.1: Row Count Validation (5 min)

```sql
USE ROLE MTLN_REPORTING_ROLE;
USE WAREHOUSE MTLN_REPORTING_WH;
USE DATABASE MTLN_PROD;

-- Check row counts
SELECT 'Bronze Campaigns' AS layer, COUNT(*) AS row_count FROM BRONZE.mtln_bronze_campaigns
UNION ALL
SELECT 'Silver Campaigns', COUNT(*) FROM SILVER.mtln_ods_campaigns
UNION ALL
SELECT 'Gold Dim Campaign', COUNT(*) FROM GOLD.mtln_dim_campaign
UNION ALL
SELECT 'Bronze Sales', COUNT(*) FROM BRONZE.mtln_bronze_sales
UNION ALL
SELECT 'Silver Sales', COUNT(*) FROM SILVER.mtln_ods_sales
UNION ALL
SELECT 'Gold Fact Sales', COUNT(*) FROM GOLD.mtln_fact_sales
ORDER BY layer;
```

**Expected:** Counts should match across layers

### Step 6.2: Data Quality Checks (10 min)

```sql
-- 1. Check for NULL primary keys (should return 0)
SELECT COUNT(*) AS null_pks
FROM SILVER.mtln_ods_campaigns
WHERE surrogate_key IS NULL OR campaign_id IS NULL;

-- 2. Check referential integrity (should return 0)
SELECT COUNT(*) AS orphan_sales
FROM GOLD.mtln_fact_sales f
LEFT JOIN GOLD.mtln_dim_customer c ON f.dim_customer_sk = c.dim_customer_sk
WHERE c.dim_customer_sk IS NULL;

-- 3. Check business rules (should return 0)
SELECT COUNT(*) AS invalid_metrics
FROM GOLD.mtln_fact_performance
WHERE clicks > impressions OR conversions > clicks;

-- 4. Check data freshness (should be < 24 hours)
SELECT 
    MAX(load_timestamp) AS last_load,
    DATEDIFF(hour, MAX(load_timestamp), CURRENT_TIMESTAMP()) AS hours_since_load
FROM SILVER.mtln_ods_sales;
```

**All checks must pass** before proceeding

### Step 6.3: Sample Analytical Queries (15 min)

```sql
-- Query 1: Top 10 campaigns by ROAS
SELECT 
    c.campaign_name,
    ch.channel_name,
    SUM(f.cost) AS total_cost,
    SUM(f.revenue) AS total_revenue,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.cost), 0), 2) AS roas
FROM GOLD.mtln_fact_performance f
JOIN GOLD.mtln_dim_campaign c ON f.dim_campaign_sk = c.dim_campaign_sk
JOIN GOLD.mtln_dim_channel ch ON f.dim_channel_sk = ch.dim_channel_sk
JOIN GOLD.mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(day, -90, CURRENT_DATE)
GROUP BY c.campaign_name, ch.channel_name
ORDER BY roas DESC
LIMIT 10;

-- Query 2: Customer segmentation summary
SELECT 
    customer_segment,
    customer_tier,
    COUNT(*) AS customer_count,
    AVG(customer_lifetime_value) AS avg_ltv
FROM GOLD.mtln_dim_customer
WHERE is_active_customer = TRUE
GROUP BY customer_segment, customer_tier
ORDER BY avg_ltv DESC;

-- Query 3: Daily sales trend
SELECT 
    d.full_date,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.revenue) AS total_revenue,
    ROUND(AVG(f.revenue), 2) AS avg_order_value
FROM GOLD.mtln_fact_sales f
JOIN GOLD.mtln_dim_date d ON f.dim_date_sk = d.date_key
WHERE d.full_date >= DATEADD(day, -30, CURRENT_DATE)
GROUP BY d.full_date
ORDER BY d.full_date DESC;
```

**Expected:** All queries return results in < 30 seconds

**Checkpoint:** ✅ Data validated

---

## Phase 7: Scheduling (15 min)

### Step 7.1: Configure Pipeline Schedule

1. In Matillion, open: `Master Pipeline - RAW to Gold.orch.yaml`
2. Click **Schedule**
3. Configure:
   - **Frequency:** Daily
   - **Time:** 02:00 (2:00 AM)
   - **Timezone:** Your local timezone
   - **Days:** Monday-Sunday
4. Save schedule

### Step 7.2: Set Up Alerts

1. Go to **Project Settings** → **Notifications**
2. Configure:
   - **On Success:** Email to `data-team@company.com`
   - **On Failure:** Email to `data-team@company.com` + Slack channel
   - **On Warning:** Email to `data-team@company.com`
3. Test notification

**Checkpoint:** ✅ Scheduling configured

---

## Rollback Plan

### If Deployment Fails

**Scenario 1: DDL Pipeline Fails**
```sql
-- Drop all objects and retry
USE ROLE MTLN_ADMIN;
USE DATABASE MTLN_PROD;

DROP SCHEMA IF EXISTS RAW CASCADE;
DROP SCHEMA IF EXISTS BRONZE CASCADE;
DROP SCHEMA IF EXISTS SILVER CASCADE;
DROP SCHEMA IF EXISTS GOLD CASCADE;

-- Re-run Phase 1, Step 1.2
```

**Scenario 2: Data Load Fails**
```sql
-- Truncate tables and retry
USE ROLE MTLN_ETL_ROLE;
TRUNCATE TABLE BRONZE.mtln_bronze_campaigns;
TRUNCATE TABLE BRONZE.mtln_bronze_customers;
-- Repeat for all Bronze tables

TRUNCATE TABLE SILVER.mtln_ods_campaigns;
TRUNCATE TABLE SILVER.mtln_ods_customers;
-- Repeat for all Silver tables

-- Reset sequences
ALTER SEQUENCE SILVER.mtln_ods_campaigns_seq SET VALUE = 1;
-- Repeat for all sequences

-- Re-run Phase 5
```

**Scenario 3: Complete Rollback**
```sql
-- Remove all project objects
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS MTLN_PROD CASCADE;
DROP WAREHOUSE IF EXISTS MTLN_ETL_WH;
DROP WAREHOUSE IF EXISTS MTLN_REPORTING_WH;
DROP ROLE IF EXISTS MTLN_ETL_ROLE;
DROP ROLE IF EXISTS MTLN_REPORTING_ROLE;
DROP ROLE IF EXISTS MTLN_DEV_ROLE;
DROP ROLE IF EXISTS MTLN_ADMIN;

-- Start over from Phase 1
```

---

## Post-Deployment

### Immediate (Day 1)

- ☑️ Verify first scheduled run completes successfully
- ☑️ Monitor pipeline execution time
- ☑️ Check alert notifications working
- ☑️ Grant user access to MTLN_REPORTING_ROLE

### Week 1

- ☑️ Conduct user training (2-hour session)
- ☑️ Share sample queries and documentation
- ☑️ Monitor query performance
- ☑️ Collect user feedback

### Month 1

- ☑️ Review pipeline success rate (target: 99%+)
- ☑️ Analyze query patterns and optimize
- ☑️ Measure adoption metrics
- ☑️ Plan enhancements

---

## Support Contacts

**Data Engineering Team:**
- Email: data-engineering@company.com
- Slack: #data-engineering
- On-call: [Phone number]

**Escalation:**
- Data Engineering Lead: [Name, email]
- Snowflake Support: [Account number]
- Matillion Support: [License key]

---

**Document Version:** 1.0  
**Last Updated:** 2025-12-21  
**Status:** ✅ Ready for Production Deployment

---

*Follow this guide step-by-step for successful deployment. Contact data engineering team if issues arise.*