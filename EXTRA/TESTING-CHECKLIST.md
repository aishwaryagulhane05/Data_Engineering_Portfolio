# Testing Checklist
# Marketing Analytics Data Warehouse - Sample Data Testing

**Date:** 2025-12-21  
**Duration:** 15 minutes  
**Tester:** ________________

---

## Pre-Test Setup

### Environment Check
- [ ] Snowflake account accessible
- [ ] MTLN_PROD database exists
- [ ] BRONZE schema exists
- [ ] MTLN_ETL_WH warehouse exists
- [ ] MTLN_REPORTING_WH warehouse exists (or use ETL for testing)
- [ ] Appropriate role assigned (MTLN_ADMIN or ACCOUNTADMIN)

### Files Ready
- [ ] `sql/create-bronze-tables.sql` downloaded/accessible
- [ ] `sql/generate-sample-data.sql` downloaded/accessible
- [ ] `sql/validate-sample-data.sql` downloaded/accessible
- [ ] `sql/sample-analytical-queries.sql` downloaded/accessible

---

## Step 1: Create Bronze Tables

### Execution
- [ ] Opened Snowflake Web UI
- [ ] Created new worksheet
- [ ] Pasted `sql/create-bronze-tables.sql`
- [ ] Executed script successfully

### Verification
- [ ] Saw "Table created" messages for all 6 tables
- [ ] Ran `SHOW TABLES IN SCHEMA BRONZE;`
- [ ] Confirmed 6 tables exist:
  - [ ] mtln_bronze_channels
  - [ ] mtln_bronze_campaigns
  - [ ] mtln_bronze_customers
  - [ ] mtln_bronze_products
  - [ ] mtln_bronze_sales
  - [ ] mtln_bronze_performance

**Time Taken:** ______ minutes  
**Issues:** _______________________________________________________

---

## Step 2: Generate Sample Data

### Execution
- [ ] Created new worksheet
- [ ] Pasted `sql/generate-sample-data.sql`
- [ ] Executed script
- [ ] Waited for completion (~5 min)

### Verification
- [ ] Saw "loaded" messages for each table
- [ ] Confirmed row counts:
  - [ ] Channels: 20
  - [ ] Campaigns: 1,000
  - [ ] Customers: 10,000
  - [ ] Products: 1,000
  - [ ] Sales: 100,000
  - [ ] Performance: 50,000
- [ ] Total records: 161,020

### Quick Check Query
```sql
SELECT COUNT(*) FROM mtln_bronze_channels;  -- Should return 20
SELECT COUNT(*) FROM mtln_bronze_campaigns; -- Should return 1000
SELECT COUNT(*) FROM mtln_bronze_sales;     -- Should return 100000
```

- [ ] All counts match expected values

**Time Taken:** ______ minutes  
**Issues:** _______________________________________________________

---

## Step 3: Validate Data Quality

### Execution
- [ ] Created new worksheet
- [ ] Pasted `sql/validate-sample-data.sql`
- [ ] Executed script

### Validation Results

#### Check 1: Row Counts
- [ ] All 6 tables show ✅ PASS
- [ ] Row counts match expected

#### Check 2: NULL Values
- [ ] Campaigns: No NULL campaign_id ✅ PASS
- [ ] Customers: No NULL customer_id ✅ PASS
- [ ] Products: No NULL product_id ✅ PASS
- [ ] Sales: No NULL order_line_id ✅ PASS
- [ ] Performance: No NULL performance_id ✅ PASS

#### Check 3: Duplicates
- [ ] Campaigns: No duplicates ✅ PASS
- [ ] Customers: No duplicates ✅ PASS
- [ ] Products: No duplicates ✅ PASS

#### Check 4: Referential Integrity
- [ ] Sales - customer_id: No orphans ✅ PASS
- [ ] Sales - product_id: No orphans ✅ PASS
- [ ] Sales - campaign_id: No orphans ✅ PASS
- [ ] Performance - campaign_id: No orphans ✅ PASS
- [ ] Performance - channel_id: No orphans ✅ PASS

#### Check 5: Business Rules
- [ ] Campaigns: No negative budget ✅ PASS
- [ ] Campaigns: Valid date ranges ✅ PASS
- [ ] Products: Positive prices ✅ PASS
- [ ] Products: Positive costs ✅ PASS
- [ ] Products: Non-negative margins ✅ PASS
- [ ] Sales: Positive quantity ✅ PASS
- [ ] Sales: Valid revenue calculation ✅ PASS
- [ ] Performance: Clicks ≤ Impressions ✅ PASS
- [ ] Performance: Conversions ≤ Clicks ✅ PASS
- [ ] Performance: Non-negative cost ✅ PASS
- [ ] Performance: Non-negative revenue ✅ PASS

#### Check 6: Data Distribution

**Campaign Status:**
- [ ] Active: ~40%
- [ ] Completed: ~50%
- [ ] Paused: ~5%
- [ ] Scheduled: ~5%

**Customer Tiers:**
- [ ] Platinum: ~5%
- [ ] Gold: ~15%
- [ ] Silver: ~30%
- [ ] Bronze: ~50%

**Customer Segments:**
- [ ] Enterprise: ~33%
- [ ] SMB: ~33%
- [ ] Consumer: ~34%

### Overall Validation Status
- [ ] **ALL CHECKS PASS** ✅
- [ ] Ready to proceed to analytical queries

**Time Taken:** ______ minutes  
**Issues:** _______________________________________________________

---

## Step 4: Run Analytical Queries

### Query 1: Top 10 Campaigns by ROAS
- [ ] Query executed successfully
- [ ] Returned 10 rows
- [ ] ROAS values between 1.5 and 6.0
- [ ] Execution time: ______ seconds (target: < 5s)

### Query 2: Customer Tier Analysis
- [ ] Query executed successfully
- [ ] Returned 12 rows (4 tiers × 3 segments)
- [ ] Platinum has highest avg_ltv
- [ ] Execution time: ______ seconds (target: < 2s)

### Query 3: Daily Sales Trend
- [ ] Query executed successfully
- [ ] Returned up to 30 days of data
- [ ] Daily revenue varies realistically
- [ ] Execution time: ______ seconds (target: < 3s)

### Query 4: Channel Performance
- [ ] Query executed successfully
- [ ] Returned ~20 channels
- [ ] ROAS values vary by channel
- [ ] Execution time: ______ seconds (target: < 3s)

### Additional Queries Tested
- [ ] Campaign budget vs actual: ______ seconds
- [ ] Product category analysis: ______ seconds
- [ ] Monthly sales summary: ______ seconds
- [ ] Executive dashboard: ______ seconds

### Query Performance Summary
- [ ] All queries returned results
- [ ] All queries completed in < 5 seconds
- [ ] Results are realistic and consistent
- [ ] No errors or warnings

**Time Taken:** ______ minutes  
**Issues:** _______________________________________________________

---

## Step 5: Review and Document

### Data Quality Assessment
- [ ] 161,020 records generated successfully
- [ ] All validation checks pass
- [ ] No data quality issues identified
- [ ] Foreign key relationships intact
- [ ] Business rules satisfied

### Query Performance Assessment
- [ ] Simple queries: < 3 seconds ✅
- [ ] Complex joins: < 5 seconds ✅
- [ ] All queries return results ✅
- [ ] Results meet business expectations ✅

### Realistic Data Assessment
- [ ] Campaign data looks realistic
- [ ] Customer distribution makes sense
- [ ] Product pricing is reasonable
- [ ] Sales patterns are believable
- [ ] Performance metrics are realistic
- [ ] Date ranges are appropriate

---

## Overall Test Results

### Success Criteria
- [ ] ✅ All tables created
- [ ] ✅ All data generated (161,020 records)
- [ ] ✅ All validations pass
- [ ] ✅ All queries execute successfully
- [ ] ✅ Performance meets targets

### Test Summary

**Status:** [ ] PASS  [ ] FAIL

**Total Time:** ______ minutes (target: 15 min)

**Key Findings:**
___________________________________________________________________
___________________________________________________________________
___________________________________________________________________

**Issues Encountered:**
___________________________________________________________________
___________________________________________________________________
___________________________________________________________________

**Recommendations:**
___________________________________________________________________
___________________________________________________________________
___________________________________________________________________

---

## Next Steps

### If Test PASSED:
- [ ] Document baseline performance metrics
- [ ] Proceed to build transformation pipelines
- [ ] Share results with stakeholders
- [ ] Use sample data for pipeline development

### If Test FAILED:
- [ ] Review error messages
- [ ] Check prerequisites
- [ ] Consult troubleshooting guide
- [ ] Contact data engineering team

---

## Sign-Off

**Tester Name:** ___________________________  
**Date Completed:** ___________________________  
**Time Taken:** ___________________________  
**Status:** [ ] PASS  [ ] FAIL  

**Approved By:** ___________________________  
**Date:** ___________________________

---

## Attachments

- [ ] Screenshots of successful execution
- [ ] Query performance metrics
- [ ] Sample query results
- [ ] Error logs (if any)

---

**Document Version:** 1.0  
**Last Updated:** 2025-12-21  
**Status:** Ready for Use

---

*Print this checklist and complete as you execute the testing steps.*