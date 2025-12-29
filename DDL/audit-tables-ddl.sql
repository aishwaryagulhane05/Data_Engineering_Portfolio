/*==============================================================================
  AUDIT TABLES DDL - Marketing Analytics Data Warehouse
  
  Purpose: Complete audit framework for data lineage, quality tracking, and
           validation across all medallion layers (Bronze, Silver, Gold)
  
  Schemas:
    - AUDIT: Central audit and quality tracking
    - BRONZE: Raw data ingestion audit
    - SILVER: Transformation audit
    - GOLD: Dimensional model audit
  
  Created: 2025-12-23
  Version: 1.0
  
  Usage:
    1. Run this script with SYSADMIN or appropriate role
    2. Verify all tables created successfully
    3. Run validation queries at the end
==============================================================================*/

-- Set context
USE ROLE SYSADMIN;
USE WAREHOUSE MATILLION_WH;
USE DATABASE MATILLION_DB;

/*==============================================================================
  SECTION 1: AUDIT SCHEMA - Central Quality Framework
==============================================================================*/

-- Create AUDIT schema if not exists
CREATE SCHEMA IF NOT EXISTS AUDIT
  COMMENT = 'Central audit schema for data quality, lineage, and validation tracking';

USE SCHEMA AUDIT;

-- ============================================================================
-- Table 1: DATA_QUALITY_CHECKS - Registry of all quality checks
-- ============================================================================

CREATE OR REPLACE TABLE AUDIT.DATA_QUALITY_CHECKS (
    check_id VARCHAR(100) PRIMARY KEY,
    check_name VARCHAR(255) NOT NULL,
    check_description VARCHAR(1000),
    layer VARCHAR(20) NOT NULL,                    -- BRONZE, SILVER, GOLD
    dimension VARCHAR(50) NOT NULL,                -- COMPLETENESS, ACCURACY, CONSISTENCY, TIMELINESS, VALIDITY, UNIQUENESS
    severity VARCHAR(20) NOT NULL,                 -- CRITICAL, HIGH, MEDIUM, LOW
    check_sql VARCHAR(10000) NOT NULL,             -- SQL query to execute
    expected_result VARCHAR(10) DEFAULT 'PASS',
    threshold_value FLOAT,                         -- Numeric threshold for pass/fail
    is_active BOOLEAN DEFAULT TRUE,
    created_by VARCHAR(100) DEFAULT CURRENT_USER(),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    modified_by VARCHAR(100) DEFAULT CURRENT_USER(),
    modified_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT chk_layer CHECK (layer IN ('BRONZE', 'SILVER', 'GOLD', 'ALL')),
    CONSTRAINT chk_dimension CHECK (dimension IN ('COMPLETENESS', 'ACCURACY', 'CONSISTENCY', 'TIMELINESS', 'VALIDITY', 'UNIQUENESS')),
    CONSTRAINT chk_severity CHECK (severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW'))
)
COMMENT = 'Registry of all data quality checks across all layers';

-- ============================================================================
-- Table 2: DATA_QUALITY_LOG - Historical results of quality check executions
-- ============================================================================

CREATE OR REPLACE TABLE AUDIT.DATA_QUALITY_LOG (
    log_id NUMBER AUTOINCREMENT PRIMARY KEY,
    check_id VARCHAR(100) NOT NULL,
    execution_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    environment VARCHAR(20),                       -- DEV, TEST, PROD
    check_status VARCHAR(10),                      -- PASS, FAIL, ERROR
    actual_value FLOAT,
    expected_value FLOAT,
    variance FLOAT,
    record_count NUMBER,
    execution_time_seconds FLOAT,
    error_message VARCHAR(5000),
    alert_sent BOOLEAN DEFAULT FALSE,
    executed_by VARCHAR(100) DEFAULT CURRENT_USER(),
    CONSTRAINT fk_check FOREIGN KEY (check_id) REFERENCES AUDIT.DATA_QUALITY_CHECKS(check_id),
    CONSTRAINT chk_status CHECK (check_status IN ('PASS', 'FAIL', 'ERROR', 'SKIPPED'))
)
COMMENT = 'Historical log of all quality check executions and results'
CLUSTER BY (CAST(execution_timestamp AS DATE));

-- ============================================================================
-- Table 3: DATA_QUALITY_ALERTS - Alert configuration and status
-- ============================================================================

CREATE OR REPLACE TABLE AUDIT.DATA_QUALITY_ALERTS (
    alert_id NUMBER AUTOINCREMENT PRIMARY KEY,
    check_id VARCHAR(100) NOT NULL,
    alert_type VARCHAR(50),                        -- EMAIL, SLACK, TEAMS, WEBHOOK
    recipient_list VARCHAR(1000),
    alert_threshold NUMBER DEFAULT 1,              -- Number of failures before alert
    consecutive_failures_required NUMBER DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    last_alert_sent TIMESTAMP,
    alert_count NUMBER DEFAULT 0,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT fk_alert_check FOREIGN KEY (check_id) REFERENCES AUDIT.DATA_QUALITY_CHECKS(check_id),
    CONSTRAINT chk_alert_type CHECK (alert_type IN ('EMAIL', 'SLACK', 'TEAMS', 'WEBHOOK', 'NONE'))
)
COMMENT = 'Alert configuration and tracking for quality check failures';

-- ============================================================================
-- Table 4: PIPELINE_EXECUTION_LOG - Track all pipeline runs
-- ============================================================================

CREATE OR REPLACE TABLE AUDIT.PIPELINE_EXECUTION_LOG (
    execution_id NUMBER AUTOINCREMENT PRIMARY KEY,
    pipeline_name VARCHAR(255) NOT NULL,
    pipeline_type VARCHAR(20),                     -- ORCHESTRATION, TRANSFORMATION
    layer VARCHAR(20),                             -- BRONZE, SILVER, GOLD, QUALITY
    environment VARCHAR(20),                       -- DEV, TEST, PROD
    execution_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    execution_end TIMESTAMP,
    execution_status VARCHAR(20),                  -- SUCCESS, FAILED, RUNNING, CANCELLED
    rows_processed NUMBER,
    rows_inserted NUMBER,
    rows_updated NUMBER,
    rows_deleted NUMBER,
    rows_rejected NUMBER,
    error_message VARCHAR(5000),
    executed_by VARCHAR(100) DEFAULT CURRENT_USER(),
    CONSTRAINT chk_pipeline_type CHECK (pipeline_type IN ('ORCHESTRATION', 'TRANSFORMATION')),
    CONSTRAINT chk_pipeline_status CHECK (execution_status IN ('SUCCESS', 'FAILED', 'RUNNING', 'CANCELLED', 'SKIPPED'))
)
COMMENT = 'Execution log for all data pipelines'
CLUSTER BY (CAST(execution_start AS DATE));

-- ============================================================================
-- Table 5: DATA_LINEAGE - Track data flow across layers
-- ============================================================================

CREATE OR REPLACE TABLE AUDIT.DATA_LINEAGE (
    lineage_id NUMBER AUTOINCREMENT PRIMARY KEY,
    source_layer VARCHAR(20) NOT NULL,
    source_table VARCHAR(255) NOT NULL,
    target_layer VARCHAR(20) NOT NULL,
    target_table VARCHAR(255) NOT NULL,
    transformation_name VARCHAR(255),
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    source_record_count NUMBER,
    target_record_count NUMBER,
    records_added NUMBER,
    records_modified NUMBER,
    records_deleted NUMBER,
    load_type VARCHAR(20),                         -- FULL, INCREMENTAL
    execution_id NUMBER,
    CONSTRAINT fk_execution FOREIGN KEY (execution_id) REFERENCES AUDIT.PIPELINE_EXECUTION_LOG(execution_id)
)
COMMENT = 'Data lineage tracking across Bronze, Silver, Gold layers'
CLUSTER BY (CAST(load_timestamp AS DATE));

-- ============================================================================
-- Table 6: DATA_PROFILING_RESULTS - Statistical profiling of tables
-- ============================================================================

CREATE OR REPLACE TABLE AUDIT.DATA_PROFILING_RESULTS (
    profile_id NUMBER AUTOINCREMENT PRIMARY KEY,
    schema_name VARCHAR(100) NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    column_name VARCHAR(255),
    profile_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    row_count NUMBER,
    distinct_count NUMBER,
    null_count NUMBER,
    null_percentage FLOAT,
    min_value VARCHAR(1000),
    max_value VARCHAR(1000),
    avg_value FLOAT,
    median_value FLOAT,
    std_dev FLOAT,
    top_5_values VARIANT,                          -- JSON array of top 5 values
    data_type VARCHAR(50)
)
COMMENT = 'Statistical profiling results for data quality analysis'
CLUSTER BY (CAST(profile_timestamp AS DATE), schema_name);

/*==============================================================================
  SECTION 2: BRONZE SCHEMA - Raw Data Ingestion Audit
==============================================================================*/

USE SCHEMA BRONZE;

-- ============================================================================
-- Table: BRONZE_LOAD_AUDIT - Track all Bronze layer loads
-- ============================================================================

CREATE OR REPLACE TABLE BRONZE.BRONZE_LOAD_AUDIT (
    audit_id NUMBER AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    load_type VARCHAR(20),                         -- FULL, INCREMENTAL, MANUAL
    source_system VARCHAR(100),                    -- API, FILE, DATABASE
    source_file_name VARCHAR(500),
    records_extracted NUMBER,
    records_loaded NUMBER,
    records_rejected NUMBER,
    load_status VARCHAR(20),                       -- SUCCESS, FAILED, PARTIAL
    error_message VARCHAR(5000),
    execution_time_seconds FLOAT,
    loaded_by VARCHAR(100) DEFAULT CURRENT_USER(),
    batch_id VARCHAR(100),                         -- For tracking related loads
    CONSTRAINT chk_bronze_load_type CHECK (load_type IN ('FULL', 'INCREMENTAL', 'MANUAL')),
    CONSTRAINT chk_bronze_load_status CHECK (load_status IN ('SUCCESS', 'FAILED', 'PARTIAL', 'RUNNING'))
)
COMMENT = 'Audit log for all Bronze layer data loads'
CLUSTER BY (CAST(load_timestamp AS DATE));

-- ============================================================================
-- Table: BRONZE_JSON_VALIDATION - Track JSON parsing issues
-- ============================================================================

CREATE OR REPLACE TABLE BRONZE.BRONZE_JSON_VALIDATION (
    validation_id NUMBER AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    validation_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    record_identifier VARCHAR(500),                -- Unique ID from source
    json_path VARCHAR(500),                        -- Path that failed
    validation_error VARCHAR(1000),
    raw_data VARIANT,                              -- Store problematic record
    resolution_status VARCHAR(20) DEFAULT 'OPEN',  -- OPEN, RESOLVED, IGNORED
    resolved_by VARCHAR(100),
    resolved_date TIMESTAMP,
    CONSTRAINT chk_resolution CHECK (resolution_status IN ('OPEN', 'RESOLVED', 'IGNORED', 'ESCALATED'))
)
COMMENT = 'Track JSON parsing and validation issues in Bronze layer'
CLUSTER BY (CAST(validation_timestamp AS DATE));

/*==============================================================================
  SECTION 3: SILVER SCHEMA - Transformation Audit
==============================================================================*/

USE SCHEMA SILVER;

-- ============================================================================
-- Table: SILVER_TRANSFORMATION_AUDIT - Track Silver transformations
-- ============================================================================

CREATE OR REPLACE TABLE SILVER.SILVER_TRANSFORMATION_AUDIT (
    audit_id NUMBER AUTOINCREMENT PRIMARY KEY,
    source_table VARCHAR(255) NOT NULL,
    target_table VARCHAR(255) NOT NULL,
    transformation_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    transformation_type VARCHAR(50),               -- FLATTEN, CLEANSE, ENRICH, AGGREGATE
    load_type VARCHAR(20),                         -- FULL, INCREMENTAL
    source_record_count NUMBER,
    target_record_count NUMBER,
    records_inserted NUMBER,
    records_updated NUMBER,
    records_rejected NUMBER,
    data_quality_score FLOAT,                      -- 0-100 quality score
    transformation_status VARCHAR(20),             -- SUCCESS, FAILED, PARTIAL
    error_message VARCHAR(5000),
    execution_time_seconds FLOAT,
    watermark_value TIMESTAMP,                     -- For incremental loads
    transformed_by VARCHAR(100) DEFAULT CURRENT_USER(),
    CONSTRAINT chk_silver_trans_type CHECK (transformation_type IN ('FLATTEN', 'CLEANSE', 'ENRICH', 'AGGREGATE', 'DEDUPE', 'VALIDATE')),
    CONSTRAINT chk_silver_trans_status CHECK (transformation_status IN ('SUCCESS', 'FAILED', 'PARTIAL', 'RUNNING'))
)
COMMENT = 'Audit log for all Silver layer transformations'
CLUSTER BY (CAST(transformation_timestamp AS DATE));

-- ============================================================================
-- Table: SILVER_DATA_QUALITY_ISSUES - Track Silver data quality problems
-- ============================================================================

CREATE OR REPLACE TABLE SILVER.SILVER_DATA_QUALITY_ISSUES (
    issue_id NUMBER AUTOINCREMENT PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    issue_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    issue_type VARCHAR(50),                        -- MISSING_VALUE, INVALID_FORMAT, BUSINESS_RULE_VIOLATION, OUTLIER
    column_name VARCHAR(255),
    record_identifier VARCHAR(500),                -- Natural key of problematic record
    expected_value VARCHAR(1000),
    actual_value VARCHAR(1000),
    rule_violated VARCHAR(500),
    severity VARCHAR(20),                          -- CRITICAL, HIGH, MEDIUM, LOW
    resolution_status VARCHAR(20) DEFAULT 'OPEN',
    resolution_notes VARCHAR(2000),
    resolved_by VARCHAR(100),
    resolved_date TIMESTAMP,
    CONSTRAINT chk_issue_severity CHECK (severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')),
    CONSTRAINT chk_issue_resolution CHECK (resolution_status IN ('OPEN', 'RESOLVED', 'IGNORED', 'ESCALATED', 'AUTOMATED_FIX'))
)
COMMENT = 'Track data quality issues identified in Silver layer'
CLUSTER BY (CAST(issue_timestamp AS DATE), severity);

/*==============================================================================
  SECTION 4: GOLD SCHEMA - Dimensional Model Audit
==============================================================================*/

USE SCHEMA GOLD;

-- ============================================================================
-- Table: GOLD_DIMENSION_AUDIT - Track dimension table changes (SCD)
-- ============================================================================

CREATE OR REPLACE TABLE GOLD.GOLD_DIMENSION_AUDIT (
    audit_id NUMBER AUTOINCREMENT PRIMARY KEY,
    dimension_table VARCHAR(255) NOT NULL,
    audit_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    scd_type VARCHAR(10),                          -- TYPE_1, TYPE_2, TYPE_3, STATIC
    operation_type VARCHAR(20),                    -- INSERT, UPDATE, EXPIRE, DELETE
    natural_key VARCHAR(500),                      -- Business key that changed
    surrogate_key NUMBER,                          -- Dimension surrogate key
    attribute_changed VARCHAR(255),                -- Column that triggered change
    old_value VARCHAR(1000),
    new_value VARCHAR(1000),
    valid_from TIMESTAMP,
    valid_to TIMESTAMP,
    is_current BOOLEAN,
    changed_by VARCHAR(100) DEFAULT CURRENT_USER(),
    CONSTRAINT chk_scd_type CHECK (scd_type IN ('TYPE_1', 'TYPE_2', 'TYPE_3', 'STATIC')),
    CONSTRAINT chk_operation CHECK (operation_type IN ('INSERT', 'UPDATE', 'EXPIRE', 'DELETE', 'NO_CHANGE'))
)
COMMENT = 'Audit trail for all dimension table changes (SCD tracking)'
CLUSTER BY (CAST(audit_timestamp AS DATE), dimension_table);

-- ============================================================================
-- Table: GOLD_FACT_AUDIT - Track fact table loads
-- ============================================================================

CREATE OR REPLACE TABLE GOLD.GOLD_FACT_AUDIT (
    audit_id NUMBER AUTOINCREMENT PRIMARY KEY,
    fact_table VARCHAR(255) NOT NULL,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    load_type VARCHAR(20),                         -- FULL, INCREMENTAL, BACKFILL
    load_date DATE,                                -- Business date being loaded
    source_record_count NUMBER,
    target_record_count NUMBER,
    records_inserted NUMBER,
    records_updated NUMBER,
    orphaned_records NUMBER,                       -- Records without valid dimension keys
    aggregate_metrics VARIANT,                     -- JSON: {total_revenue: 100000, total_cost: 50000}
    load_status VARCHAR(20),                       -- SUCCESS, FAILED, PARTIAL
    error_message VARCHAR(5000),
    execution_time_seconds FLOAT,
    loaded_by VARCHAR(100) DEFAULT CURRENT_USER(),
    CONSTRAINT chk_gold_load_type CHECK (load_type IN ('FULL', 'INCREMENTAL', 'BACKFILL', 'CORRECTION')),
    CONSTRAINT chk_gold_load_status CHECK (load_status IN ('SUCCESS', 'FAILED', 'PARTIAL', 'RUNNING'))
)
COMMENT = 'Audit log for all fact table loads'
CLUSTER BY (CAST(load_timestamp AS DATE), fact_table);

-- ============================================================================
-- Table: GOLD_REFERENTIAL_INTEGRITY_LOG - Track RI violations
-- ============================================================================

CREATE OR REPLACE TABLE GOLD.GOLD_REFERENTIAL_INTEGRITY_LOG (
    log_id NUMBER AUTOINCREMENT PRIMARY KEY,
    check_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    fact_table VARCHAR(255) NOT NULL,
    dimension_table VARCHAR(255) NOT NULL,
    foreign_key_column VARCHAR(255) NOT NULL,
    orphaned_record_count NUMBER,
    sample_orphaned_keys VARIANT,                  -- JSON array of sample orphaned keys
    resolution_status VARCHAR(20) DEFAULT 'OPEN',
    resolution_action VARCHAR(1000),               -- Description of fix applied
    resolved_by VARCHAR(100),
    resolved_date TIMESTAMP,
    CONSTRAINT chk_ri_resolution CHECK (resolution_status IN ('OPEN', 'RESOLVED', 'IGNORED', 'AUTO_FIXED'))
)
COMMENT = 'Track referential integrity violations in fact-dimension relationships'
CLUSTER BY (CAST(check_timestamp AS DATE));

/*==============================================================================
  SECTION 5: INDEXES AND PERFORMANCE OPTIMIZATION
==============================================================================*/

-- Add search optimization for frequently queried audit tables
ALTER TABLE AUDIT.DATA_QUALITY_LOG ADD SEARCH OPTIMIZATION ON EQUALITY(check_id, check_status, environment);
ALTER TABLE AUDIT.PIPELINE_EXECUTION_LOG ADD SEARCH OPTIMIZATION ON EQUALITY(pipeline_name, execution_status, environment);
ALTER TABLE BRONZE.BRONZE_LOAD_AUDIT ADD SEARCH OPTIMIZATION ON EQUALITY(table_name, load_status);
ALTER TABLE SILVER.SILVER_TRANSFORMATION_AUDIT ADD SEARCH OPTIMIZATION ON EQUALITY(source_table, target_table, transformation_status);
ALTER TABLE GOLD.GOLD_DIMENSION_AUDIT ADD SEARCH OPTIMIZATION ON EQUALITY(dimension_table, natural_key);

/*==============================================================================
  SECTION 6: GRANT PERMISSIONS
==============================================================================*/

-- Grant permissions to MATILLION_ROLE (adjust as needed)
GRANT USAGE ON SCHEMA AUDIT TO ROLE MATILLION_ROLE;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA AUDIT TO ROLE MATILLION_ROLE;

GRANT SELECT, INSERT ON TABLE BRONZE.BRONZE_LOAD_AUDIT TO ROLE MATILLION_ROLE;
GRANT SELECT, INSERT ON TABLE BRONZE.BRONZE_JSON_VALIDATION TO ROLE MATILLION_ROLE;

GRANT SELECT, INSERT ON TABLE SILVER.SILVER_TRANSFORMATION_AUDIT TO ROLE MATILLION_ROLE;
GRANT SELECT, INSERT ON TABLE SILVER.SILVER_DATA_QUALITY_ISSUES TO ROLE MATILLION_ROLE;

GRANT SELECT, INSERT ON TABLE GOLD.GOLD_DIMENSION_AUDIT TO ROLE MATILLION_ROLE;
GRANT SELECT, INSERT ON TABLE GOLD.GOLD_FACT_AUDIT TO ROLE MATILLION_ROLE;
GRANT SELECT, INSERT ON TABLE GOLD.GOLD_REFERENTIAL_INTEGRITY_LOG TO ROLE MATILLION_ROLE;

/*==============================================================================
  VERIFICATION QUERIES
==============================================================================*/

-- Verify all audit tables created
SELECT 
    table_schema,
    table_name,
    table_type,
    row_count,
    bytes,
    comment
FROM INFORMATION_SCHEMA.TABLES
WHERE table_schema IN ('AUDIT', 'BRONZE', 'SILVER', 'GOLD')
  AND (table_name LIKE '%AUDIT%' 
    OR table_name LIKE '%QUALITY%'
    OR table_name LIKE '%LINEAGE%'
    OR table_name LIKE '%VALIDATION%')
ORDER BY table_schema, table_name;

SELECT 'Audit tables created successfully!' as status;