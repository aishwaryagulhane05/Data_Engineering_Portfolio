-- =====================================================
-- BRONZE LAYER - CREATE ALL TABLES
-- Purpose: Raw/Landing zone for source data (as-is)
-- =====================================================

USE DATABASE MATILLION_DB;
USE SCHEMA BRONZE;

-- =====================================================
-- TABLE: MTLN_BRONZE_CAMPAIGNS
-- =====================================================
CREATE OR REPLACE TABLE MTLN_BRONZE_CAMPAIGNS (
    RAW_DATA VARIANT,
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_SYSTEM VARCHAR(50) DEFAULT 'AD_PLATFORM'
)
COMMENT = 'Bronze: Marketing campaigns - as-is from source';

-- =====================================================
-- TABLE: MTLN_BRONZE_CHANNELS
-- =====================================================
CREATE OR REPLACE TABLE MTLN_BRONZE_CHANNELS (
    RAW_DATA VARIANT,
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_SYSTEM VARCHAR(50) DEFAULT 'AD_PLATFORM'
)
COMMENT = 'Bronze: Marketing channels - as-is from source';

-- =====================================================
-- TABLE: MTLN_BRONZE_CUSTOMERS
-- =====================================================
CREATE OR REPLACE TABLE MTLN_BRONZE_CUSTOMERS (
    RAW_DATA VARIANT,
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_SYSTEM VARCHAR(50) DEFAULT 'CRM'
)
COMMENT = 'Bronze: Customer master data - as-is from source';

-- =====================================================
-- TABLE: MTLN_BRONZE_PERFORMANCE
-- =====================================================
CREATE OR REPLACE TABLE MTLN_BRONZE_PERFORMANCE (
    RAW_DATA VARIANT,
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_SYSTEM VARCHAR(50) DEFAULT 'AD_PLATFORM'
)
COMMENT = 'Bronze: Marketing performance metrics - as-is from source';

-- =====================================================
-- TABLE: MTLN_BRONZE_PRODUCTS
-- =====================================================
CREATE OR REPLACE TABLE MTLN_BRONZE_PRODUCTS (
    RAW_DATA VARIANT,
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_SYSTEM VARCHAR(50) DEFAULT 'ERP'
)
COMMENT = 'Bronze: Product catalog - as-is from source';

-- =====================================================
-- TABLE: MTLN_BRONZE_SALES
-- =====================================================
CREATE OR REPLACE TABLE MTLN_BRONZE_SALES (
    RAW_DATA VARIANT,
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SOURCE_SYSTEM VARCHAR(50) DEFAULT 'ERP'
)
COMMENT = 'Bronze: Sales transactions - as-is from source';

-- =====================================================
-- VERIFICATION QUERY
-- =====================================================
SELECT TABLE_NAME, ROW_COUNT, COMMENT 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'BRONZE' 
AND TABLE_NAME LIKE 'MTLN_BRONZE_%'
ORDER BY TABLE_NAME;