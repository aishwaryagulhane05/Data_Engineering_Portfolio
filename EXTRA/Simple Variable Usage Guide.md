# Simple Variable Usage Guide - Bronze to Silver

**Quick Start**: How to use variables in the Master Orchestration pipeline

---

## ✅ What We Did

Added **5 shared variables** to `Master - Orchestrate Silver Layer.orch.yaml`:

1. `bronze_database` = MATILLION_DB
2. `bronze_schema` = BRONZE
3. `silver_database` = MATILLION_DB
4. `silver_schema` = SILVER
5. `warehouse_name` = MATILLION_WH

---

## 📊 How It Works

```
Master Orchestration Pipeline
├── Variables (5 shared variables defined here)
│   ├── bronze_database = MATILLION_DB
│   ├── bronze_schema = BRONZE
│   ├── silver_database = MATILLION_DB
│   ├── silver_schema = SILVER
│   └── warehouse_name = MATILLION_WH
│
├── Runs 6 Transformation Pipelines (in parallel)
│   ├── Bronze to Silver - Campaigns
│   ├── Bronze to Silver - Customers
│   ├── Bronze to Silver - Channels
│   ├── Bronze to Silver - Performance
│   ├── Bronze to Silver - Products
│   └── Bronze to Silver - Sales
│       └── (Sales has its own variables too!)
│
└── All transformations can access these variables
```

---

## 🎯 Why This Is Simple

### Before (Without Variables)
```sql
-- Hardcoded in each pipeline
FROM MATILLION_DB.BRONZE.MTLN_BRONZE_SALES
WHERE ...
INSERT INTO MATILLION_DB.SILVER.MTLN_SILVER_SALES
```
**Problem**: To change environments, you must edit 6 pipelines!

### After (With Variables)
```sql
-- Uses variables
FROM ${bronze_database}.${bronze_schema}.MTLN_BRONZE_SALES
WHERE ...
INSERT INTO ${silver_database}.${silver_schema}.MTLN_SILVER_SALES
```
**Solution**: Change 5 variables in ONE place (Master pipeline)!

---

## 🔧 How to Use Variables

### Step 1: View Variables in Master Pipeline

1. Open `Master - Orchestrate Silver Layer.orch.yaml`
2. Look at the **Variables** tab (top of pipeline)
3. You'll see 5 variables with their default values

### Step 2: Keep Defaults for DEV

**DEV Environment** - Use as-is:
- bronze_database = MATILLION_DB
- bronze_schema = BRONZE
- silver_database = MATILLION_DB
- silver_schema = SILVER
- warehouse_name = MATILLION_WH

### Step 3: Change for PROD

**PROD Environment** - Edit the defaults:
- bronze_database = MATILLION_PROD_DB  ← Change here
- bronze_schema = BRONZE
- silver_database = MATILLION_PROD_DB  ← Change here
- silver_schema = SILVER
- warehouse_name = PROD_WH  ← Change here

**That's it!** All 6 transformations now use PROD databases.

---

## 📝 Real Example

### Sales Transformation Pipeline SQL

**Original (Hardcoded)**:
```sql
FROM MATILLION_DB.BRONZE.MTLN_BRONZE_SALES
WHERE "LOAD_TIMESTAMP" > (
    SELECT COALESCE(MAX("LOAD_TIMESTAMP"), '1900-01-01'::TIMESTAMP)
    FROM MATILLION_DB.SILVER.MTLN_SILVER_SALES
)
```

**Updated (With Variables)**:
```sql
FROM ${bronze_database}.${bronze_schema}.MTLN_BRONZE_SALES
WHERE "LOAD_TIMESTAMP" > (
    SELECT COALESCE(MAX("LOAD_TIMESTAMP"), '${watermark_default}'::TIMESTAMP)
    FROM ${silver_database}.${silver_schema}.MTLN_SILVER_SALES
)
```

**How It Works**:
- `${bronze_database}` gets replaced with "MATILLION_DB"
- `${bronze_schema}` gets replaced with "BRONZE"
- `${silver_database}` gets replaced with "MATILLION_DB"
- `${silver_schema}` gets replaced with "SILVER"

---

## 🌍 Environment Examples

### DEV Environment
```yaml
variables:
  bronze_database: MATILLION_DEV_DB
  silver_database: MATILLION_DEV_DB
  warehouse_name: DEV_WH
```
SQL becomes:
```sql
FROM MATILLION_DEV_DB.BRONZE.MTLN_BRONZE_SALES
```

### QA Environment
```yaml
variables:
  bronze_database: MATILLION_QA_DB
  silver_database: MATILLION_QA_DB
  warehouse_name: QA_WH
```
SQL becomes:
```sql
FROM MATILLION_QA_DB.BRONZE.MTLN_BRONZE_SALES
```

### PROD Environment
```yaml
variables:
  bronze_database: MATILLION_PROD_DB
  silver_database: MATILLION_PROD_DB
  warehouse_name: PROD_WH
```
SQL becomes:
```sql
FROM MATILLION_PROD_DB.BRONZE.MTLN_BRONZE_SALES
```

---

## ✨ Key Benefits

1. **Single Source of Truth** - Change variables in ONE place
2. **Easy Environment Promotion** - DEV → QA → PROD without code changes
3. **No SQL Editing** - Just change variable values
4. **Less Error-Prone** - Can't forget to update one pipeline
5. **Clear Documentation** - Variables show what can be configured

---

## 🚀 Quick Start Checklist

### For Current Environment (DEV)
- ✅ Variables already set with defaults
- ✅ Master pipeline ready to use
- ✅ Sales transformation uses variables
- ✅ No changes needed!

### For New Environment (PROD)
1. ☐ Open Master - Orchestrate Silver Layer
2. ☐ Go to Variables tab
3. ☐ Change bronze_database to MATILLION_PROD_DB
4. ☐ Change silver_database to MATILLION_PROD_DB
5. ☐ Change warehouse_name to PROD_WH
6. ☐ Run pipeline - it uses PROD databases!

---

## 💡 Common Questions

### Q: Do I need to change variables in each transformation?
**A**: No! Variables in Master pipeline are inherited by all transformations.

### Q: What if I want different values for one specific pipeline?
**A**: You can override variables when calling that specific transformation. (Advanced - see full guide)

### Q: Can I see what values are being used?
**A**: Yes! In the Variables tab, you see the current defaults. During execution, Matillion replaces `${variable}` with the actual value.

### Q: What happens if I don't set a variable?
**A**: It uses the default value you defined when creating the variable.

---

## 📚 Where Variables Are Used

### In Master Orchestration
- **Defined**: 5 shared variables (database, schema, warehouse)
- **Used**: Automatically passed to all child transformations

### In Sales Transformation
- **Defined**: 7 variables (includes validation rules)
- **Used**: In SQL queries to reference databases/schemas

### In Other Transformations (Future)
- **Can Add**: Same pattern to Campaigns, Customers, etc.
- **Benefit**: All use centralized configuration

---

## 🎯 Summary

**What Changed**:
- Added 5 variables to Master orchestration
- Updated Sales transformation to use variables
- Deleted confusing override example

**What You Get**:
- ✅ Easy environment switching (DEV/QA/PROD)
- ✅ Single place to configure databases
- ✅ No SQL editing needed
- ✅ Clear, maintainable pipelines

**Next Step**:
- Use the Master pipeline as-is for DEV
- When ready for PROD, just change 3 variable values!

---

**For More Details**: See `Variables - Configuration Guide.md` (comprehensive guide)

**Current Implementation**:
- Master orchestration: 5 shared variables ✅
- Sales transformation: 7 specific variables ✅
- Other transformations: Can add same pattern

---

*Simple, practical, production-ready!*