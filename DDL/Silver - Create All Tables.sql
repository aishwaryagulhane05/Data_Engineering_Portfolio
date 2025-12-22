USE DATABASE MATILLION_DB;
USE SCHEMA SILVER;

-- ========================================
-- SILVER SCHEMA DDL
-- Medallion Architecture - Silver Layer
-- Purpose: Cleansed, validated, and enriched data
-- ========================================

USE DATABASE MATILLION_DB;
USE SCHEMA SILVER;

-- ========================================
-- 1. CAMPAIGNS (Dimension - Small)
-- Load Strategy: FULL REFRESH
-- ========================================

CREATE OR REPLACE TABLE mtln_silver_campaigns (
    campaign_id             VARCHAR(100)        NOT NULL,
    campaign_name           VARCHAR(255)        NOT NULL,
    campaign_type           VARCHAR(100)        NOT NULL,
    status                  VARCHAR(50)         NOT NULL,
    objective               VARCHAR(255),
    start_date              DATE,
    end_date                DATE,
    budget                  NUMBER(18,2)        DEFAULT 0.00,
    duration_days           NUMBER(10,0),
    last_modified_timestamp TIMESTAMP_NTZ,
    load_timestamp          TIMESTAMP_NTZ       NOT NULL,
    source_system           VARCHAR(50)         DEFAULT 'MARKETING_PLATFORM',
    CONSTRAINT pk_silver_campaigns PRIMARY KEY (campaign_id)
)
COMMENT = 'Silver: Marketing campaigns with data cleansing and quality checks';


-- ========================================
-- 2. CHANNELS (Dimension - Small)
-- Load Strategy: FULL REFRESH
-- ========================================

CREATE OR REPLACE TABLE mtln_silver_channels (
    channel_id              VARCHAR(100)        NOT NULL,
    channel_name            VARCHAR(255)        NOT NULL,
    channel_type            VARCHAR(100)        NOT NULL,
    category                VARCHAR(100)        NOT NULL,
    cost_structure          VARCHAR(100),
    last_modified_timestamp TIMESTAMP_NTZ,
    load_timestamp          TIMESTAMP_NTZ       NOT NULL,
    source_system           VARCHAR(50)         DEFAULT 'MARKETING_PLATFORM',
    CONSTRAINT pk_silver_channels PRIMARY KEY (channel_id)
)
COMMENT = 'Silver: Marketing channels with data cleansing';


-- ========================================
-- 3. CUSTOMERS (Dimension - Medium)
-- Load Strategy: FULL REFRESH
-- ========================================

CREATE OR REPLACE TABLE mtln_silver_customers (
    customer_id             VARCHAR(100)        NOT NULL,
    customer_name           VARCHAR(255)        NOT NULL,
    email                   VARCHAR(255),
    phone                   VARCHAR(50),
    segment                 VARCHAR(100)        NOT NULL,
    tier                    VARCHAR(50),
    status                  VARCHAR(50)         NOT NULL,
    lifetime_value          NUMBER(18,2)        DEFAULT 0.00,
    email_valid             BOOLEAN,
    phone_valid             BOOLEAN,
    last_modified_timestamp TIMESTAMP_NTZ,
    load_timestamp          TIMESTAMP_NTZ       NOT NULL,
    source_system           VARCHAR(50)         DEFAULT 'CRM',
    CONSTRAINT pk_silver_customers PRIMARY KEY (customer_id)
)
COMMENT = 'Silver: Customer master data with data cleansing';


-- ========================================
-- 4. PRODUCTS (Dimension - Medium)
-- Load Strategy: FULL REFRESH
-- ========================================

CREATE OR REPLACE TABLE mtln_silver_products (
    product_id              VARCHAR(100)        NOT NULL,
    sku                     VARCHAR(100)        NOT NULL,
    product_name            VARCHAR(255)        NOT NULL,
    category                VARCHAR(100)        NOT NULL,
    subcategory             VARCHAR(100),
    brand                   VARCHAR(100),
    product_status          VARCHAR(50)         NOT NULL,
    unit_price              NUMBER(18,2)        DEFAULT 0.00,
    cost                    NUMBER(18,2)        DEFAULT 0.00,
    margin                  NUMBER(18,2),
    margin_percent          NUMBER(10,4),
    last_modified_timestamp TIMESTAMP_NTZ,
    load_timestamp          TIMESTAMP_NTZ       NOT NULL,
    source_system           VARCHAR(50)         DEFAULT 'ERP',
    CONSTRAINT pk_silver_products PRIMARY KEY (product_id)
)
COMMENT = 'Silver: Product catalog with calculated metrics';


-- ========================================
-- 5. PERFORMANCE (Fact - Large, Growing)
-- Load Strategy: INCREMENTAL
-- ========================================

CREATE OR REPLACE TABLE mtln_silver_performance (
    performance_id          VARCHAR(100)        NOT NULL,
    campaign_id             VARCHAR(100),
    channel_id              VARCHAR(100),
    performance_date        DATE                NOT NULL,
    impressions             NUMBER(18,0)        DEFAULT 0,
    clicks                  NUMBER(18,0)        DEFAULT 0,
    cost                    NUMBER(18,2)        DEFAULT 0.00,
    conversions             NUMBER(18,0)        DEFAULT 0,
    revenue                 NUMBER(18,2)        DEFAULT 0.00,
    ctr                     NUMBER(10,4),
    cpc                     NUMBER(18,4),
    cpa                     NUMBER(18,4),
    roas                    NUMBER(10,4),
    conversion_rate         NUMBER(10,4),
    clicks_valid            BOOLEAN,
    conversions_valid       BOOLEAN,
    last_modified_timestamp TIMESTAMP_NTZ,
    load_timestamp          TIMESTAMP_NTZ       NOT NULL,
    source_system           VARCHAR(50)         DEFAULT 'AD_PLATFORM',
    CONSTRAINT pk_silver_performance PRIMARY KEY (performance_id)
)
CLUSTER BY (performance_date)
COMMENT = 'Silver: Marketing performance with calculated KPIs';


-- ========================================
-- 6. SALES (Fact - Large, Growing)
-- Load Strategy: INCREMENTAL
-- ========================================

CREATE OR REPLACE TABLE mtln_silver_sales (
    order_line_id           VARCHAR(100)        NOT NULL,
    order_id                VARCHAR(100)        NOT NULL,
    customer_id             VARCHAR(100),
    product_id              VARCHAR(100),
    campaign_id             VARCHAR(100),
    order_date              DATE                NOT NULL,
    order_timestamp         TIMESTAMP_NTZ       NOT NULL,
    quantity                NUMBER(10,0)        DEFAULT 0,
    unit_price              NUMBER(18,2)        DEFAULT 0.00,
    discount_amount         NUMBER(18,2)        DEFAULT 0.00,
    tax_amount              NUMBER(18,2)        DEFAULT 0.00,
    line_total              NUMBER(18,2),
    revenue                 NUMBER(18,2),
    discount_percent        NUMBER(10,4),
    last_modified_timestamp TIMESTAMP_NTZ,
    load_timestamp          TIMESTAMP_NTZ       NOT NULL,
    source_system           VARCHAR(50)         DEFAULT 'ECOMMERCE',
    CONSTRAINT pk_silver_sales PRIMARY KEY (order_line_id)
)
CLUSTER BY (order_date)
COMMENT = 'Silver: Sales transactions with calculated metrics';