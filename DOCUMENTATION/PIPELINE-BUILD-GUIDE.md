# Pipeline Build Guide
# Marketing Analytics Data Warehouse - Bronze → Silver Transformations

**Status:** Ready to Build  
**Date:** 2025-12-21  
**Prerequisites:** Sample data loaded in Bronze tables

---

## Overview

You've successfully tested with sample data! Now let's build **transformation pipelines** to move data from Bronze → Silver with:

✅ **Data cleansing** - Handle NULLs, trim whitespace, standardize values  
✅ **Data quality** - Validate business rules  
✅ **Surrogate keys** - Add technical keys for relationships  
✅ **Audit columns** - Track when data was processed  
✅ **Deduplication** - Ensure no duplicate records

---

## What We'll Build

### Phase 1: Simple Full Refresh Pipeline (START HERE)
**File:** `Bronze to Silver - Campaigns.tran.yaml`

**Flow:**
```
Load Bronze → Cleanse Data → Add Metadata → Write to Silver
```

**Components:**
1. [Table Input](https://docs.matillion.com/data-productivity-cloud/designer/docs/table-input) - Read from mtln_bronze_campaigns
2. [Calculator](https://docs.matillion.com/data-productivity-cloud/designer/docs/calculator) - Cleanse NULL values, trim data
3. [Calculator](https://docs.matillion.com/data-productivity-cloud/designer/docs/calculator) - Add derived columns
4. [Rewrite Table](https://docs.matillion.com/data-productivity-cloud/designer/docs/rewrite-table) - Write to mtln_silver_campaigns

**Duration:** 20 minutes  
**Complexity:** Beginner  
**Test with:** Your 1,000 campaign records

---

## Step-by-Step: Build Your First Pipeline

### Step 1: Create Silver Table (SQL)

First, create the target Silver table in Snowflake:

```sql
USE DATABASE MATILLION_DB;
USE SCHEMA DEV;

CREATE OR REPLACE TABLE mtln_silver_campaigns (
    campaign_id               VARCHAR(100) NOT NULL,
    campaign_name             VARCHAR(255) NOT NULL,
    campaign_type             VARCHAR(100) NOT NULL,
    start_date                DATE NOT NULL,
    end_date                  DATE NOT NULL,
    budget                    NUMBER(18,2) DEFAULT 0.00,
    status                    VARCHAR(50) DEFAULT 'Unknown',
    objective                 VARCHAR(255),
    duration_days             NUMBER(10,0),
    last_modified_timestamp   TIMESTAMP_NTZ NOT NULL,
    load_timestamp            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system             VARCHAR(50) NOT NULL,
    
    CONSTRAINT pk_silver_campaigns PRIMARY KEY (campaign_id)
);

SELECT 'Silver table created' AS status;
```

**Run this in Snowflake now!**

---

### Step 2: Open Matillion & Create Pipeline

1. **Open Matillion Data Productivity Cloud**
2. **Navigate to your project**
3. **Click "Pipelines"** in left menu
4. **Click "+ New Pipeline"**
5. **Select "Transformation Pipeline"**
6. **Name it:** `Bronze to Silver - Campaigns`
7. **Click "Create"**

---

### Step 3: Add Table Input Component

1. **Drag "Table Input"** from component palette onto canvas
2. **Click the component** to configure
3. **Set parameters:**
   - **Component Name:** `Load Bronze Campaigns`
   - **Database:** Select `MATILLION_DB`
   - **Schema:** Select `DEV`
   - **Target Table:** Select `mtln_bronze_campaigns`
   - **Column Names:** Select ALL columns
4. **Click "Save"**

---

### Step 4: Add Calculator for Cleansing

1. **Drag "Calculator"** onto canvas (to the right of Table Input)
2. **Connect** Table Input → Calculator (click and drag from Table Input output port)
3. **Click Calculator** to configure
4. **Set parameters:**
   - **Component Name:** `Cleanse Data`
   - **Include Input Columns:** `Yes`
   - **Calculations:** Add these one by one:

```
Calculation 1:
Expression: COALESCE("campaign_name", 'Unknown Campaign')
Output Name: campaign_name_clean

Calculation 2:
Expression: COALESCE("campaign_type", 'Unknown')
Output Name: campaign_type_clean

Calculation 3:
Expression: COALESCE("budget", 0.00)
Output Name: budget_clean

Calculation 4:
Expression: COALESCE("status", 'Unknown')
Output Name: status_clean

Calculation 5:
Expression: UPPER(TRIM("campaign_id"))
Output Name: campaign_id_clean
```

5. **Click "Save"**

---

### Step 5: Add Calculator for Metadata

1. **Drag another "Calculator"** onto canvas
2. **Connect** Cleanse Data → Add Metadata
3. **Click to configure:**
   - **Component Name:** `Add Metadata`
   - **Include Input Columns:** `Yes`
   - **Calculations:**

```
Calculation 1:
Expression: CURRENT_TIMESTAMP()
Output Name: silver_load_timestamp

Calculation 2:
Expression: DATEDIFF('day', "start_date", "end_date") + 1
Output Name: campaign_duration_days
```

4. **Click "Save"**

---

### Step 6: Add Rewrite Table Output

1. **Drag "Rewrite Table"** onto canvas
2. **Connect** Add Metadata → Rewrite Table
3. **Click to configure:**
   - **Component Name:** `Write to Silver`
   - **Database:** `MATILLION_DB`
   - **Schema:** `DEV`
   - **Target Table:** `mtln_silver_campaigns`
   - **Column Mapping:** Map cleansed columns to target:

```
Source Column → Target Column
────────────────────────────────
campaign_id_clean → campaign_id
campaign_name_clean → campaign_name
campaign_type_clean → campaign_type
start_date → start_date
end_date → end_date
budget_clean → budget
status_clean → status
objective → objective
campaign_duration_days → duration_days
last_modified_timestamp → last_modified_timestamp
silver_load_timestamp → load_timestamp
source_system → source_system
```

4. **Click "Save"**

---

### Step 7: Test the Pipeline

1. **Click "Sample"** button (eye icon) on any component
2. **Review the data** - should show 10 sample rows
3. **Verify calculations** - Check that NULL values are handled
4. **Click "Run"** button (play icon) to execute full pipeline
5. **Wait ~30 seconds** for completion

---

### Step 8: Validate Results

**Run in Snowflake:**

```sql
USE DATABASE MATILLION_DB;
USE SCHEMA DEV;

-- Check row count
SELECT COUNT(*) FROM mtln_silver_campaigns;
-- Should return: 1000

-- Compare Bronze vs Silver counts
SELECT 
    'Bronze' AS layer,
    COUNT(*) AS row_count
FROM mtln_bronze_campaigns
UNION ALL
SELECT 
    'Silver',
    COUNT(*)
FROM mtln_silver_campaigns;
-- Both should be 1000

-- Verify data cleansing worked
SELECT 
    campaign_id,
    campaign_name,
    budget,
    duration_days,
    load_timestamp
FROM mtln_silver_campaigns
LIMIT 10;

-- Check for NULLs in required fields (should return 0)
SELECT COUNT(*) 
FROM mtln_silver_campaigns
WHERE campaign_id IS NULL 
   OR campaign_name IS NULL 
   OR campaign_type IS NULL;
```

**Expected Results:**
- ✅ 1,000 rows in Silver
- ✅ No NULL values in required fields
- ✅ `duration_days` calculated correctly
- ✅ `load_timestamp` populated
- ✅ Budget defaults to 0.00 if NULL

---

## 🎉 Success! You've Built Your First Pipeline!

You now have:
- ✅ Working transformation pipeline
- ✅ Data cleansing logic
- ✅ Derived calculations
- ✅ Clean Silver layer data

---

## Next Steps

### Option A: Build More Simple Pipelines

**Replicate the same pattern for:**
1. **Customers** - Bronze → Silver
2. **Products** - Bronze → Silver  
3. **Channels** - Bronze → Silver

**Each takes ~15 minutes** once you know the pattern!

### Option B: Build Advanced Pipeline with Surrogate Keys

**Create:**
- Bronze → Silver with **Snowflake SEQUENCE** for surrogate keys
- Includes **MERGE logic** for incremental updates
- Handles **slowly changing dimensions**

### Option C: Build Fact Table Pipeline

**Transform Sales or Performance:**
- Lookup surrogate keys from dimension tables
- Calculate derived metrics
- Handle high volume (100K+ rows)

---

## Tips for Building More Pipelines

### Component Palette

**Essential Transformation Components:**

| Component | Use For |
|-----------|--------|
| [Table Input](https://docs.matillion.com/data-productivity-cloud/designer/docs/table-input) | Read from source tables |
| [Calculator](https://docs.matillion.com/data-productivity-cloud/designer/docs/calculator) | Add calculated columns, cleanse data |
| [Filter](https://docs.matillion.com/data-productivity-cloud/designer/docs/filter) | Remove unwanted rows |
| [Join](https://docs.matillion.com/data-productivity-cloud/designer/docs/join) | Combine tables |
| [Aggregate](https://docs.matillion.com/data-productivity-cloud/designer/docs/aggregate) | Group and summarize data |
| [Rank](https://docs.matillion.com/data-productivity-cloud/designer/docs/rank) | Deduplicate or rank rows |
| [Rewrite Table](https://docs.matillion.com/data-productivity-cloud/designer/docs/rewrite-table) | Full refresh output |
| [Table Update](https://docs.matillion.com/data-productivity-cloud/designer/docs/table-update) | Merge/upsert output |

### Testing Strategy

1. **Sample Early, Sample Often** - Use the Sample button on each component
2. **Build Incrementally** - Add one component at a time, test, then add next
3. **Validate Immediately** - Check Silver table after each run
4. **Keep It Simple** - Don't over-engineer on first iteration

### Common Patterns

**NULL Handling:**
```sql
COALESCE("column_name", 'default_value')
```

**Trim Whitespace:**
```sql
TRIM("column_name")
```

**Standardize Case:**
```sql
UPPER("column_name")  -- or LOWER()
```

**Date Calculations:**
```sql
DATEDIFF('day', "start_date", "end_date")
```

**Current Timestamp:**
```sql
CURRENT_TIMESTAMP()
```

---

## Troubleshooting

### Pipeline Won't Validate

**Check:**
- Database/schema selections correct?
- Table exists in target schema?
- Column names spelled correctly? (case-sensitive!)
- All required parameters filled in?

### Sample Shows No Data

**Check:**
- Source table has data? (Run SELECT COUNT(*) in Snowflake)
- Filters removing all rows?
- Join conditions correct?

### Pipeline Runs But No Data in Target

**Check:**
- Run completed successfully? (No errors in log)
- Correct target table selected?
- Column mappings correct?

---

## Summary: What You're Building

### Current State
```
[Bronze Tables] ← Sample data loaded (161K records)
```

### After This Guide
```
[Bronze Tables] → [Transformation Pipeline] → [Silver Tables]
                      ↓
             Data Cleansing
             NULL Handling
             Calculations
             Metadata
```

### End Goal
```
[Bronze] → [Silver with SKs] → [Gold Views] → [Analytics]
   ↓            ↓                    ↓             ↓
 Raw Data   Clean Data         Star Schema   Insights
```

---

## Quick Reference

**Key Snowflake Commands:**

```sql
-- Check if table exists
SHOW TABLES LIKE 'mtln_silver_%';

-- View table structure
DESC TABLE mtln_silver_campaigns;

-- Sample data
SELECT * FROM mtln_silver_campaigns LIMIT 10;

-- Row count
SELECT COUNT(*) FROM mtln_silver_campaigns;

-- Drop and recreate if needed
DROP TABLE IF EXISTS mtln_silver_campaigns;
```

**Matillion Shortcuts:**
- **Ctrl+S**: Save pipeline
- **Ctrl+Enter**: Run pipeline
- **Sample button** (eye icon): Preview data
- **Run button** (play icon): Execute pipeline

---

**Ready to build your first pipeline?**

**Start with Step 1: Create the Silver table in Snowflake!**

---

**Document Version:** 1.0  
**Last Updated:** 2025-12-21  
**Status:** ✅ Ready to Use

*For help, refer to [Matillion Documentation](https://docs.matillion.com/data-productivity-cloud/)*