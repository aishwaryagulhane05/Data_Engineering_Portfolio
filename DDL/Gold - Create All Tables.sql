-- ========================================
-- GOLD SCHEMA DDL
-- Medallion Architecture - Gold Layer
-- Purpose: Analytics-ready star schema
-- ========================================

USE DATABASE MATILLION_DB;
USE SCHEMA GOLD;

-- ========================================
-- DIMENSIONS (SCD Type 2 with History Tracking)
-- ========================================

-- ========================================
-- 1. DIM_CAMPAIGN (SCD Type 2)
-- Purpose: Marketing campaign dimension with full history
-- ========================================

CREATE OR REPLACE TABLE dim_campaign (
    -- Surrogate Key (Auto-increment for SCD)
    campaign_key            NUMBER(18,0)        IDENTITY(1,1) NOT NULL,
    
    -- Natural/Business Key
    campaign_id             VARCHAR(100)        NOT NULL,
    
    -- Descriptive Attributes
    campaign_name           VARCHAR(255)        NOT NULL,
    campaign_type           VARCHAR(100)        NOT NULL,
    status                  VARCHAR(50)         NOT NULL,
    objective               VARCHAR(255),
    start_date              DATE,
    end_date                DATE,
    budget                  NUMBER(18,2)        DEFAULT 0.00,
    duration_days           NUMBER(10,0),
    
    -- SCD Type 2 Columns
    valid_from              TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    valid_to                TIMESTAMP_NTZ       DEFAULT '9999-12-31 23:59:59'::TIMESTAMP_NTZ,
    is_current              BOOLEAN             NOT NULL DEFAULT TRUE,
    version_number          NUMBER(10,0)        NOT NULL DEFAULT 1,
    
    -- Audit Columns
    created_timestamp       TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp       TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    source_system           VARCHAR(50)         DEFAULT 'MARKETING_PLATFORM',
    
    -- Constraints
    CONSTRAINT pk_dim_campaign PRIMARY KEY (campaign_key),
    CONSTRAINT uq_dim_campaign_current UNIQUE (campaign_id, is_current)
)
COMMENT = 'Gold: Campaign dimension with SCD Type 2 for tracking budget/status changes';




-- ========================================
-- 2. DIM_CHANNEL (SCD Type 3)
-- Purpose: Marketing channel dimension with previous value tracking
-- ========================================

CREATE OR REPLACE TABLE dim_channel (
    -- Surrogate Key
    channel_key             NUMBER(18,0)        IDENTITY(1,1) NOT NULL,
    
    -- Natural/Business Key
    channel_id              VARCHAR(100)        NOT NULL,
    
    -- Current Attributes
    channel_name            VARCHAR(255)        NOT NULL,
    channel_type            VARCHAR(100)        NOT NULL,
    current_category        VARCHAR(100)        NOT NULL,
    cost_structure          VARCHAR(100),
    
    -- Previous Attributes (SCD Type 3)
    previous_category       VARCHAR(100),
    category_changed_date   TIMESTAMP_NTZ,
    
    -- Audit Columns
    created_timestamp       TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp       TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    source_system           VARCHAR(50)         DEFAULT 'MARKETING_PLATFORM',
    
    -- Constraints
    CONSTRAINT pk_dim_channel PRIMARY KEY (channel_key),
    CONSTRAINT uq_dim_channel_id UNIQUE (channel_id)
)
COMMENT = 'Gold: Channel dimension with SCD Type 3 for category change tracking';


-- ========================================
-- 3. DIM_CUSTOMER (SCD Type 2)
-- Purpose: Customer dimension with segment/tier history
-- ========================================

CREATE OR REPLACE TABLE dim_customer (
    -- Surrogate Key
    customer_key            NUMBER(18,0)        IDENTITY(1,1) NOT NULL,
    
    -- Natural/Business Key
    customer_id             VARCHAR(100)        NOT NULL,
    
    -- Descriptive Attributes
    customer_name           VARCHAR(255)        NOT NULL,
    email                   VARCHAR(255),
    phone                   VARCHAR(50),
    segment                 VARCHAR(100)        NOT NULL,
    tier                    VARCHAR(50),
    status                  VARCHAR(50)         NOT NULL,
    lifetime_value          NUMBER(18,2)        DEFAULT 0.00,
    
    -- Data Quality
    email_valid             BOOLEAN,
    phone_valid             BOOLEAN,
    
    -- SCD Type 2 Columns
    valid_from              TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    valid_to                TIMESTAMP_NTZ       DEFAULT '9999-12-31 23:59:59'::TIMESTAMP_NTZ,
    is_current              BOOLEAN             NOT NULL DEFAULT TRUE,
    version_number          NUMBER(10,0)        NOT NULL DEFAULT 1,
    
    -- Audit Columns
    created_timestamp       TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp       TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    source_system           VARCHAR(50)         DEFAULT 'CRM',
    
    -- Constraints
    CONSTRAINT pk_dim_customer PRIMARY KEY (customer_key),
    CONSTRAINT uq_dim_customer_current UNIQUE (customer_id, is_current)
)
COMMENT = 'Gold: Customer dimension with SCD Type 2 for tracking segment/tier changes';



-- ========================================
-- 4. DIM_PRODUCT (SCD Type 1)
-- Purpose: Product dimension - overwrite changes
-- ========================================

CREATE OR REPLACE TABLE dim_product (
    -- Surrogate Key
    product_key             NUMBER(18,0)        IDENTITY(1,1) NOT NULL,
    
    -- Natural/Business Key
    product_id              VARCHAR(100)        NOT NULL,
    
    -- Descriptive Attributes
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
    
    -- Audit Columns
    created_timestamp       TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp       TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    source_system           VARCHAR(50)         DEFAULT 'ERP',
    
    -- Constraints
    CONSTRAINT pk_dim_product PRIMARY KEY (product_key),
    CONSTRAINT uq_dim_product_id UNIQUE (product_id)
)
COMMENT = 'Gold: Product dimension with SCD Type 1 (overwrite changes)';


-- ========================================
-- 5. DIM_DATE (Pre-built Date Dimension)
-- Purpose: Standard date dimension for time-series analysis
-- ========================================

CREATE OR REPLACE TABLE dim_date (
    -- Surrogate Key
    date_key                NUMBER(8,0)         NOT NULL,  -- Format: YYYYMMDD
    
    -- Date Attributes
    date_value              DATE                NOT NULL,
    year                    NUMBER(4,0)         NOT NULL,
    quarter                 NUMBER(1,0)         NOT NULL,
    quarter_name            VARCHAR(10)         NOT NULL,  -- Q1, Q2, Q3, Q4
    month                   NUMBER(2,0)         NOT NULL,
    month_name              VARCHAR(20)         NOT NULL,  -- January, February, etc.
    month_short_name        VARCHAR(3)          NOT NULL,  -- Jan, Feb, etc.
    week_of_year            NUMBER(2,0)         NOT NULL,
    day_of_year             NUMBER(3,0)         NOT NULL,
    day_of_month            NUMBER(2,0)         NOT NULL,
    day_of_week             NUMBER(1,0)         NOT NULL,  -- 1=Monday, 7=Sunday
    day_name                VARCHAR(20)         NOT NULL,  -- Monday, Tuesday, etc.
    day_short_name          VARCHAR(3)          NOT NULL,  -- Mon, Tue, etc.
    
    -- Business Day Flags
    is_weekend              BOOLEAN             NOT NULL,
    is_holiday              BOOLEAN             DEFAULT FALSE,
    holiday_name            VARCHAR(100),
    
    -- Fiscal Attributes (optional)
    fiscal_year             NUMBER(4,0),
    fiscal_quarter          NUMBER(1,0),
    fiscal_month            NUMBER(2,0),
    
    -- Constraints
    CONSTRAINT pk_dim_date PRIMARY KEY (date_key),
    CONSTRAINT uq_dim_date_value UNIQUE (date_value)
)
COMMENT = 'Gold: Date dimension for time-series analysis (2020-2030)';


-- ========================================
-- FACT TABLES (Transactional Grain)
-- ========================================

-- ========================================
-- 6. FACT_PERFORMANCE (Daily Performance Metrics)
-- Grain: One row per campaign per channel per day
-- ========================================

CREATE OR REPLACE TABLE fact_performance (
    -- Surrogate Key
    performance_key         NUMBER(18,0)        IDENTITY(1,1) NOT NULL,
    
    -- Foreign Keys (Surrogate)
    campaign_key            NUMBER(18,0)        NOT NULL,
    channel_key             NUMBER(18,0)        NOT NULL,
    date_key                NUMBER(8,0)         NOT NULL,
    
    -- Degenerate Dimension (Natural Key from source)
    performance_id          VARCHAR(100)        NOT NULL,
    
    -- Additive Measures
    impressions             NUMBER(18,0)        DEFAULT 0,
    clicks                  NUMBER(18,0)        DEFAULT 0,
    conversions             NUMBER(18,0)        DEFAULT 0,
    cost                    NUMBER(18,2)        DEFAULT 0.00,
    revenue                 NUMBER(18,2)        DEFAULT 0.00,
    
    -- Semi-Additive Measures (Pre-calculated)
    ctr                     NUMBER(10,4),
    cpc                     NUMBER(18,4),
    cpa                     NUMBER(18,4),
    roas                    NUMBER(10,4),
    conversion_rate         NUMBER(10,4),
    
    -- Audit Columns
    load_timestamp          TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    source_system           VARCHAR(50)         DEFAULT 'AD_PLATFORM',
    
    -- Constraints
    CONSTRAINT pk_fact_performance PRIMARY KEY (performance_key),
    CONSTRAINT fk_fact_performance_campaign FOREIGN KEY (campaign_key) 
        REFERENCES dim_campaign(campaign_key),
    CONSTRAINT fk_fact_performance_channel FOREIGN KEY (channel_key) 
        REFERENCES dim_channel(channel_key),
    CONSTRAINT fk_fact_performance_date FOREIGN KEY (date_key) 
        REFERENCES dim_date(date_key)
)
CLUSTER BY (date_key, campaign_key)
COMMENT = 'Gold: Marketing performance fact table - daily grain';

-- ========================================
-- 7. FACT_SALES (Sales Transaction Details)
-- Grain: One row per order line
-- ========================================

CREATE OR REPLACE TABLE fact_sales (
    -- Surrogate Key
    sales_key               NUMBER(18,0)        IDENTITY(1,1) NOT NULL,
    
    -- Foreign Keys (Surrogate)
    customer_key            NUMBER(18,0)        NOT NULL,
    product_key             NUMBER(18,0)        NOT NULL,
    campaign_key            NUMBER(18,0),
    date_key                NUMBER(8,0)         NOT NULL,
    
    -- Degenerate Dimensions (Natural Keys from source)
    order_id                VARCHAR(100)        NOT NULL,
    order_line_id           VARCHAR(100)        NOT NULL,
    order_timestamp         TIMESTAMP_NTZ       NOT NULL,
    
    -- Additive Measures
    quantity                NUMBER(10,0)        DEFAULT 0,
    unit_price              NUMBER(18,2)        DEFAULT 0.00,
    discount_amount         NUMBER(18,2)        DEFAULT 0.00,
    tax_amount              NUMBER(18,2)        DEFAULT 0.00,
    line_total              NUMBER(18,2)        DEFAULT 0.00,
    revenue                 NUMBER(18,2)        DEFAULT 0.00,
    
    -- Non-Additive Measures
    discount_percent        NUMBER(10,4),
    
    -- Audit Columns
    load_timestamp          TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    source_system           VARCHAR(50)         DEFAULT 'ECOMMERCE',
    
    -- Constraints
    CONSTRAINT pk_fact_sales PRIMARY KEY (sales_key),
    CONSTRAINT fk_fact_sales_customer FOREIGN KEY (customer_key) 
        REFERENCES dim_customer(customer_key),
    CONSTRAINT fk_fact_sales_product FOREIGN KEY (product_key) 
        REFERENCES dim_product(product_key),
    CONSTRAINT fk_fact_sales_campaign FOREIGN KEY (campaign_key) 
        REFERENCES dim_campaign(campaign_key),
    CONSTRAINT fk_fact_sales_date FOREIGN KEY (date_key) 
        REFERENCES dim_date(date_key)
)
CLUSTER BY (date_key, customer_key)
COMMENT = 'Gold: Sales fact table - order line grain';


-- ========================================
-- AGGREGATE FACT TABLES (Pre-aggregated)
-- ========================================

-- ========================================
-- 8. FACT_CAMPAIGN_DAILY (Campaign Performance Summary)
-- Grain: One row per campaign per day
-- ========================================

CREATE OR REPLACE TABLE fact_campaign_daily (
    campaign_key            NUMBER(18,0)        NOT NULL,
    date_key                NUMBER(8,0)         NOT NULL,
    total_impressions       NUMBER(18,0)        DEFAULT 0,
    total_clicks            NUMBER(18,0)        DEFAULT 0,
    total_conversions       NUMBER(18,0)        DEFAULT 0,
    total_cost              NUMBER(18,2)        DEFAULT 0.00,
    total_revenue           NUMBER(18,2)        DEFAULT 0.00,
    avg_ctr                 NUMBER(10,4),
    avg_cpc                 NUMBER(18,4),
    total_roas              NUMBER(10,4),
    channel_count           NUMBER(10,0),
    load_timestamp          TIMESTAMP_NTZ       NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fact_campaign_daily PRIMARY KEY (campaign_key, date_key),
    CONSTRAINT fk_fact_campaign_daily_campaign FOREIGN KEY (campaign_key) 
        REFERENCES dim_campaign(campaign_key),
    CONSTRAINT fk_fact_campaign_daily_date FOREIGN KEY (date_key) 
        REFERENCES dim_date(date_key)
)
CLUSTER BY (date_key)
COMMENT = 'Gold: Pre-aggregated campaign performance by day';


-- ========================================
-- GOLD LAYER SCHEMA SUMMARY
-- ========================================
/*
STAR SCHEMA DESIGN:

DIMENSIONS:
- dim_campaign (SCD Type 2) - Budget/status changes tracked
- dim_channel (SCD Type 3) - Category change tracking
- dim_customer (SCD Type 2) - Segment/tier changes tracked
- dim_product (SCD Type 1) - Overwrite changes
- dim_date (Static) - Pre-built 2020-2030

FACTS:
- fact_performance (Daily grain) - Marketing metrics
- fact_sales (Order line grain) - Sales transactions
- fact_campaign_daily (Aggregated) - Campaign summary

KEY FEATURES:
1. Surrogate keys (IDENTITY) for all dimensions
2. Foreign key constraints for referential integrity
3. SCD Type 2 for tracking historical changes
4. Clustering keys on date + primary dimension
6. Degenerate dimensions in facts (order_id, performance_id)
7. Pre-calculated metrics for query performance

LOAD STRATEGY:
- Dimensions: Load from Silver with SCD logic
- Facts: Incremental with surrogate key lookups
- Date dimension: Pre-populated once (2020-2030)
*/