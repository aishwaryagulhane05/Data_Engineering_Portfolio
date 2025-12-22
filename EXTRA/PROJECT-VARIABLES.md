# Project-Level Variables Reference

**Project**: Campaign Data Mart - Silver Layer Orchestration  
**Architecture**: Medallion (RAW → Bronze → Silver → Gold)  
**Last Updated**: 2025-12-22  
**Purpose**: Centralized documentation of variables used across all Silver layer pipelines for environment configuration and operational flexibility

---

## Overview

This document describes the variable strategy for the Silver layer pipelines in the Campaign Data Mart project. Variables enable environment-specific configuration (DEV/TEST/PROD) and operational flexibility without code changes.

### Variable Philosophy
- **Scope**: `SHARED` - Variables persist across branch executions and can be updated dynamically
- **Visibility**: `PUBLIC` - Variables can be overridden by parent orchestration pipelines
- **Environment Strategy**: Same defaults across environments, override at project or runtime level for environment-specific values

---

## Variable Inventory

### Infrastructure Variables (All Pipelines)

#### 1. `bronze_database`
- **Type**: TEXT
- **Default**: `MATILLION_DB`
- **Scope**: SHARED
- **Visibility**: PUBLIC
- **Purpose**: Specifies the Snowflake database containing Bronze layer tables
- **Used In**: All 6 transformation pipelines (Campaigns, Customers, Channels, Performance, Products, Sales)
- **Override Scenarios**:
  - **DEV**: `MATILLION_DB` (default)
  - **TEST**: `MATILLION_TEST_DB`
  - **PROD**: `MATILLION_PROD_DB`
- **Example Usage**: `FROM ${bronze_database}.${bronze_schema}.MTLN_BRONZE_CAMPAIGNS`

#### 2. `bronze_schema`
- **Type**: TEXT
- **Default**: `BRONZE`
- **Scope**: SHARED
- **Visibility**: PUBLIC
- **Purpose**: Schema name for Bronze layer tables within the database
- **Used In**: All 6 transformation pipelines
- **Override Scenarios**:
  - Typically consistent across environments (`BRONZE`)
  - Could be `BRONZE_V2` for parallel version testing
- **Example Usage**: `FROM ${bronze_database}.${bronze_schema}.MTLN_BRONZE_CAMPAIGNS`

#### 3. `silver_database`
- **Type**: TEXT
- **Default**: `MATILLION_DB`
- **Scope**: SHARED
- **Visibility**: PUBLIC
- **Purpose**: Specifies the Snowflake database for Silver layer tables (output target)
- **Used In**: All 6 transformation pipelines
- **Override Scenarios**:
  - **DEV**: `MATILLION_DB` (default)
  - **TEST**: `MATILLION_TEST_DB`
  - **PROD**: `MATILLION_PROD_DB`
- **Example Usage**: `FROM ${silver_database}.${silver_schema}.MTLN_SILVER_CAMPAIGNS`

#### 4. `silver_schema`
- **Type**: TEXT
- **Default**: `SILVER`
- **Scope**: SHARED
- **Visibility**: PUBLIC
- **Purpose**: Schema name for Silver layer tables within the database
- **Used In**: All 6 transformation pipelines
- **Override Scenarios**:
  - Typically consistent across environments (`SILVER`)
  - Could be `SILVER_V2` for parallel version testing
- **Example Usage**: `INSERT INTO ${silver_database}.${silver_schema}.MTLN_SILVER_CAMPAIGNS`

#### 5. `warehouse_name`
- **Type**: TEXT
- **Default**: `MATILLION_WH`
- **Scope**: SHARED
- **Visibility**: PUBLIC
- **Purpose**: Snowflake compute warehouse for executing Silver layer transformations
- **Used In**: Master orchestration pipeline (`Master - Orchestrate Silver Layer.orch.yaml`)
- **Override Scenarios**:
  - **DEV**: `MATILLION_WH` (MEDIUM, auto-suspend 300s)
  - **TEST**: `MATILLION_TEST_WH` (MEDIUM)
  - **PROD**: `MATILLION_ETL_WH` (LARGE, optimized for production loads)
- **Note**: Currently defined but not actively used in pipelines (uses `[Environment Default]`)

### Operational Variables (Transformation Pipelines Only)

#### 6. `watermark_default`
- **Type**: TEXT (Timestamp string)
- **Default**: `1900-01-01`
- **Scope**: SHARED
- **Visibility**: PUBLIC
- **Purpose**: Default watermark timestamp for first-time incremental loads when target Silver table is empty
- **Used In**: All 6 transformation pipelines (in SQL watermark logic)
- **Override Scenarios**:
  - **Initial Load**: `1900-01-01` (loads all Bronze records)
  - **Historical Replay**: `2025-01-01` (reload from specific date)
  - **Partial Reload**: `2025-12-01` (reload only December onwards)
- **Example Usage**:
  ```sql
  WHERE "LOAD_TIMESTAMP" > (
      SELECT COALESCE(MAX("LOAD_TIMESTAMP"), '${watermark_default}'::TIMESTAMP)
      FROM ${silver_database}.${silver_schema}.MTLN_SILVER_CAMPAIGNS
  )
  ```
- **Behavior**:
  - If Silver table is **empty**: Uses `watermark_default` → full load from Bronze
  - If Silver table has **data**: Uses `MAX(LOAD_TIMESTAMP)` → incremental load only

---

## Pipeline Usage Patterns

### Master Orchestration Pipeline
**File**: `Master - Orchestrate Silver Layer.orch.yaml`

**Variables Defined**:
- `bronze_database`
- `bronze_schema`
- `silver_database`
- `silver_schema`
- `warehouse_name`

**Variable Passing**: Currently NOT passing variables to child pipelines (child pipelines use their own defaults)

**Components**:
- 6x `run-transformation` components (Campaigns, Customers, Channels, Performance, Products, Sales)
- 1x `and` logic component (waits for all to complete)

### Transformation Pipelines (6 Total)
**Files**:
1. `Bronze to Silver - Campaigns.tran.yaml`
2. `Bronze to Silver - Customers.tran.yaml`
3. `Bronze to Silver - Channels.tran.yaml`
4. `Bronze to Silver - Performance.tran.yaml`
5. `Bronze to Silver - Products.tran.yaml`
6. `Bronze to Silver - Sales.tran.yaml`

**Variables Defined** (all 6 pipelines):
- `bronze_database`
- `bronze_schema`
- `silver_database`
- `silver_schema`
- `watermark_default`

**Variable Usage Locations**:
1. **SQL Component** (`Incremental Load with Watermark`):
   - Source table reference: `${bronze_database}.${bronze_schema}.MTLN_BRONZE_*`
   - Watermark query: `${silver_database}.${silver_schema}.MTLN_SILVER_*`
   - Default watermark: `'${watermark_default}'::TIMESTAMP`

2. **Table Output Component** (`Write to Silver`):
   - Uses `[Environment Default]` for database/schema (not variables)
   - Writes to hardcoded schema: `SILVER`

---

## Variable Resolution & Precedence

### Resolution Order (Highest to Lowest Priority)
1. **Runtime Override**: Variables passed via `setScalarVariables` in `run-transformation` component
2. **Project-Level Variables**: Defined at project level in Matillion UI (not currently used)
3. **Pipeline-Level Variables**: Defined in each `.yaml` file's `variables` section (CURRENT approach)
4. **Component-Level Defaults**: Hardcoded in component parameters

### Current State
- ✅ **Pipeline-level variables** are defined in all 7 files
- ❌ **Project-level variables** are NOT configured in Matillion
- ❌ **Runtime overrides** are NOT implemented in Master orchestration

### Consistency Model
**Current**: Each pipeline maintains its own variable definitions with identical defaults
- ✅ **Pros**: Self-contained, no dependencies, works independently
- ❌ **Cons**: Duplication (35+ variable definitions), risk of inconsistency, harder to manage environment promotion

---

## Environment Override Strategies

### Strategy 1: Pipeline-Level Overrides (Current)
**How**: Edit default values in each `.yaml` file's `variables` section

**Steps**:
1. Open each transformation pipeline (6 files)
2. Update `defaultValue` for environment-specific variables
3. Commit changes to environment-specific branch (e.g., `main` for DEV, `production` for PROD)

**Example**:
```yaml
variables:
  bronze_database:
    metadata:
      type: "TEXT"
      description: "Bronze layer database name"
      scope: "SHARED"
      visibility: "PUBLIC"
    defaultValue: "MATILLION_PROD_DB"  # Changed from MATILLION_DB
```

**Pros**: Simple, no additional configuration  
**Cons**: Must update 7 files, risk of missed updates

---

### Strategy 2: Runtime Overrides (Recommended)
**How**: Pass variables from Master orchestration to child transformation pipelines

**Steps**:
1. Define project-level variables in Matillion (Project → Variables)
2. Update Master orchestration to pass variables using `setScalarVariables`
3. Keep pipeline-level defaults as fallback

**Example** (Master orchestration update):
```yaml
Run Campaigns:
  type: "run-transformation"
  parameters:
    componentName: "Run Campaigns"
    transformationJob: "Bronze to Silver - Campaigns.tran.yaml"
    setScalarVariables:
      - - "bronze_database"
        - "${bronze_database}"  # Pass from parent
      - - "bronze_schema"
        - "${bronze_schema}"
      - - "silver_database"
        - "${silver_database}"
      - - "silver_schema"
        - "${silver_schema}"
      - - "watermark_default"
        - "${watermark_default}"
```

**Pros**: Single source of truth, update once in Master  
**Cons**: Requires Master orchestration changes (one-time)

---

### Strategy 3: Project-Level Variables (Future State)
**How**: Configure variables in Matillion UI at project level

**Steps**:
1. Navigate to: Project Settings → Variables
2. Create variables with environment-specific values:
   - `bronze_database` = `MATILLION_DB` (DEV) or `MATILLION_PROD_DB` (PROD)
   - `bronze_schema` = `BRONZE`
   - `silver_database` = `MATILLION_DB` (DEV) or `MATILLION_PROD_DB` (PROD)
   - `silver_schema` = `SILVER`
   - `watermark_default` = `1900-01-01`
3. Reference in pipelines: `${bronze_database}` (automatically resolves project-level first)

**Pros**: True single source of truth, UI-managed, no code changes  
**Cons**: Requires Matillion UI configuration (per environment)

---

## Testing & Validation

### Variable Override Testing

#### Test 1: Pipeline-Level Default
1. Run transformation pipeline directly (e.g., `Bronze to Silver - Campaigns.tran.yaml`)
2. Verify uses default: `MATILLION_DB.BRONZE`
3. **Expected**: Loads from Bronze using default database/schema

#### Test 2: Runtime Override (After Implementing Strategy 2)
1. Update Master orchestration with `setScalarVariables`
2. Change Master's `bronze_database` variable to `TEST_DB`
3. Run Master pipeline
4. **Expected**: All child transformations use `TEST_DB.BRONZE`

#### Test 3: Watermark Override
1. Set `watermark_default` to `2025-12-01`
2. Run transformation pipeline on empty Silver table
3. Check row count: Should only load Bronze records after 2025-12-01
4. **Expected**: Partial historical load

### Validation Queries

**Check Variable Usage**:
```sql
-- Verify Silver table loaded from correct Bronze source
SELECT 
    'MTLN_SILVER_CAMPAIGNS' AS table_name,
    COUNT(*) AS row_count,
    MIN(load_timestamp) AS earliest_load,
    MAX(load_timestamp) AS latest_load
FROM MATILLION_DB.SILVER.MTLN_SILVER_CAMPAIGNS;
```

**Check Watermark Logic**:
```sql
-- Verify watermark is working (should show max timestamp)
SELECT MAX(load_timestamp) AS current_watermark
FROM MATILLION_DB.SILVER.MTLN_SILVER_CAMPAIGNS;
```

---

## Common Issues & Troubleshooting

### Issue 1: Variable Not Resolving
**Symptom**: Pipeline fails with error like `Object 'BRONZE' does not exist`

**Causes**:
- Variable name typo in SQL: `${bronz_database}` instead of `${bronze_database}`
- Variable not defined at any level (pipeline/project/runtime)
- Variable visibility set to `PRIVATE` (can't be overridden)

**Solution**:
1. Check variable spelling in SQL component
2. Verify variable exists in pipeline `variables` section
3. Confirm `visibility: "PUBLIC"` for variables that need overriding

---

### Issue 2: Incremental Load Not Working (Full Load Every Time)
**Symptom**: Pipeline loads all Bronze records even after initial load

**Causes**:
- Watermark query returning NULL (Silver table doesn't exist)
- `LOAD_TIMESTAMP` column not populated in Silver
- Watermark comparison logic incorrect

**Solution**:
1. Verify Silver table exists: `SHOW TABLES LIKE 'MTLN_SILVER_%' IN SILVER;`
2. Check `LOAD_TIMESTAMP` populated: `SELECT MAX(load_timestamp) FROM SILVER.MTLN_SILVER_CAMPAIGNS;`
3. Review watermark SQL logic in transformation pipeline

---

### Issue 3: Inconsistent Variables Across Pipelines
**Symptom**: Some pipelines use different database/schema than others

**Causes**:
- Variables manually edited in multiple files
- Copy/paste errors during pipeline creation
- Forgot to update all 6 transformation pipelines

**Solution**:
1. Run consistency check (see below)
2. Implement Strategy 2 (Runtime Overrides) to prevent future inconsistency

**Consistency Check Script**:
```bash
# Search all .yaml files for variable defaults
grep -A 5 "bronze_database:" *.yaml
grep -A 5 "bronze_schema:" *.yaml
grep -A 5 "silver_database:" *.yaml
grep -A 5 "silver_schema:" *.yaml
```

---

## Migration Path: Current → Centralized Variables

### Phase 1: Document Current State ✅ (This Document)
- Inventory all variables across pipelines
- Document usage patterns
- Identify inconsistencies

### Phase 2: Implement Runtime Overrides (Recommended Next Step)
**Estimated Time**: 1 hour

1. **Update Master Orchestration** (30 min):
   - Add `setScalarVariables` to all 6 `run-transformation` components
   - Pass 5 variables from Master to each child pipeline

2. **Test in DEV** (20 min):
   - Sample one transformation (e.g., Campaigns) before/after
   - Override one variable in Master, verify cascade to child
   - Run full Master pipeline, verify all 6 transformations work

3. **Document Changes** (10 min):
   - Update this document with new "Runtime Override" section
   - Add examples to Master orchestration notes

### Phase 3: Create Project-Level Variables (Optional Future)
**Estimated Time**: 30 minutes

1. **Configure in Matillion UI**:
   - Project Settings → Variables
   - Create 5 variables with defaults

2. **Verify Resolution**:
   - Test project-level variable overrides pipeline-level defaults
   - Document precedence order

---

## Environment Configuration Examples

### DEV Environment (Current Default)
```yaml
variables:
  bronze_database: "MATILLION_DB"
  bronze_schema: "BRONZE"
  silver_database: "MATILLION_DB"
  silver_schema: "SILVER"
  warehouse_name: "MATILLION_WH"
  watermark_default: "1900-01-01"
```

### TEST Environment
```yaml
variables:
  bronze_database: "MATILLION_TEST_DB"
  bronze_schema: "BRONZE"
  silver_database: "MATILLION_TEST_DB"
  silver_schema: "SILVER"
  warehouse_name: "MATILLION_TEST_WH"
  watermark_default: "1900-01-01"
```

### PROD Environment
```yaml
variables:
  bronze_database: "MATILLION_PROD_DB"
  bronze_schema: "BRONZE"
  silver_database: "MATILLION_PROD_DB"
  silver_schema: "SILVER"
  warehouse_name: "MATILLION_ETL_WH"
  watermark_default: "1900-01-01"
```

---

## Best Practices

### Variable Naming
✅ **Do**:
- Use descriptive names: `bronze_database` not `db1`
- Use consistent casing: `snake_case` for variables
- Include layer name: `bronze_schema`, `silver_schema` (not just `schema`)

❌ **Don't**:
- Use generic names: `database`, `table`, `value`
- Mix naming conventions: `bronzeDatabase` vs `bronze_schema`
- Include environment in name: `dev_database` (use default values instead)

### Variable Scope & Visibility
✅ **Do**:
- Use `SHARED` scope for configuration variables (persist across runs)
- Use `PUBLIC` visibility for variables that parent pipelines should override
- Use `COPIED` scope for variables used in concurrent/iterator components

❌ **Don't**:
- Use `PRIVATE` visibility for infrastructure variables (can't be overridden)
- Use `SHARED` scope for loop counters/temporary values

### Documentation
✅ **Do**:
- Add meaningful descriptions to all variables
- Document override scenarios in descriptions
- Include examples in pipeline notes

❌ **Don't**:
- Leave descriptions empty
- Use generic descriptions: "database name"

---

## Related Documentation

- **Architecture**: See `ARCHITECTURE.md` for Medallion layer overview
- **Deployment**: See `deployment-guide.md` for environment-specific setup
- **Data Dictionary**: See `data-dictionary.md` for table schemas
- **Incremental Loading**: See `SILVER-LAYER.md` for watermark logic details

---

## Changelog

### 2025-12-22 - Initial Documentation
- Documented current variable strategy (pipeline-level definitions)
- Created inventory of 6 variables across 7 pipelines
- Added environment override strategies
- Included testing procedures and troubleshooting
- Outlined migration path to centralized variables

### Next Review: After Runtime Override Implementation
- Update with actual `setScalarVariables` examples
- Add test results from DEV environment
- Document any issues encountered during migration

---

**Document Owner**: Data Engineering Team  
**Maintained By**: Maia (Matillion AI Assistant)  
**Review Frequency**: After each major pipeline change or environment promotion