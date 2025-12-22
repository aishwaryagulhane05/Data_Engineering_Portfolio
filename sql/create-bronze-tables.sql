-- ============================================================================
-- CREATE BRONZE TABLES
-- Marketing Analytics Data Warehouse
-- ============================================================================
-- Purpose: Create all Bronze layer tables for sample data testing
-- Target: MTLN_PROD.BRONZE schema
-- Duration: < 1 minute
-- Note: Run this BEFORE generate-sample-data.sql
-- ============================================================================

USE WAREHOUSE MTLN_ETL_WH;
USE DATABASE MTLN_PROD;
USE SCHEMA BRONZE;

-- =====================================USE ROLE MTLN_ADMIN;  -- Or ACCOUNTADMIN if MTLN_ADMIN not created yet
=======================================
-- TABLE 1: CHANNELS
-- ============================================================================

CREATE OR REPLACE TRANSIENT TABLE mtln_bronze_channels (
    channel_id                VARCHAR(100) NOT NULL,
    channel_name              VARCHAR(255),
    channel_type              VARCHAR(100),
    category                  VARCHAR(100),
    cost_structure            VARCHAR(100),
    last_modified_timestamp   TIMESTAMP_NTZ,
    load_timestamp            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system             VARCHAR(50) DEFAULT 'MARKETING_PLATFORM',
    
    -- Constraints
    CONSTRAINT pk_bronze_channels PRIMARY KEY (channel_id)
)
DATA_RETENTION_TIME_IN_DAYS = 14
COMMENT = 'Bronze: Marketing channels - as-is from source';

SELECT 'Table created: mtln_bronze_channels' AS status;

-- ============================================================================
-- TABLE 2: CAMPAIGNS
-- ============================================================================

CREATE OR REPLACE TRANSIENT TABLE mtln_bronze_campaigns (
    campaign_id               VARCHAR(100) NOT NULL,
    campaign_name             VARCHAR(255),
    campaign_type             VARCHAR(100),
    start_date                DATE,
    end_date                  DATE,
    budget                    NUMBER(18,2),
    status                    VARCHAR(50),
    objective                 VARCHAR(255),
    last_modified_timestamp   TIMESTAMP_NTZ,
    load_timestamp            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system             VARCHAR(50) DEFAULT 'MARKETING_PLATFORM',
    
    -- Constraints
    CONSTRAINT pk_bronze_campaigns PRIMARY KEY (campaign_id)
)
DATA_RETENTION_TIME_IN_DAYS = 14
COMMENT = 'Bronze: Marketing campaigns - as-is from source';

SELECT 'Table created: mtln_bronze_campaigns' AS status;

-- ============================================================================
-- TABLE 3: CUSTOMERS
-- ============================================================================

CREATE OR REPLACE TRANSIENT TABLE mtln_bronze_customers (
    customer_id               VARCHAR(100) NOT NULL,
    customer_name             VARCHAR(255),
    email                     VARCHAR(255),
    phone                     VARCHAR(50),
    segment                   VARCHAR(100),
    tier                      VARCHAR(50),
    status                    VARCHAR(50),
    lifetime_value            NUMBER(18,2),
    last_modified_timestamp   TIMESTAMP_NTZ,
    load_timestamp            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system             VARCHAR(50) DEFAULT 'CRM',
    
    -- Constraints
    CONSTRAINT pk_bronze_customers PRIMARY KEY (customer_id)
)
DATA_RETENTION_TIME_IN_DAYS = 14
COMMENT = 'Bronze: Customer master data - as-is from source';

SELECT 'Table created: mtln_bronze_customers' AS status;

-- ============================================================================
-- TABLE 4: PRODUCTS
-- ============================================================================

CREATE OR REPLACE TRANSIENT TABLE mtln_bronze_products (
    product_id                VARCHAR(100) NOT NULL,
    sku                       VARCHAR(100),
    product_name              VARCHAR(255),
    category                  VARCHAR(100),
    subcategory               VARCHAR(100),
    brand                     VARCHAR(100),
    unit_price                NUMBER(18,2),
    cost                      NUMBER(18,2),
    margin                    NUMBER(18,2),
    margin_percent            NUMBER(10,4),
    product_status            VARCHAR(50),
    last_modified_timestamp   TIMESTAMP_NTZ,
    load_timestamp            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system             VARCHAR(50) DEFAULT 'ERP',
    
    -- Constraints
    CONSTRAINT pk_bronze_products PRIMARY KEY (product_id)
)
DATA_RETENTION_TIME_IN_DAYS = 14
COMMENT = 'Bronze: Product catalog - as-is from source';

SELECT 'Table created: mtln_bronze_products' AS status;

-- ============================================================================
-- TABLE 5: SALES
-- ============================================================================

CREATE OR REPLACE TRANSIENT TABLE mtln_bronze_sales (
    order_id                  VARCHAR(100) NOT NULL,
    order_line_id             VARCHAR(100) NOT NULL,
    customer_id               VARCHAR(100),
    product_id                VARCHAR(100),
    campaign_id               VARCHAR(100),
    order_date                DATE,
    order_timestamp           TIMESTAMP_NTZ,
    quantity                  NUMBER(10,0),
    unit_price                NUMBER(18,2),
    discount_amount           NUMBER(18,2),
    tax_amount                NUMBER(18,2),
    line_total                NUMBER(18,2),
    revenue                   NUMBER(18,2),
    last_modified_timestamp   TIMESTAMP_NTZ,
    load_timestamp            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system             VARCHAR(50) DEFAULT 'ECOMMERCE',
    
    -- Constraints
    CONSTRAINT pk_bronze_sales PRIMARY KEY (order_line_id)
)
DATA_RETENTION_TIME_IN_DAYS = 14
COMMENT = 'Bronze: Sales transactions - as-is from source';

SELECT 'Table created: mtln_bronze_sales' AS status;

-- ============================================================================
-- TABLE 6: PERFORMANCE
-- ============================================================================

CREATE OR REPLACE TRANSIENT TABLE mtln_bronze_performance (
    performance_id            VARCHAR(100) NOT NULL,
    campaign_id               VARCHAR(100),
    channel_id                VARCHAR(100),
    performance_date          DATE,
    impressions               NUMBER(18,0),
    clicks                    NUMBER(18,0),
    cost                      NUMBER(18,2),
    conversions               NUMBER(18,0),
    revenue                   NUMBER(18,2),
    last_modified_timestamp   TIMESTAMP_NTZ,
    load_timestamp            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_system             VARCHAR(50) DEFAULT 'AD_PLATFORM',
    
    -- Constraints
    CONSTRAINT pk_bronze_performance PRIMARY KEY (performance_id)
)
DATA_RETENTION_TIME_IN_DAYS = 14
COMMENT = 'Bronze: Marketing performance metrics - as-is from source';

SELECT 'Table created: mtln_bronze_performance' AS status;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT '========================================' AS summary;
SELECT 'BRONZE TABLES CREATED SUCCESSFULLY' AS summary;
SELECT '========================================' AS summary;

-- List all Bronze tables
SHOW TABLES IN SCHEMA BRONZE;

-- Verify table structures
SELECT 
    table_name,
    row_count,
    bytes,
    retention_time
FROM INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'BRONZE'
  AND table_name LIKE 'MTLN_BRONZE_%'
ORDER BY table_name;

SELECT '========================================' AS summary;
SELECT 'Next Step: Run sql/generate-sample-data.sql' AS summary;
SELECT '========================================' AS summary;

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================