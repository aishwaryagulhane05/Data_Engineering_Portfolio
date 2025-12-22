# Data Dictionary

Marketing Analytics Data Warehouse - Medallion Architecture

## Overview

This data dictionary documents all tables in the Marketing Analytics Data Warehouse built on Snowflake using Matillion.

**Architecture**: Medallion (Bronze → Silver → Gold)
**Total Tables**: 20 tables (6 Bronze + 6 Silver + 8 Gold)
**Database**: MATILLION_DB
**Last Updated**: 2025-12-22

---

## Table of Contents

1. [Bronze Layer (6 tables)](#bronze-layer)
2. [Silver Layer (6 tables)](#silver-layer)
3. [Gold Layer - Dimensions (5 tables)](#gold-dimensions)
4. [Gold Layer - Facts (3 tables)](#gold-facts)
5. [SCD Patterns](#scd-patterns)
6. [Relationships & Keys](#relationships)
7. [Load Strategies](#load-strategies)

---

## Bronze Layer

**Purpose**: Raw landing zone for immutable JSON data from source systems  
**Load Strategy**: Full Refresh  
**Schema**: BRONZE

### MTLN_BRONZE_CAMPAIGNS

**Row Count**: ~1,000  
**Source**: Marketing Platform

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| RAW_DATA | VARIANT | YES | NULL | Full JSON payload |
| LOAD_TIMESTAMP | TIMESTAMP_NTZ | NO | CURRENT_TIMESTAMP() | ETL load time |
| SOURCE_SYSTEM | VARCHAR(50) | NO | 'AD_PLATFORM' | Source identifier |

### MTLN_BRONZE_CHANNELS

**Row Count**: ~20  
**Source**: Marketing Platform

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| RAW_DATA | VARIANT | YES | NULL | Full JSON payload |
| LOAD_TIMESTAMP | TIMESTAMP_NTZ | NO | CURRENT_TIMESTAMP() | ETL load time |
| SOURCE_SYSTEM | VARCHAR(50) | NO | 'AD_PLATFORM' | Source identifier |

### MTLN_BRONZE_CUSTOMERS

**Row Count**: ~10,000  
**Source**: CRM System

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| RAW_DATA | VARIANT | YES | NULL | Full JSON payload |
| LOAD_TIMESTAMP | TIMESTAMP_NTZ | NO | CURRENT_TIMESTAMP() | ETL load time |
| SOURCE_SYSTEM | VARCHAR(50) | NO | 'CRM' | Source identifier |

### MTLN_BRONZE_PERFORMANCE

**Row Count**: ~50,000  
**Source**: Ad Platform

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| RAW_DATA | VARIANT | YES | NULL | Full JSON payload |
| LOAD_TIMESTAMP | TIMESTAMP_NTZ | NO | CURRENT_TIMESTAMP() | ETL load time |
| SOURCE_SYSTEM | VARCHAR(50) | NO | 'AD_PLATFORM' | Source identifier |

### MTLN_BRONZE_PRODUCTS

**Row Count**: ~2,000  
**Source**: ERP System

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| RAW_DATA | VARIANT | YES | NULL | Full JSON payload |
| LOAD_TIMESTAMP | TIMESTAMP_NTZ | NO | CURRENT_TIMESTAMP() | ETL load time |
| SOURCE_SYSTEM | VARCHAR(50) | NO | 'ERP' | Source identifier |

### MTLN_BRONZE_SALES

**Row Count**: ~200,000  
**Source**: E-commerce Platform

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| RAW_DATA | VARIANT | YES | NULL | Full JSON payload |
| LOAD_TIMESTAMP | TIMESTAMP_NTZ | NO | CURRENT_TIMESTAMP() | ETL load time |
| SOURCE_SYSTEM | VARCHAR(50) | NO | 'ERP' | Source identifier |

---

## Silver Layer

**Purpose**: Cleansed, validated, enriched relational data  
**Schema**: SILVER  
**Load Strategy**: Full Refresh (dimensions) + Incremental (facts)

### mtln_silver_campaigns

**Row Count**: ~1,000  
**Primary Key**: campaign_id  
**Load Strategy**: Full Refresh

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| campaign_id | VARCHAR(100) | NOT NULL | - | Unique campaign ID (PK) |
| campaign_name | VARCHAR(255) | NOT NULL | - | Campaign name |
| campaign_type | VARCHAR(100) | NOT NULL | - | Type (Email, Social, Display, Search) |
| status | VARCHAR(50) | NOT NULL | - | Active, Paused, Ended |
| objective | VARCHAR(255) | YES | NULL | Campaign objective |
| start_date | DATE | YES | NULL | Start date |
| end_date | DATE | YES | NULL | End date |
| budget | NUMBER(18,2) | NO | 0.00 | Campaign budget (USD) |
| duration_days | NUMBER(10,0) | YES | NULL | Calculated: end_date - start_date |
| last_modified_timestamp | TIMESTAMP_NTZ | YES | NULL | Source timestamp |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | - | ETL load timestamp |
| source_system | VARCHAR(50) | NO | 'MARKETING_PLATFORM' | Source system |

### mtln_silver_channels

**Row Count**: ~20  
**Primary Key**: channel_id  
**Load Strategy**: Full Refresh

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| channel_id | VARCHAR(100) | NOT NULL | - | Unique channel ID (PK) |
| channel_name | VARCHAR(255) | NOT NULL | - | Channel name |
| channel_type | VARCHAR(100) | NOT NULL | - | Paid, Organic, Direct |
| category | VARCHAR(100) | NOT NULL | - | Social, Search, Email, Display |
| cost_structure | VARCHAR(100) | YES | NULL | CPC, CPM, Fixed, Free |
| last_modified_timestamp | TIMESTAMP_NTZ | YES | NULL | Source timestamp |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | - | ETL load timestamp |
| source_system | VARCHAR(50) | NO | 'MARKETING_PLATFORM' | Source system |

### mtln_silver_customers

**Row Count**: ~10,000  
**Primary Key**: customer_id  
**Load Strategy**: Full Refresh

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| customer_id | VARCHAR(100) | NOT NULL | - | Unique customer ID (PK) |
| customer_name | VARCHAR(255) | NOT NULL | - | Customer name |
| email | VARCHAR(255) | YES | NULL | Email address |
| phone | VARCHAR(50) | YES | NULL | Phone number |
| segment | VARCHAR(100) | NOT NULL | - | Enterprise, SMB, Retail, Consumer |
| tier | VARCHAR(50) | YES | NULL | Gold, Silver, Bronze, Standard |
| status | VARCHAR(50) | NOT NULL | - | Active, Inactive, Churned |
| lifetime_value | NUMBER(18,2) | NO | 0.00 | Lifetime value (USD) |
| email_valid | BOOLEAN | YES | NULL | Email format validation |
| phone_valid | BOOLEAN | YES | NULL | Phone format validation |
| last_modified_timestamp | TIMESTAMP_NTZ | YES | NULL | Source timestamp |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | - | ETL load timestamp |
| source_system | VARCHAR(50) | NO | 'CRM' | Source system |

### mtln_silver_products

**Row Count**: ~2,000  
**Primary Key**: product_id  
**Load Strategy**: Full Refresh

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| product_id | VARCHAR(100) | NOT NULL | - | Unique product ID (PK) |
| sku | VARCHAR(100) | NOT NULL | - | Stock keeping unit |
| product_name | VARCHAR(255) | NOT NULL | - | Product name |
| category | VARCHAR(100) | NOT NULL | - | Product category |
| subcategory | VARCHAR(100) | YES | NULL | Product subcategory |
| brand | VARCHAR(100) | YES | NULL | Brand name |
| product_status | VARCHAR(50) | NOT NULL | - | Active, Discontinued, EOL |
| unit_price | NUMBER(18,2) | NO | 0.00 | Selling price |
| cost | NUMBER(18,2) | NO | 0.00 | Cost price |
| margin | NUMBER(18,2) | YES | NULL | Calc: unit_price - cost |
| margin_percent | NUMBER(10,4) | YES | NULL | Calc: (margin/unit_price)*100 |
| last_modified_timestamp | TIMESTAMP_NTZ | YES | NULL | Source timestamp |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | - | ETL load timestamp |
| source_system | VARCHAR(50) | NO | 'ERP' | Source system |

### mtln_silver_performance

**Row Count**: ~50,000+ (growing)  
**Primary Key**: performance_id  
**Load Strategy**: Incremental (watermark-based)  
**Clustering**: performance_date

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| performance_id | VARCHAR(100) | NOT NULL | - | Unique performance ID (PK) |
| campaign_id | VARCHAR(100) | YES | NULL | FK to campaigns |
| channel_id | VARCHAR(100) | YES | NULL | FK to channels |
| performance_date | DATE | NOT NULL | - | Metrics date |
| impressions | NUMBER(18,0) | NO | 0 | Ad impressions |
| clicks | NUMBER(18,0) | NO | 0 | Clicks |
| cost | NUMBER(18,2) | NO | 0.00 | Total cost (USD) |
| conversions | NUMBER(18,0) | NO | 0 | Conversions |
| revenue | NUMBER(18,2) | NO | 0.00 | Revenue (USD) |
| ctr | NUMBER(10,4) | YES | NULL | Calc: (clicks/impressions)*100 |
| cpc | NUMBER(18,4) | YES | NULL | Calc: cost/clicks |
| cpa | NUMBER(18,4) | YES | NULL | Calc: cost/conversions |
| roas | NUMBER(10,4) | YES | NULL | Calc: revenue/cost |
| conversion_rate | NUMBER(10,4) | YES | NULL | Calc: (conversions/clicks)*100 |
| clicks_valid | BOOLEAN | YES | NULL | Validation: clicks <= impressions |
| conversions_valid | BOOLEAN | YES | NULL | Validation: conversions <= clicks |
| last_modified_timestamp | TIMESTAMP_NTZ | YES | NULL | Source timestamp |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | - | ETL load timestamp (watermark) |
| source_system | VARCHAR(50) | NO | 'AD_PLATFORM' | Source system |

**Incremental Logic**: `WHERE performance_date > (SELECT MAX(load_timestamp) FROM target)`

### mtln_silver_sales

**Row Count**: ~200,000+ (growing)  
**Primary Key**: order_line_id  
**Load Strategy**: Incremental (watermark-based)  
**Clustering**: order_date

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| order_line_id | VARCHAR(100) | NOT NULL | - | Unique order line ID (PK) |
| order_id | VARCHAR(100) | NOT NULL | - | Order ID (multiple lines) |
| customer_id | VARCHAR(100) | YES | NULL | FK to customers |
| product_id | VARCHAR(100) | YES | NULL | FK to products |
| campaign_id | VARCHAR(100) | YES | NULL | FK to campaigns |
| order_date | DATE | NOT NULL | - | Order date |
| order_timestamp | TIMESTAMP_NTZ | NOT NULL | - | Exact order time |
| quantity | NUMBER(10,0) | NO | 0 | Order quantity |
| unit_price | NUMBER(18,2) | NO | 0.00 | Price per unit |
| discount_amount | NUMBER(18,2) | NO | 0.00 | Discount (USD) |
| tax_amount | NUMBER(18,2) | NO | 0.00 | Tax (USD) |
| line_total | NUMBER(18,2) | YES | NULL | Calc: (qty*price)-discount+tax |
| revenue | NUMBER(18,2) | YES | NULL | Same as line_total |
| discount_percent | NUMBER(10,4) | YES | NULL | Calc: (discount/(qty*price))*100 |
| last_modified_timestamp | TIMESTAMP_NTZ | YES | NULL | Source timestamp |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | - | ETL load timestamp (watermark) |
| source_system | VARCHAR(50) | NO | 'ECOMMERCE' | Source system |

**Incremental Logic**: `WHERE order_date > (SELECT MAX(load_timestamp) FROM target)`

---

## Gold Dimensions

**Purpose**: Analytics-ready dimension tables with SCD patterns  
**Schema**: GOLD

### dim_campaign (SCD Type 2)

**Row Count**: ~1,200 (with versions)  
**Primary Key**: campaign_key (surrogate)  
**Natural Key**: campaign_id  
**Unique Constraint**: (campaign_id, is_current)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| campaign_key | NUMBER(18,0) | NOT NULL | IDENTITY(1,1) | Surrogate key (PK) |
| campaign_id | VARCHAR(100) | NOT NULL | - | Natural business key |
| campaign_name | VARCHAR(255) | NOT NULL | - | Campaign name |
| campaign_type | VARCHAR(100) | NOT NULL | - | Campaign type |
| status | VARCHAR(50) | NOT NULL | - | **Tracked**: Active, Paused, Ended |
| objective | VARCHAR(255) | YES | NULL | Campaign objective |
| start_date | DATE | YES | NULL | Start date |
| end_date | DATE | YES | NULL | End date |
| budget | NUMBER(18,2) | NO | 0.00 | **Tracked**: Campaign budget |
| duration_days | NUMBER(10,0) | YES | NULL | Calculated duration |
| valid_from | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | **SCD**: Validity start |
| valid_to | TIMESTAMP_NTZ | NO | '9999-12-31' | **SCD**: Validity end |
| is_current | BOOLEAN | NOT NULL | TRUE | **SCD**: Current version flag |
| version_number | NUMBER(10,0) | NOT NULL | 1 | **SCD**: Version counter |
| created_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | Record creation |
| updated_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | Last update |
| source_system | VARCHAR(50) | NO | 'MARKETING_PLATFORM' | Source system |

**SCD Logic**: New version when budget OR status changes

### dim_channel (SCD Type 3)

**Row Count**: ~20  
**Primary Key**: channel_key (surrogate)  
**Natural Key**: channel_id

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| channel_key | NUMBER(18,0) | NOT NULL | IDENTITY(1,1) | Surrogate key (PK) |
| channel_id | VARCHAR(100) | NOT NULL | - | Natural business key |
| channel_name | VARCHAR(255) | NOT NULL | - | Channel name |
| channel_type | VARCHAR(100) | NOT NULL | - | Channel type |
| current_category | VARCHAR(100) | NOT NULL | - | **Current**: Current category |
| cost_structure | VARCHAR(100) | YES | NULL | Cost structure |
| previous_category | VARCHAR(100) | YES | NULL | **SCD3**: Previous category |
| category_changed_date | TIMESTAMP_NTZ | YES | NULL | **SCD3**: Change timestamp |
| created_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | Record creation |
| updated_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | Last update |
| source_system | VARCHAR(50) | NO | 'MARKETING_PLATFORM' | Source system |

**SCD Logic**: Current moved to previous, new value in current (in-place update)

### dim_customer (SCD Type 2)

**Row Count**: ~12,000 (with versions)  
**Primary Key**: customer_key (surrogate)  
**Natural Key**: customer_id  
**Unique Constraint**: (customer_id, is_current)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| customer_key | NUMBER(18,0) | NOT NULL | IDENTITY(1,1) | Surrogate key (PK) |
| customer_id | VARCHAR(100) | NOT NULL | - | Natural business key |
| customer_name | VARCHAR(255) | NOT NULL | - | Customer name |
| email | VARCHAR(255) | YES | NULL | Email address |
| phone | VARCHAR(50) | YES | NULL | Phone number |
| segment | VARCHAR(100) | NOT NULL | - | **Tracked**: Customer segment |
| tier | VARCHAR(50) | YES | NULL | **Tracked**: Customer tier |
| status | VARCHAR(50) | NOT NULL | - | Customer status |
| lifetime_value | NUMBER(18,2) | NO | 0.00 | Lifetime value |
| email_valid | BOOLEAN | YES | NULL | Email validation |
| phone_valid | BOOLEAN | YES | NULL | Phone validation |
| valid_from | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | **SCD**: Validity start |
| valid_to | TIMESTAMP_NTZ | NO | '9999-12-31' | **SCD**: Validity end |
| is_current | BOOLEAN | NOT NULL | TRUE | **SCD**: Current version flag |
| version_number | NUMBER(10,0) | NOT NULL | 1 | **SCD**: Version counter |
| created_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | Record creation |
| updated_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | Last update |
| source_system | VARCHAR(50) | NO | 'CRM' | Source system |

**SCD Logic**: New version when segment OR tier changes

### dim_product (SCD Type 1)

**Row Count**: ~2,000  
**Primary Key**: product_key (surrogate)  
**Natural Key**: product_id

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| product_key | NUMBER(18,0) | NOT NULL | IDENTITY(1,1) | Surrogate key (PK) |
| product_id | VARCHAR(100) | NOT NULL | - | Natural business key |
| sku | VARCHAR(100) | NOT NULL | - | Stock keeping unit |
| product_name | VARCHAR(255) | NOT NULL | - | Product name |
| category | VARCHAR(100) | NOT NULL | - | Product category |
| subcategory | VARCHAR(100) | YES | NULL | Product subcategory |
| brand | VARCHAR(100) | YES | NULL | Brand name |
| product_status | VARCHAR(50) | NOT NULL | - | Product status |
| unit_price | NUMBER(18,2) | NO | 0.00 | Unit price |
| cost | NUMBER(18,2) | NO | 0.00 | Unit cost |
| margin | NUMBER(18,2) | YES | NULL | Calculated margin |
| margin_percent | NUMBER(10,4) | YES | NULL | Margin percentage |
| created_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | Record creation |
| updated_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | Last update |
| source_system | VARCHAR(50) | NO | 'ERP' | Source system |

**SCD Logic**: In-place UPDATE (MERGE), no history

### dim_date (Static)

**Row Count**: 4,018 (2020-01-01 to 2030-12-31)  
**Primary Key**: date_key  
**Natural Key**: date_value

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| date_key | NUMBER(8,0) | NOT NULL | - | Surrogate key (YYYYMMDD format) |
| date_value | DATE | NOT NULL | - | Actual date |
| year | NUMBER(4,0) | NOT NULL | - | Year (2025) |
| quarter | NUMBER(1,0) | NOT NULL | - | Quarter (1-4) |
| quarter_name | VARCHAR(10) | NOT NULL | - | Q1, Q2, Q3, Q4 |
| month | NUMBER(2,0) | NOT NULL | - | Month (1-12) |
| month_name | VARCHAR(20) | NOT NULL | - | January, February, etc. |
| month_short_name | VARCHAR(3) | NOT NULL | - | Jan, Feb, etc. |
| week_of_year | NUMBER(2,0) | NOT NULL | - | Week (1-53) |
| day_of_year | NUMBER(3,0) | NOT NULL | - | Day (1-366) |
| day_of_month | NUMBER(2,0) | NOT NULL | - | Day (1-31) |
| day_of_week | NUMBER(1,0) | NOT NULL | - | 1=Monday, 7=Sunday |
| day_name | VARCHAR(20) | NOT NULL | - | Monday, Tuesday, etc. |
| day_short_name | VARCHAR(3) | NOT NULL | - | Mon, Tue, etc. |
| is_weekend | BOOLEAN | NOT NULL | - | Weekend flag |
| is_holiday | BOOLEAN | NO | FALSE | Holiday flag (optional) |
| holiday_name | VARCHAR(100) | YES | NULL | Holiday name (optional) |
| fiscal_year | NUMBER(4,0) | YES | NULL | Fiscal year (optional) |
| fiscal_quarter | NUMBER(1,0) | YES | NULL | Fiscal quarter (optional) |
| fiscal_month | NUMBER(2,0) | YES | NULL | Fiscal month (optional) |

**Generation**: Pre-populated using Calculator component

---

## Gold Facts

**Purpose**: Analytics-ready fact tables with additive measures  
**Schema**: GOLD

### fact_performance

**Row Count**: ~50,000+ (growing)  
**Grain**: One row per campaign per channel per day  
**Primary Key**: performance_key (surrogate)  
**Foreign Keys**: campaign_key, channel_key, date_key  
**Clustering**: (date_key, campaign_key)

| Column | Type | Nullable | Default | Measure Type | Description |
|--------|------|----------|---------|--------------|-------------|
| performance_key | NUMBER(18,0) | NOT NULL | IDENTITY(1,1) | - | Surrogate key (PK) |
| campaign_key | NUMBER(18,0) | NOT NULL | - | - | FK → dim_campaign |
| channel_key | NUMBER(18,0) | NOT NULL | - | - | FK → dim_channel |
| date_key | NUMBER(8,0) | NOT NULL | - | - | FK → dim_date |
| performance_id | VARCHAR(100) | NOT NULL | - | - | Degenerate dimension |
| impressions | NUMBER(18,0) | NO | 0 | **Additive** | Total impressions |
| clicks | NUMBER(18,0) | NO | 0 | **Additive** | Total clicks |
| conversions | NUMBER(18,0) | NO | 0 | **Additive** | Total conversions |
| cost | NUMBER(18,2) | NO | 0.00 | **Additive** | Total cost (USD) |
| revenue | NUMBER(18,2) | NO | 0.00 | **Additive** | Total revenue (USD) |
| ctr | NUMBER(10,4) | YES | NULL | **Semi-Additive** | Click-through rate (%) |
| cpc | NUMBER(18,4) | YES | NULL | **Semi-Additive** | Cost per click |
| cpa | NUMBER(18,4) | YES | NULL | **Semi-Additive** | Cost per acquisition |
| roas | NUMBER(10,4) | YES | NULL | **Semi-Additive** | Return on ad spend |
| conversion_rate | NUMBER(10,4) | YES | NULL | **Semi-Additive** | Conversion rate (%) |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | - | ETL load timestamp |
| source_system | VARCHAR(50) | NO | 'AD_PLATFORM' | - | Source system |

**Foreign Keys**:
```sql
CONSTRAINT fk_fact_performance_campaign FOREIGN KEY (campaign_key) 
    REFERENCES dim_campaign(campaign_key)
CONSTRAINT fk_fact_performance_channel FOREIGN KEY (channel_key) 
    REFERENCES dim_channel(channel_key)
CONSTRAINT fk_fact_performance_date FOREIGN KEY (date_key) 
    REFERENCES dim_date(date_key)
```

### fact_sales

**Row Count**: ~200,000+ (growing)  
**Grain**: One row per order line  
**Primary Key**: sales_key (surrogate)  
**Foreign Keys**: customer_key, product_key, campaign_key, date_key  
**Clustering**: (date_key, customer_key)

| Column | Type | Nullable | Default | Measure Type | Description |
|--------|------|----------|---------|--------------|-------------|
| sales_key | NUMBER(18,0) | NOT NULL | IDENTITY(1,1) | - | Surrogate key (PK) |
| customer_key | NUMBER(18,0) | NOT NULL | - | - | FK → dim_customer |
| product_key | NUMBER(18,0) | NOT NULL | - | - | FK → dim_product |
| campaign_key | NUMBER(18,0) | YES | NULL | - | FK → dim_campaign (nullable) |
| date_key | NUMBER(8,0) | NOT NULL | - | - | FK → dim_date |
| order_id | VARCHAR(100) | NOT NULL | - | - | Degenerate dimension |
| order_line_id | VARCHAR(100) | NOT NULL | - | - | Degenerate dimension |
| order_timestamp | TIMESTAMP_NTZ | NOT NULL | - | - | Exact order time |
| quantity | NUMBER(10,0) | NO | 0 | **Additive** | Order quantity |
| unit_price | NUMBER(18,2) | NO | 0.00 | **Non-Additive** | Price per unit |
| discount_amount | NUMBER(18,2) | NO | 0.00 | **Additive** | Total discount |
| tax_amount | NUMBER(18,2) | NO | 0.00 | **Additive** | Total tax |
| line_total | NUMBER(18,2) | NO | 0.00 | **Additive** | Line total |
| revenue | NUMBER(18,2) | NO | 0.00 | **Additive** | Revenue |
| discount_percent | NUMBER(10,4) | YES | NULL | **Non-Additive** | Discount percentage |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | - | ETL load timestamp |
| source_system | VARCHAR(50) | NO | 'ECOMMERCE' | - | Source system |

**Foreign Keys**:
```sql
CONSTRAINT fk_fact_sales_customer FOREIGN KEY (customer_key) 
    REFERENCES dim_customer(customer_key)
CONSTRAINT fk_fact_sales_product FOREIGN KEY (product_key) 
    REFERENCES dim_product(product_key)
CONSTRAINT fk_fact_sales_campaign FOREIGN KEY (campaign_key) 
    REFERENCES dim_campaign(campaign_key)
CONSTRAINT fk_fact_sales_date FOREIGN KEY (date_key) 
    REFERENCES dim_date(date_key)
```

### fact_campaign_daily (Pre-Aggregated)

**Row Count**: ~365+ (growing)  
**Grain**: One row per campaign per day  
**Primary Key**: (campaign_key, date_key) composite  
**Foreign Keys**: campaign_key, date_key  
**Clustering**: date_key

| Column | Type | Nullable | Default | Measure Type | Description |
|--------|------|----------|---------|--------------|-------------|
| campaign_key | NUMBER(18,0) | NOT NULL | - | - | FK → dim_campaign (PK) |
| date_key | NUMBER(8,0) | NOT NULL | - | - | FK → dim_date (PK) |
| total_impressions | NUMBER(18,0) | NO | 0 | **Additive** | Sum of impressions |
| total_clicks | NUMBER(18,0) | NO | 0 | **Additive** | Sum of clicks |
| total_conversions | NUMBER(18,0) | NO | 0 | **Additive** | Sum of conversions |
| total_cost | NUMBER(18,2) | NO | 0.00 | **Additive** | Sum of cost |
| total_revenue | NUMBER(18,2) | NO | 0.00 | **Additive** | Sum of revenue |
| avg_ctr | NUMBER(10,4) | YES | NULL | **Calculated** | Average CTR |
| avg_cpc | NUMBER(18,4) | YES | NULL | **Calculated** | Average CPC |
| total_roas | NUMBER(10,4) | YES | NULL | **Calculated** | Total ROAS |
| channel_count | NUMBER(10,0) | YES | NULL | **Count** | Number of channels |
| load_timestamp | TIMESTAMP_NTZ | NOT NULL | CURRENT_TIMESTAMP() | - | ETL load timestamp |

**Foreign Keys**:
```sql
CONSTRAINT pk_fact_campaign_daily PRIMARY KEY (campaign_key, date_key)
CONSTRAINT fk_fact_campaign_daily_campaign FOREIGN KEY (campaign_key) 
    REFERENCES dim_campaign(campaign_key)
CONSTRAINT fk_fact_campaign_daily_date FOREIGN KEY (date_key) 
    REFERENCES dim_date(date_key)
```

---

## SCD Patterns

| Dimension | SCD Type | Tracked Attributes | Implementation |
|-----------|----------|-------------------|----------------|
| dim_campaign | Type 2 | budget, status | Rewrite Table: New version on change, is_current flag |
| dim_channel | Type 3 | category | Rewrite Table: Previous value stored in column |
| dim_customer | Type 2 | segment, tier | Rewrite Table: New version on change, is_current flag |
| dim_product | Type 1 | All attributes | Table Update: In-place MERGE, no history |
| dim_date | Static | None | Pre-populated, no updates |

---

## Relationships

### Star Schema

**fact_performance** relationships:
- campaign_key → dim_campaign.campaign_key
- channel_key → dim_channel.channel_key
- date_key → dim_date.date_key

**fact_sales** relationships:
- customer_key → dim_customer.customer_key
- product_key → dim_product.product_key
- campaign_key → dim_campaign.campaign_key (nullable)
- date_key → dim_date.date_key

**fact_campaign_daily** relationships:
- campaign_key → dim_campaign.campaign_key
- date_key → dim_date.date_key

### Referential Integrity

All foreign keys enforced with FOREIGN KEY constraints. Prevents orphaned fact records.

---

## Load Strategies

### Bronze Layer
- **All tables**: Full Refresh
- **Purpose**: Immutable JSON landing zone

### Silver Layer
- **Full Refresh** (< 5 min): campaigns, channels, customers, products
- **Incremental** (97% faster): performance, sales
- **Watermark**: `load_timestamp` column

### Gold Dimensions
- **SCD Type 1** (product): Table Update (MERGE)
- **SCD Type 2** (campaign, customer): Rewrite Table with versioning
- **SCD Type 3** (channel): Rewrite Table with previous column
- **Static** (date): Pre-populated once

### Gold Facts
- **Incremental**: performance, sales, campaign_daily
- **Method**: Surrogate key lookups + watermark

---

## Performance Optimizations

### Clustering Keys
- **fact_performance**: `CLUSTER BY (date_key, campaign_key)` → 50-80% faster queries
- **fact_sales**: `CLUSTER BY (date_key, customer_key)` → 50-80% faster queries  
- **fact_campaign_daily**: `CLUSTER BY (date_key)` → Optimized for time-series
- **mtln_silver_performance**: `CLUSTER BY (performance_date)`
- **mtln_silver_sales**: `CLUSTER BY (order_date)`

### Surrogate Keys
- All dimensions use **IDENTITY(1,1)** auto-increment
- Faster joins than VARCHAR natural keys
- Supports SCD versioning

### Foreign Key Constraints
- Enforced referential integrity
- Query optimizer benefits
- Prevents data quality issues

---

**End of Data Dictionary**  
**Version**: 1.0  
**Last Updated**: 2025-12-22