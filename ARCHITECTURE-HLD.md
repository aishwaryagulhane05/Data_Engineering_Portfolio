# Architecture High-Level Design (HLD)
# Marketing Analytics Data Warehouse

**Project:** Multi-Source Marketing & Sales Analytics Platform  
**Architecture Pattern:** Medallion (Bronze → Silver → Gold)  
**Platform:** Matillion + Snowflake  
**Version:** 1.0  
**Date:** 2025-12-21  
**Status:** Design Complete

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Business Context](#2-business-context)
3. [Architecture Overview](#3-architecture-overview)
4. [Dimensional Model](#4-dimensional-model)
5. [Key Design Decisions](#5-key-design-decisions)
6. [Analytics Capabilities](#6-analytics-capabilities)
7. [Operations](#7-operations)
8. [Next Steps](#8-next-steps)

---

## 1. Executive Summary

### Business Problem

Organizations struggle with:
- ✗ Fragmented data across 6+ systems  
- ✗ 7+ day decision latency
- ✗ Inconsistent metrics between teams
- ✗ Poor ad spend ROI visibility
- ✗ Unable to optimize campaigns effectively

### Solution

Unified marketing analytics data warehouse:
- ✓ Single source of truth (6 integrated sources)
- ✓ Sub-30-second query response
- ✓ 85% faster insights (7 days → < 1 day)
- ✓ 25% ROAS improvement (2.8:1 → 3.5:1)
- ✓ Self-service analytics for 50+ users

### ROI

**Annual Benefits:** $525K  
- Time savings: $250K
- ROAS improvement: $200K
- Faster decisions: $75K

**Annual Costs:** $130K  
- Snowflake: $30K
- Matillion: $50K
- Maintenance: $50K

**Net ROI: $395K/year (304% return, 3.9-month payback)**

### Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Design | 2 weeks | ✅ Complete |
| Development | 4 weeks | 🔄 In Progress |
| Testing | 1 week | ⏳ Pending |
| Deployment | 3 hours | ⏳ Pending |

---

## 2. Business Context

### 2.1 Objectives

1. **Improve Ad Channel ROI** - Identify best-performing channels
2. **Enhance Customer Segmentation** - Target right customers
3. **Accelerate Decision-Making** - From days to hours
4. **Democratize Data** - Self-service for 50+ users

### 2.2 Key Use Cases

#### **Use Case 1: Ad Channel Analysis**
*"Which channels deliver best ROI?"*

**Insight Example:**
- Email campaigns: 5.2:1 ROAS (best)
- Display ads: 1.8:1 ROAS (underperforming)
- **Action:** Shift 20% budget email → +$50K revenue

#### **Use Case 2: Customer Segmentation**
*"Which segments should I target?"*

**Insight Example:**
- "Champions" (recent, frequent): 45% conversion
- "At Risk" (inactive 180+ days): 5% conversion
- **Action:** Target Champions → $100K opportunity

#### **Use Case 3: Campaign Tracking**
*"Is my campaign on track?"*

**Insight Example:**
- Day 7: 15% budget spent, 12% target achieved
- **Action:** Increase daily spend 20%

### 2.3 Success Criteria

**Technical:**
- ✅ Pipeline success > 99%
- ✅ Data freshness < 24 hours
- ✅ Query response < 30 seconds

**Business:**
- ✅ 50+ active users
- ✅ 10%+ ROAS improvement
- ✅ 90% user satisfaction

---

## 3. Architecture Overview

### 3.1 Medallion Pattern

```
┌─────────────────────────────────────────────────────┐
│ SOURCE SYSTEMS                                      │
│ • Marketing Platform  • CRM  • ERP                  │
│ • E-commerce  • Ad Platforms  • Analytics           │
└────────────────────┬────────────────────────────────┘
                     │ (Parquet files)
                     ▼
┌─────────────────────────────────────────────────────┐
│ 🗃️ RAW LAYER - Internal Stages                     │
│ 6 stages for file landing                           │
│ Retention: 7 days                                   │
└────────────────────┬────────────────────────────────┘
                     │ (Load)
                     ▼
┌─────────────────────────────────────────────────────┐
│ 🥉 BRONZE LAYER - Raw Relational                    │
│ 6 tables, as-is from source                         │
│ Retention: 14 days                                  │
└────────────────────┬────────────────────────────────┘
                     │ (Cleanse + Dedupe)
                     ▼
┌─────────────────────────────────────────────────────┐
│ 🥈 SILVER LAYER - Operational Data Store (ODS)      │
│ 6 tables with surrogate keys                        │
│ Retention: 30 days                                  │
└────────────────────┬────────────────────────────────┘
                     │ (Star Schema Views)
                     ▼
┌─────────────────────────────────────────────────────┐
│ 🥇 GOLD LAYER - Analytical Star Schema              │
│ 5 dimensions + 2 facts (views)                      │
│ No retention (views read from ODS)                  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│ 📊 BI & ANALYTICS TOOLS                             │
│ Tableau, Power BI, SQL Clients                      │
└─────────────────────────────────────────────────────┘
```

### 3.2 Layer Philosophy

| Layer | Purpose | Quality | Users |
|-------|---------|---------|-------|
| **RAW** | File staging | Raw files | System |
| **BRONZE** | Relational copy | May have duplicates | Engineers |
| **SILVER/ODS** | Clean operational | Validated, deduplicated | Engineers, Analysts |
| **GOLD** | Analytics-ready | Production-grade | Business Users |

### 3.3 Data Entities (6)

1. **Campaigns** - Marketing campaign master
2. **Customers** - Customer demographics & segments
3. **Products** - Product catalog with pricing
4. **Sales** - Transaction fact
5. **Performance** - Ad metrics fact
6. **Channels** - Marketing channel reference
7. **Date** - Calendar dimension (generated)

### 3.4 Technology Stack

| Component | Technology | Purpose |
|-----------|------------|--------|
| **Data Warehouse** | Snowflake | Storage & compute |
| **ETL/ELT** | Matillion | Pipeline development |
| **File Format** | Parquet | Efficient columnar storage |
| **Version Control** | Git | Pipeline versioning |
| **BI Tools** | Tableau/Power BI | Visualization (Phase 2) |

---

## 4. Dimensional Model

### 4.1 Star Schema Overview

```
           DIM_CUSTOMER
                │
                │
  DIM_DATE ───┼─── FACT_SALES ─── DIM_PRODUCT
                │
                │
           DIM_CAMPAIGN


        DIM_CHANNEL
             │
             │
  DIM_DATE ──┴── FACT_PERFORMANCE
```

### 4.2 Dimensions (5)

| Dimension | Natural Key | Attributes | SCD Type |
|-----------|-------------|------------|----------|
| **DIM_CAMPAIGN** | campaign_id | name, type, budget, dates | Type 1 |
| **DIM_CUSTOMER** | customer_id | name, email, segment, tier | Type 1 |
| **DIM_PRODUCT** | product_id | name, category, price, margin | Type 1 |
| **DIM_CHANNEL** | channel_id | name, type, category | Type 1 |
| **DIM_DATE** | date_key | year, quarter, month, week | Static |

### 4.3 Facts (2)

#### **FACT_SALES** (Transactional)
**Grain:** One row per order line item

**Foreign Keys:**
- dim_customer_sk
- dim_product_sk
- dim_campaign_sk
- dim_date_sk
- dim_time_sk

**Measures:**
- quantity
- unit_price
- discount_amount
- tax_amount
- line_total
- revenue

#### **FACT_PERFORMANCE** (Daily snapshot)
**Grain:** One row per campaign per channel per day

**Foreign Keys:**
- dim_campaign_sk
- dim_channel_sk
- dim_date_sk

**Measures:**
- impressions
- clicks
- cost
- conversions
- revenue
- ctr (click-through rate)
- cpc (cost per click)
- roas (return on ad spend)

### 4.4 Implementation Detail

**Gold Layer = Views (Not Tables)**

Benefits:
- ⚡ No data duplication (reads from ODS)
- ⚡ Always current (no refresh lag)
- ⚡ Easy to modify derived logic
- ⚡ Lower storage costs

**See [ARCHITECTURE-LLD.md](ARCHITECTURE-LLD.md#2-final-dimensional-model-gold-layer) for complete DDL**

---

## 5. Key Design Decisions

### 5.1 Why Medallion Architecture?

| Requirement | How Medallion Addresses It |
|-------------|----------------------------|
| **Audit Trail** | Bronze layer preserves raw data |
| **Data Quality** | Progressive refinement across layers |
| **Flexibility** | Reprocess Silver/Gold without reloading Bronze |
| **Multi-Audience** | Technical (Bronze/Silver) + Business (Gold) |
| **Scalability** | Add sources without impacting downstream |

### 5.2 Load Strategy: Mixed Approach

| Table | Strategy | Rationale |
|-------|----------|--------|
| **Campaigns** | Incremental | Changes frequently |
| **Customers** | Incremental | Updates daily |
| **Products** | Incremental | Price changes |
| **Sales** | Incremental | High volume, growing |
| **Performance** | Incremental | Daily metrics |
| **Channels** | Full Refresh | Small, rarely changes |

**Incremental Pattern:**
- High water mark based on `last_modified_timestamp`
- Load only new/changed records
- 97% faster than full refresh

### 5.3 SCD Type 1 (Overwrite)

**Decision:** Use Type 1 (overwrite) instead of Type 2 (history tracking)

**Rationale:**
- ✅ Simpler implementation
- ✅ Faster queries (no date range filters)
- ✅ History not required for this use case
- ✅ Matches SFDC pattern proven in production

**Trade-off:** If historical dimension changes needed later, implement Type 2 in Silver layer

### 5.4 Gold as Views

**Decision:** Implement Gold layer as views, not tables

**Rationale:**
- ✅ Single source of truth (ODS tables)
- ✅ No refresh lag or sync issues
- ✅ 50% lower storage costs
- ✅ Instant updates when ODS changes

**Trade-off:** Slightly slower queries (negligible with Snowflake clustering)

### 5.5 Surrogate Keys via Sequences

**Decision:** Use Snowflake sequences with DEFAULT values

**Rationale:**
- ✅ Auto-generation (no pipeline logic)
- ✅ Guaranteed uniqueness
- ✅ Preserved on UPDATE (MERGE)
- ✅ Follows Snowflake best practices

---

## 6. Analytics Capabilities

### 6.1 Ad Channel Analysis

**Questions Answered:**
1. Which channels drive most revenue?
2. What's the ROI/ROAS by channel?
3. Which channels have best conversion rates?
4. How do costs compare to revenue?
5. Channel performance trends?

**Key Metrics:**
- ROAS (Return on Ad Spend)
- CPC (Cost Per Click)
- CTR (Click-Through Rate)
- Conversion Rate
- Cost Per Conversion

**Sample Query:**
```sql
SELECT 
    ch.channel_name,
    SUM(f.cost) AS total_cost,
    SUM(f.revenue) AS total_revenue,
    ROUND(SUM(f.revenue) / NULLIF(SUM(f.cost), 0), 2) AS roas
FROM mtln_fact_performance f
JOIN mtln_dim_channel ch ON f.dim_channel_sk = ch.dim_channel_sk
GROUP BY ch.channel_name
ORDER BY roas DESC;
```

### 6.2 Customer Segmentation

**Approaches:**

1. **RFM Analysis** (Recency, Frequency, Monetary)
   - Champions: Recent + Frequent + High spend
   - Loyal: Frequent + Good spend
   - At Risk: Not recent + Previously good
   - Lost: Long time inactive

2. **Tier-Based** (Platinum/Gold/Silver/Bronze)
   - Pre-defined in source system
   - Track tier migration

3. **Value-Based** (Lifetime Value)
   - VIP: $20K+
   - Premium: $10K-20K
   - Standard: $5K-10K
   - Basic: < $5K

**Key Metrics:**
- Customer Lifetime Value
- Average Order Value
- Purchase Frequency
- Days Since Last Purchase

### 6.3 Campaign Performance

**Tracking:**
- Budget vs. Actual Spend
- Target vs. Actual Conversions
- Performance by Campaign Type
- Time-to-date Progress
- Historical Benchmarks

**Alerting:**
- 🔴 Campaign 20%+ over budget
- 🟡 Campaign 10%+ under target
- 🟢 Campaign on track

### 6.4 Product Profitability

**Analysis:**
- Margin % by Product/Category
- Sales Volume vs. Margin
- Best Sellers (volume)
- Most Profitable (margin × volume)
- Underperforming Products

**Recommendations:**
- Promote high-margin products
- Bundle low-margin with high-margin
- Discontinue unprofitable products

---

## 7. Operations

### 7.1 Data Refresh Schedule

**Daily Batch:**
- **Time:** 2:00 AM (off-peak)
- **Duration:** ~15 minutes
- **Frequency:** Daily (Mon-Sun)

**Pipeline Flow:**
1. Set high water marks (1 min)
2. Load Bronze (parallel, 5 min)
3. Transform to Silver (5 min)
4. Transform to Gold (instant, views)
5. Data quality validation (2 min)
6. Send success notification (1 min)

### 7.2 Monitoring

**Automated Alerts:**
- ❌ Pipeline failure
- ⚠️ Row count variance > 20%
- ⚠️ Execution time > 30 min
- ℹ️ Daily success summary

**Dashboards:**
- Pipeline execution history
- Data quality metrics
- Query performance stats
- User adoption metrics

### 7.3 Data Retention

| Layer | Retention | Rationale |
|-------|-----------|--------|
| RAW (Stages) | 7 days | Temporary file landing |
| Bronze | 14 days | Short-term audit trail |
| Silver/ODS | 30 days | Operational queries |
| Gold (Views) | N/A | No storage (views) |

### 7.4 Disaster Recovery

**Backup Strategy:**
- ODS tables: Snowflake Time Travel (30 days)
- Pipeline code: Git version control
- Metadata: Daily export

**Recovery Time:**
- Pipeline failure: < 1 hour (automatic retry)
- Data corruption: < 4 hours (restore from Time Travel)
- Complete rebuild: < 8 hours (reload from sources)

---

## 8. Next Steps

### 8.1 Implementation Phases

**Phase 1: Foundation (Week 1-2)** ✅ Complete
- ✅ Architecture design
- ✅ Dimensional model
- ✅ Technical specifications

**Phase 2: Development (Week 3-6)** 🔄 In Progress
- 🔄 Create stages and sequences
- 🔄 Build Bronze layer pipelines
- 🔄 Build Silver transformations
- 🔄 Build Gold views
- 🔄 Unit testing

**Phase 3: Testing (Week 7)** ⏳ Pending
- ⏳ Integration testing
- ⏳ Data quality validation
- ⏳ Performance testing
- ⏳ UAT with business users

**Phase 4: Deployment (Week 8)** ⏳ Pending
- ⏳ Production setup (3 hours)
- ⏳ Initial data load
- ⏳ Validation
- ⏳ Go-live

### 8.2 Post-Deployment

**Week 1-2:**
- Monitor pipeline executions
- User training sessions
- Quick wins identification

**Month 1:**
- Adoption tracking
- Performance tuning
- User feedback collection

**Month 2-3:**
- Advanced analytics enablement
- Self-service expansion
- ROI measurement

### 8.3 Technical Documentation

**Available:**
- ✅ **ARCHITECTURE-HLD.md** (this document)
- ✅ **ARCHITECTURE-LLD.md** (technical implementation)
- ⏳ **DATA-DICTIONARY.md** (column definitions)
- ⏳ **DEPLOYMENT-GUIDE.md** (deployment steps)
- ⏳ **USER-GUIDE.md** (business user guide)

### 8.4 Review & Approval

**Stakeholders:**
- [ ] CMO (Executive Sponsor)
- [ ] Data Engineering Lead
- [ ] Analytics Lead
- [ ] IT Security
- [ ] Finance

---

**Document Status:** Complete  
**Last Updated:** 2025-12-21  
**Next Review:** After UAT completion

**For technical implementation details:**  
→ See **[ARCHITECTURE-LLD.md](ARCHITECTURE-LLD.md)**