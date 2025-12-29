/*==============================================================================
  AUDIT VALIDATION QUERIES - Marketing Analytics Data Warehouse
  
  Purpose: Comprehensive validation queries for audit tables and data quality
           monitoring across all medallion layers
  
  Sections:
    1. Audit Table Health Checks
    2. Data Quality Monitoring
    3. Pipeline Execution Monitoring
    4. Data Lineage Validation
    5. Layer-Specific Audit Checks
    6. Performance and Trend Analysis
  
  Created: 2025-12-23
  Version: 1.0
  
  Usage: Run these queries regularly to monitor data quality and audit health
==============================================================================*/

USE DATABASE MATILLION_DB;

/*==============================================================================
  SECTION 1: AUDIT TABLE HEALTH CHECKS
==============================================================================*/

-- Query 1.1: Verify All Audit Tables Exist
SELECT 
    table_schema,
    table_name,
    CASE 
        WHEN row_count > 0 THEN '✅ Has Data'
        ELSE '⚠️ Empty'
    END as status,
    row_count,
    ROUND(bytes / 1024 / 1024, 2) as size_mb,
    comment
FROM INFORMATION_SCHEMA.TABLES
WHERE table_schema IN ('AUDIT', 'BRONZE', 'SILVER', 'GOLD')
  AND (table_name LIKE '%AUDIT%' 
    OR table_name LIKE '%QUALITY%'
    OR table_name LIKE '%LINEAGE%'
    OR table_name LIKE '%VALIDATION%')
ORDER BY table_schema, table_name;

-- Query 1.2: Check Audit Table Row Counts Summary
SELECT 
    'AUDIT.DATA_QUALITY_CHECKS' as table_name,
    COUNT(*) as row_count,
    SUM(CASE WHEN is_active = TRUE THEN 1 ELSE 0 END) as active_checks
FROM AUDIT.DATA_QUALITY_CHECKS

UNION ALL

SELECT 
    'AUDIT.DATA_QUALITY_LOG',
    COUNT(*),
    SUM(CASE WHEN check_status = 'PASS' THEN 1 ELSE 0 END) as passed_checks
FROM AUDIT.DATA_QUALITY_LOG

UNION ALL

SELECT 
    'AUDIT.PIPELINE_EXECUTION_LOG',
    COUNT(*),
    SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_runs
FROM AUDIT.PIPELINE_EXECUTION_LOG

UNION ALL

SELECT 
    'AUDIT.DATA_LINEAGE',
    COUNT(*),
    COUNT(DISTINCT source_table || '→' || target_table) as unique_lineages
FROM AUDIT.DATA_LINEAGE;

-- Query 1.3: Check for Missing Audit Entries (Tables without Recent Audit)
SELECT 
    t.table_schema,
    t.table_name,
    t.row_count,
    'Missing Bronze Audit' as issue
FROM INFORMATION_SCHEMA.TABLES t
LEFT JOIN BRONZE.BRONZE_LOAD_AUDIT a 
    ON t.table_name = a.table_name
   AND a.load_timestamp >= DATEADD(day, -1, CURRENT_DATE())
WHERE t.table_schema = 'BRONZE'
  AND t.table_name LIKE 'MTLN_BRONZE_%'
  AND a.table_name IS NULL

UNION ALL

SELECT 
    t.table_schema,
    t.table_name,
    t.row_count,
    'Missing Silver Audit'
FROM INFORMATION_SCHEMA.TABLES t
LEFT JOIN SILVER.SILVER_TRANSFORMATION_AUDIT a 
    ON t.table_name = a.target_table
   AND a.transformation_timestamp >= DATEADD(day, -1, CURRENT_DATE())
WHERE t.table_schema = 'SILVER'
  AND t.table_name LIKE 'MTLN_SILVER_%'
  AND a.target_table IS NULL;

/*==============================================================================
  SECTION 2: DATA QUALITY MONITORING
==============================================================================*/

-- Query 2.1: Quality Check Status Dashboard (Last 24 Hours)
SELECT 
    c.layer,
    c.severity,
    COUNT(DISTINCT c.check_id) as total_checks,
    SUM(CASE WHEN l.check_status = 'PASS' THEN 1 ELSE 0 END) as passed,
    SUM(CASE WHEN l.check_status = 'FAIL' THEN 1 ELSE 0 END) as failed,
    SUM(CASE WHEN l.check_status = 'ERROR' THEN 1 ELSE 0 END) as errors,
    ROUND((SUM(CASE WHEN l.check_status = 'PASS' THEN 1 ELSE 0 END)::FLOAT / COUNT(*)) * 100, 2) as pass_rate_pct
FROM AUDIT.DATA_QUALITY_CHECKS c
LEFT JOIN AUDIT.DATA_QUALITY_LOG l 
    ON c.check_id = l.check_id
   AND l.execution_timestamp >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
WHERE c.is_active = TRUE
GROUP BY 1, 2
ORDER BY 
    CASE c.layer WHEN 'BRONZE' THEN 1 WHEN 'SILVER' THEN 2 WHEN 'GOLD' THEN 3 ELSE 4 END,
    CASE c.severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END;

-- Query 2.2: Failed Quality Checks Requiring Attention
SELECT 
    l.execution_timestamp,
    c.layer,
    c.severity,
    c.check_name,
    c.check_description,
    l.check_status,
    l.actual_value,
    l.expected_value,
    l.error_message,
    DATEDIFF(hour, l.execution_timestamp, CURRENT_TIMESTAMP()) as hours_since_failure,
    l.alert_sent
FROM AUDIT.DATA_QUALITY_LOG l
JOIN AUDIT.DATA_QUALITY_CHECKS c ON l.check_id = c.check_id
WHERE l.check_status IN ('FAIL', 'ERROR')
  AND l.execution_timestamp >= DATEADD(day, -7, CURRENT_DATE())
  AND c.is_active = TRUE
ORDER BY 
    CASE c.severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
    l.execution_timestamp DESC;

-- Query 2.3: Quality Trend Analysis (Last 30 Days)
SELECT 
    CAST(l.execution_timestamp AS DATE) as check_date,
    c.layer,
    COUNT(*) as total_checks,
    SUM(CASE WHEN l.check_status = 'PASS' THEN 1 ELSE 0 END) as passed,
    SUM(CASE WHEN l.check_status = 'FAIL' THEN 1 ELSE 0 END) as failed,
    ROUND((SUM(CASE WHEN l.check_status = 'PASS' THEN 1 ELSE 0 END)::FLOAT / COUNT(*)) * 100, 2) as pass_rate_pct
FROM AUDIT.DATA_QUALITY_LOG l
JOIN AUDIT.DATA_QUALITY_CHECKS c ON l.check_id = c.check_id
WHERE l.execution_timestamp >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY 1, 2
HAVING COUNT(*) > 0
ORDER BY check_date DESC, layer;

-- Query 2.4: Quality Check Performance (Slowest Checks)
SELECT 
    c.check_id,
    c.check_name,
    c.layer,
    COUNT(*) as execution_count,
    ROUND(AVG(l.execution_time_seconds), 2) as avg_execution_time,
    ROUND(MAX(l.execution_time_seconds), 2) as max_execution_time,
    ROUND(MIN(l.execution_time_seconds), 2) as min_execution_time
FROM AUDIT.DATA_QUALITY_LOG l
JOIN AUDIT.DATA_QUALITY_CHECKS c ON l.check_id = c.check_id
WHERE l.execution_timestamp >= DATEADD(day, -7, CURRENT_DATE())
  AND l.execution_time_seconds IS NOT NULL
GROUP BY 1, 2, 3
HAVING AVG(l.execution_time_seconds) > 1  -- Checks taking more than 1 second
ORDER BY avg_execution_time DESC
LIMIT 20;

-- Query 2.5: Quality Score by Dimension
SELECT 
    c.dimension,
    COUNT(*) as total_checks,
    SUM(CASE WHEN l.check_status = 'PASS' THEN 1 ELSE 0 END) as passed,
    SUM(CASE WHEN l.check_status = 'FAIL' THEN 1 ELSE 0 END) as failed,
    ROUND((SUM(CASE WHEN l.check_status = 'PASS' THEN 1 ELSE 0 END)::FLOAT / COUNT(*)) * 100, 2) as quality_score
FROM AUDIT.DATA_QUALITY_CHECKS c
JOIN AUDIT.DATA_QUALITY_LOG l 
    ON c.check_id = l.check_id
   AND l.execution_timestamp >= DATEADD(day, -1, CURRENT_DATE())
WHERE c.is_active = TRUE
GROUP BY 1
ORDER BY quality_score DESC;

/*==============================================================================
  SECTION 3: PIPELINE EXECUTION MONITORING
==============================================================================*/

-- Query 3.1: Pipeline Execution Summary (Last 7 Days)
SELECT 
    CAST(execution_start AS DATE) as execution_date,
    layer,
    COUNT(*) as total_runs,
    SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END) as successful,
    SUM(CASE WHEN execution_status = 'FAILED' THEN 1 ELSE 0 END) as failed,
    SUM(CASE WHEN execution_status = 'RUNNING' THEN 1 ELSE 0 END) as running,
    ROUND((SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END)::FLOAT / COUNT(*)) * 100, 2) as success_rate_pct
FROM AUDIT.PIPELINE_EXECUTION_LOG
WHERE execution_start >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY 1, 2
ORDER BY execution_date DESC, layer;

-- Query 3.2: Failed Pipeline Runs
SELECT 
    execution_id,
    pipeline_name,
    layer,
    environment,
    execution_start,
    execution_end,
    DATEDIFF(minute, execution_start, COALESCE(execution_end, CURRENT_TIMESTAMP())) as duration_minutes,
    rows_processed,
    error_message,
    executed_by
FROM AUDIT.PIPELINE_EXECUTION_LOG
WHERE execution_status = 'FAILED'
  AND execution_start >= DATEADD(day, -7, CURRENT_DATE())
ORDER BY execution_start DESC;

-- Query 3.3: Pipeline Performance Metrics
SELECT 
    pipeline_name,
    layer,
    COUNT(*) as execution_count,
    ROUND(AVG(DATEDIFF(second, execution_start, execution_end)), 2) as avg_duration_seconds,
    ROUND(MAX(DATEDIFF(second, execution_start, execution_end)), 2) as max_duration_seconds,
    SUM(rows_processed) as total_rows_processed,
    ROUND(AVG(rows_processed), 0) as avg_rows_per_run
FROM AUDIT.PIPELINE_EXECUTION_LOG
WHERE execution_status = 'SUCCESS'
  AND execution_start >= DATEADD(day, -7, CURRENT_DATE())
  AND execution_end IS NOT NULL
GROUP BY 1, 2
ORDER BY avg_duration_seconds DESC
LIMIT 20;

-- Query 3.4: Long-Running Pipelines (Currently Active)
SELECT 
    execution_id,
    pipeline_name,
    layer,
    environment,
    execution_start,
    DATEDIFF(minute, execution_start, CURRENT_TIMESTAMP()) as running_for_minutes,
    rows_processed,
    executed_by
FROM AUDIT.PIPELINE_EXECUTION_LOG
WHERE execution_status = 'RUNNING'
  AND execution_start >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
ORDER BY execution_start;

/*==============================================================================
  SECTION 4: DATA LINEAGE VALIDATION
==============================================================================*/

-- Query 4.1: Complete Data Lineage Flow
SELECT 
    source_layer,
    source_table,
    target_layer,
    target_table,
    transformation_name,
    load_type,
    COUNT(*) as load_count,
    MAX(load_timestamp) as last_load,
    SUM(source_record_count) as total_source_records,
    SUM(target_record_count) as total_target_records,
    ROUND((SUM(target_record_count)::FLOAT / NULLIF(SUM(source_record_count), 0)) * 100, 2) as data_flow_pct
FROM AUDIT.DATA_LINEAGE
WHERE load_timestamp >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY source_layer, source_table, target_layer;

-- Query 4.2: Data Lineage Gaps (Missing Downstream Loads)
SELECT 
    b.table_name as bronze_table,
    b.load_timestamp as bronze_load_time,
    'Missing Silver lineage' as issue,
    DATEDIFF(hour, b.load_timestamp, CURRENT_TIMESTAMP()) as hours_since_load
FROM BRONZE.BRONZE_LOAD_AUDIT b
LEFT JOIN AUDIT.DATA_LINEAGE l 
    ON l.source_table = b.table_name
   AND l.source_layer = 'BRONZE'
   AND l.target_layer = 'SILVER'
   AND l.load_timestamp >= b.load_timestamp
WHERE b.load_timestamp >= DATEADD(day, -1, CURRENT_DATE())
  AND b.load_status = 'SUCCESS'
  AND l.lineage_id IS NULL;

-- Query 4.3: Record Count Reconciliation Across Layers
WITH bronze_counts AS (
    SELECT 
        table_name,
        SUM(records_loaded) as bronze_records,
        MAX(load_timestamp) as last_load
    FROM BRONZE.BRONZE_LOAD_AUDIT
    WHERE load_timestamp >= DATEADD(day, -1, CURRENT_DATE())
      AND load_status = 'SUCCESS'
    GROUP BY table_name
),
silver_counts AS (
    SELECT 
        source_table,
        target_table,
        SUM(target_record_count) as silver_records
    FROM AUDIT.DATA_LINEAGE
    WHERE source_layer = 'BRONZE'
      AND target_layer = 'SILVER'
      AND load_timestamp >= DATEADD(day, -1, CURRENT_DATE())
    GROUP BY 1, 2
)
SELECT 
    b.table_name as bronze_table,
    s.target_table as silver_table,
    b.bronze_records,
    s.silver_records,
    ABS(b.bronze_records - COALESCE(s.silver_records, 0)) as variance,
    ROUND(((COALESCE(s.silver_records, 0)::FLOAT / NULLIF(b.bronze_records, 0)) * 100), 2) as match_pct,
    CASE 
        WHEN match_pct >= 99 THEN '✅ Good'
        WHEN match_pct >= 95 THEN '⚠️ Check'
        ELSE '❌ Issue'
    END as status
FROM bronze_counts b
LEFT JOIN silver_counts s ON b.table_name = s.source_table
ORDER BY variance DESC;

/*==============================================================================
  SECTION 5: LAYER-SPECIFIC AUDIT CHECKS
==============================================================================*/

-- Query 5.1: Bronze Layer - Load Status Summary
SELECT 
    CAST(load_timestamp AS DATE) as load_date,
    table_name,
    load_type,
    load_status,
    records_extracted,
    records_loaded,
    records_rejected,
    ROUND((records_loaded::FLOAT / NULLIF(records_extracted, 0)) * 100, 2) as load_success_rate,
    execution_time_seconds
FROM BRONZE.BRONZE_LOAD_AUDIT
WHERE load_timestamp >= DATEADD(day, -7, CURRENT_DATE())
ORDER BY load_timestamp DESC;

-- Query 5.2: Bronze Layer - JSON Validation Issues
SELECT 
    table_name,
    json_path,
    validation_error,
    COUNT(*) as error_count,
    SUM(CASE WHEN resolution_status = 'OPEN' THEN 1 ELSE 0 END) as open_issues,
    MAX(validation_timestamp) as last_occurrence
FROM BRONZE.BRONZE_JSON_VALIDATION
WHERE validation_timestamp >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY error_count DESC;

-- Query 5.3: Silver Layer - Transformation Quality Score
SELECT 
    target_table,
    transformation_type,
    COUNT(*) as transformation_count,
    AVG(data_quality_score) as avg_quality_score,
    SUM(records_rejected) as total_rejected,
    ROUND(AVG(execution_time_seconds), 2) as avg_execution_time,
    MAX(transformation_timestamp) as last_transformation
FROM SILVER.SILVER_TRANSFORMATION_AUDIT
WHERE transformation_timestamp >= DATEADD(day, -7, CURRENT_DATE())
  AND transformation_status = 'SUCCESS'
GROUP BY 1, 2
ORDER BY avg_quality_score ASC, total_rejected DESC;

-- Query 5.4: Silver Layer - Data Quality Issues by Type
SELECT 
    table_name,
    issue_type,
    severity,
    COUNT(*) as issue_count,
    SUM(CASE WHEN resolution_status = 'OPEN' THEN 1 ELSE 0 END) as open_issues,
    SUM(CASE WHEN resolution_status = 'RESOLVED' THEN 1 ELSE 0 END) as resolved_issues,
    MAX(issue_timestamp) as last_occurrence
FROM SILVER.SILVER_DATA_QUALITY_ISSUES
WHERE issue_timestamp >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY issue_count DESC;

-- Query 5.5: Gold Layer - SCD Audit Trail
SELECT 
    dimension_table,
    scd_type,
    operation_type,
    COUNT(*) as change_count,
    COUNT(DISTINCT natural_key) as unique_entities_changed,
    MAX(audit_timestamp) as last_change
FROM GOLD.GOLD_DIMENSION_AUDIT
WHERE audit_timestamp >= DATEADD(day, -7, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY change_count DESC;

-- Query 5.6: Gold Layer - Fact Load Summary
SELECT 
    fact_table,
    load_date,
    load_type,
    load_status,
    source_record_count,
    target_record_count,
    records_inserted,
    records_updated,
    orphaned_records,
    execution_time_seconds
FROM GOLD.GOLD_FACT_AUDIT
WHERE load_timestamp >= DATEADD(day, -7, CURRENT_DATE())
ORDER BY load_timestamp DESC;

-- Query 5.7: Gold Layer - Referential Integrity Violations
SELECT 
    fact_table,
    dimension_table,
    foreign_key_column,
    orphaned_record_count,
    resolution_status,
    check_timestamp,
    resolution_action
FROM GOLD.GOLD_REFERENTIAL_INTEGRITY_LOG
WHERE check_timestamp >= DATEADD(day, -7, CURRENT_DATE())
  AND orphaned_record_count > 0
ORDER BY orphaned_record_count DESC, check_timestamp DESC;

/*==============================================================================
  SECTION 6: PERFORMANCE AND TREND ANALYSIS
==============================================================================*/

-- Query 6.1: Overall Data Quality Score (Executive Summary)
SELECT 
    '📊 Overall Data Quality Score' as metric,
    CONCAT(ROUND(AVG(CASE WHEN check_status = 'PASS' THEN 100 ELSE 0 END), 1), '%') as value,
    COUNT(*) as checks_executed
FROM AUDIT.DATA_QUALITY_LOG
WHERE execution_timestamp >= DATEADD(day, -1, CURRENT_DATE())

UNION ALL

SELECT 
    '❌ Critical Failures (24h)',
    COUNT(*)::VARCHAR,
    NULL
FROM AUDIT.DATA_QUALITY_LOG l
JOIN AUDIT.DATA_QUALITY_CHECKS c ON l.check_id = c.check_id
WHERE l.check_status = 'FAIL'
  AND c.severity = 'CRITICAL'
  AND l.execution_timestamp >= DATEADD(day, -1, CURRENT_TIMESTAMP())

UNION ALL

SELECT 
    '✅ Pipeline Success Rate (7d)',
    CONCAT(ROUND((SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END)::FLOAT / COUNT(*)) * 100, 1), '%'),
    COUNT(*)
FROM AUDIT.PIPELINE_EXECUTION_LOG
WHERE execution_start >= DATEADD(day, -7, CURRENT_DATE())

UNION ALL

SELECT 
    '📈 Total Records Processed (7d)',
    TO_VARCHAR(SUM(rows_processed), '999,999,999'),
    NULL
FROM AUDIT.PIPELINE_EXECUTION_LOG
WHERE execution_start >= DATEADD(day, -7, CURRENT_DATE())
  AND execution_status = 'SUCCESS';

-- Query 6.2: Data Quality Trend (30-Day Moving Average)
SELECT 
    CAST(execution_timestamp AS DATE) as check_date,
    COUNT(*) as total_checks,
    SUM(CASE WHEN check_status = 'PASS' THEN 1 ELSE 0 END) as passed,
    ROUND((SUM(CASE WHEN check_status = 'PASS' THEN 1 ELSE 0 END)::FLOAT / COUNT(*)) * 100, 2) as pass_rate,
    AVG(SUM(CASE WHEN check_status = 'PASS' THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100) 
        OVER (ORDER BY CAST(execution_timestamp AS DATE) ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) as moving_avg_7d
FROM AUDIT.DATA_QUALITY_LOG
WHERE execution_timestamp >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY check_date
ORDER BY check_date DESC;

-- Query 6.3: Alerts Generated Summary
SELECT 
    c.check_name,
    c.severity,
    a.alert_type,
    a.alert_count,
    a.last_alert_sent,
    DATEDIFF(hour, a.last_alert_sent, CURRENT_TIMESTAMP()) as hours_since_last_alert
FROM AUDIT.DATA_QUALITY_ALERTS a
JOIN AUDIT.DATA_QUALITY_CHECKS c ON a.check_id = c.check_id
WHERE a.is_active = TRUE
  AND a.alert_count > 0
ORDER BY a.last_alert_sent DESC;

-- Query 6.4: Data Profiling Results Summary
SELECT 
    schema_name,
    table_name,
    COUNT(DISTINCT column_name) as columns_profiled,
    AVG(null_percentage) as avg_null_pct,
    MAX(profile_timestamp) as last_profiled,
    DATEDIFF(day, MAX(profile_timestamp), CURRENT_DATE()) as days_since_last_profile
FROM AUDIT.DATA_PROFILING_RESULTS
GROUP BY 1, 2
ORDER BY days_since_last_profile DESC;

/*==============================================================================
  SECTION 7: ACTION ITEMS AND RECOMMENDATIONS
==============================================================================*/

-- Query 7.1: Critical Action Items
SELECT 
    'Critical' as priority,
    'Failed Quality Check' as action_type,
    c.check_name as description,
    l.execution_timestamp as identified_at
FROM AUDIT.DATA_QUALITY_LOG l
JOIN AUDIT.DATA_QUALITY_CHECKS c ON l.check_id = c.check_id
WHERE l.check_status = 'FAIL'
  AND c.severity = 'CRITICAL'
  AND l.execution_timestamp >= DATEADD(day, -1, CURRENT_TIMESTAMP())

UNION ALL

SELECT 
    'High',
    'Pipeline Failure',
    pipeline_name,
    execution_start
FROM AUDIT.PIPELINE_EXECUTION_LOG
WHERE execution_status = 'FAILED'
  AND execution_start >= DATEADD(day, -1, CURRENT_DATE())

UNION ALL

SELECT 
    'High',
    'Referential Integrity Violation',
    CONCAT(fact_table, ' → ', dimension_table),
    check_timestamp
FROM GOLD.GOLD_REFERENTIAL_INTEGRITY_LOG
WHERE orphaned_record_count > 0
  AND resolution_status = 'OPEN'
  AND check_timestamp >= DATEADD(day, -1, CURRENT_DATE())

ORDER BY priority, identified_at DESC;

-- Query 7.2: Audit Table Maintenance Recommendations
SELECT 
    'Archive old audit logs' as recommendation,
    CONCAT('AUDIT.DATA_QUALITY_LOG has ', 
           (SELECT COUNT(*) FROM AUDIT.DATA_QUALITY_LOG 
            WHERE execution_timestamp < DATEADD(day, -90, CURRENT_DATE())),
           ' records older than 90 days') as details,
    'Medium' as priority
WHERE (SELECT COUNT(*) FROM AUDIT.DATA_QUALITY_LOG 
       WHERE execution_timestamp < DATEADD(day, -90, CURRENT_DATE())) > 0

UNION ALL

SELECT 
    'Profile tables',
    CONCAT(schema_name, '.', table_name, ' last profiled ', 
           days_since_last_profile, ' days ago'),
    'Low'
FROM (
    SELECT 
        schema_name,
        table_name,
        DATEDIFF(day, MAX(profile_timestamp), CURRENT_DATE()) as days_since_last_profile
    FROM AUDIT.DATA_PROFILING_RESULTS
    GROUP BY 1, 2
    HAVING days_since_last_profile > 30
)

UNION ALL

SELECT 
    'Review inactive checks',
    CONCAT(COUNT(*), ' quality checks are marked inactive'),
    'Low'
FROM AUDIT.DATA_QUALITY_CHECKS
WHERE is_active = FALSE
HAVING COUNT(*) > 0;

/*==============================================================================
  END OF AUDIT VALIDATION QUERIES
==============================================================================*/

SELECT 'Audit validation queries completed successfully! ✅' as status;