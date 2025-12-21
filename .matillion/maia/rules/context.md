# Data Warehouse Project Pattern - Quick Reference

**Purpose**: Capture key patterns and decisions for reuse in similar projects  
**Project**: Campaign Data Mart (Medallion Architecture)  
**Date**: 2025-12-18

---

## Project Overview

**Type**: Marketing Analytics Data Warehouse  
**Architecture**: Medallion (RAW → Bronze → Silver → Gold)  
**Platform**: Matillion + Snowflake  
**Scale**: 25 tables, 40+ pipelines, daily batch  
**Timeline**: 3 weeks design/build/test, 3 hours deployment

---

## Key Decisions & Rationale

### 1. Architecture: Medallion (4 Layers)

**Why**:
- Progressive data refinement (immutable → analytics-ready)
- Clear separation: technical (RAW/Bronze) vs. business (Silver/Gold)
- Audit trail of all transformations
- Supports diverse user skill levels

**Layers**:
- **RAW**: JSON landing zone (VARIANT) - Full refresh
- **Bronze**: Flattened relational - Full refresh  
- **Silver**: Quality + metrics - Mixed (full + incremental)
- **Gold**: Star schema (SCD + facts) - Incremental

---

### 2. Load Strategy: Mixed (Full Refresh + Incremental)

**Full Refresh** (10 tables):
- Dimensions < 1M rows
- Reference data (campaigns, customers, channels, geography)
- **Why**: Simple, fast enough (< 5 min), no merge complexity

**Incremental** (4 tables):
- Facts: Performance, Interactions (growing daily)
- Silver: Performance, Interactions (high volume)
- **Why**: 97% faster, scalable, watermark-based

**Pattern**:
```sql
WHERE source_timestamp > (SELECT MAX(LOAD_TIMESTAMP) FROM target)
```

---

### 3. SCD Strategy: Mixed Types by Business Need

**Type 1 (Overwrite)**: DIM_GEOGRAPHY
- **Why**: Corrections only, history not needed

**Type 2 (Full History)**: DIM_CAMPAIGN, DIM_CUSTOMER  
- **Why**: Budget/segment changes affect historical analysis
- **Implementation**: VALID_FROM, VALID_TO, IS_CURRENT

**Type 3 (Previous + Current)**: DIM_CHANNEL
- **Why**: Compare before/after category changes
- **Implementation**: CURRENT_*, PREVIOUS_* columns

---

### 4. Surrogate + Natural Keys

**Both Used**:
- **Surrogate**: CAMPAIGN_KEY (AUTOINCREMENT) - for joins, SCD versioning
- **Natural**: CAMPAIGN_ID (VARCHAR) - for business traceability

**Why Both**: Technical efficiency + business meaning

---

### 5. DDL Separate from Data Pipelines

**Structure**:
- `Create All Tables - Master DDL.orch.yaml` (run once)
- `Master Pipeline - RAW to Gold.orch.yaml` (run daily)

**Why**: 
- Tables created once, data loaded repeatedly
- Faster iteration (no schema drop/recreate)
- Safer (prevent accidental data loss)
- Idempotent with CREATE OR REPLACE

---

### 6. Master Orchestration Pattern

**Hierarchy**:
```
Master Pipeline
├── Orchestrate RAW (6 generators in parallel)
├── Orchestrate Bronze (6 loads in parallel)  
├── Orchestrate Silver (6 loads, mixed strategies)
└── Orchestrate Gold (7 loads with dependencies)
```

**Benefits**: One-click execution, clear dependencies, parallel within layers

---

## Common Table Patterns

### Date Dimension
- 2020-2030 range
- Year, quarter, month, week, day_of_week
- Generated once with Calculator component

### Fact Tables
- Grain: One row per [entity] per [day]
- Foreign keys only (no denormalization)
- Additive metrics: impressions, clicks, cost, revenue
- LOAD_TIMESTAMP for incremental logic

### Dimension Tables (SCD Type 2)
- Surrogate + natural keys
- VALID_FROM, VALID_TO, IS_CURRENT
- VERSION_NUMBER for tracking
- Descriptive attributes + derived fields

---

## Data Quality Patterns (Silver Layer)

1. **NULL Handling**: `COALESCE(col, 'UNKNOWN')`
2. **Validation**: `CASE WHEN clicks > impressions THEN impressions ELSE clicks END`
3. **Deduplication**: `QUALIFY ROW_NUMBER() OVER (...) = 1`
4. **Derived Metrics**: Calculate CTR, ROAS once in Silver
5. **Type Casting**: `TRY_CAST(value AS NUMBER)`

---

## Documentation Pattern

### Essential (Minimum)
1. README.md
2. ARCHITECTURE.md
3. data-dictionary.md
4. deployment-guide.md

### Complete Suite (This Project = 16 docs)
5. Layer-specific (RAW, Bronze, Silver, Gold)
6. metric-calculations.md
7. Project-Story.md
8. Next-Steps.md
9. DEPLOYMENT-READINESS.md
10. DEPLOYMENT-CHECKLIST.md
11. production-setup-scripts.sql
12. GIT-SETUP-GUIDE.md
13. EXECUTIVE-SUMMARY.md

**Key Insight**: Documentation = deliverable, not afterthought

---

## Performance Optimizations

1. **Parallel Execution**: Independent loads within layer run simultaneously
2. **Incremental Loading**: 97% faster for high-volume tables
3. **Clustering Keys**: DATE_KEY, CAMPAIGN_KEY on facts (50-80% faster queries)
4. **Warehouse Auto-Suspend**: 300 sec ETL, 60 sec reporting (60-70% cost savings)

---

## Cost Optimizations

1. **Data Retention**: 7d RAW, 14d Bronze, 30d Silver, 90d Gold
2. **TRANSIENT Tables**: RAW/Bronze layers (25% storage savings)
3. **Auto-Suspend/Resume**: Warehouses idle when not in use
4. **Resource Monitors**: 1000 credit quota with alerts at 75%, 90%, 100%

**Result**: ~40-50% storage, 60-70% compute cost reduction

---

## Testing Strategy

### DEV Testing
1. Component-level (individual transformations)
2. Layer-level (orchestrations)
3. End-to-end (Master pipeline)
4. Data quality (validation queries)
5. Performance (execution times)

### Validation Queries (Always Run)
```sql
-- Row counts
SELECT COUNT(*) FROM table;

-- Referential integrity (should return 0)
SELECT COUNT(*) FROM fact f
LEFT JOIN dim d ON f.key = d.key
WHERE d.key IS NULL;

-- SCD consistency (should be empty)
SELECT entity_id FROM dim 
WHERE is_current = TRUE
GROUP BY entity_id HAVING COUNT(*) > 1;

-- Business rules (should return 0)
SELECT COUNT(*) WHERE clicks > impressions;
```

---

## Deployment Phases (3 hours)

1. **Snowflake Setup** (45 min) - Schemas, warehouses, roles, permissions
2. **Git Configuration** (30 min) - Repository, tokens, branch protection
3. **Matillion Setup** (30 min) - Project, connections, pipeline import
4. **Table Creation** (10 min) - Run Master DDL
5. **Data Load** (15 min) - Run Master Pipeline
6. **Validation** (30 min) - Quality checks, performance tests
7. **Scheduling** (15 min) - Daily runs, alerts
8. **Training** (1-2 days) - User onboarding

**Risk Level**: LOW (comprehensive testing, rollback plan ready)

---

## ROI Template

### This Project
- **Time Savings**: 40 hours/week → $250K/year
- **ROAS Improvement**: 2.8 → 3.2 (15%) → $150K/year  
- **Faster Decisions**: 7 days → 1 day (25%) → $50K/year
- **Total Benefits**: $450K/year
- **Operating Costs**: $122K/year
- **Net ROI**: $328K/year (269% return, < 4 month payback)

---

## Common Pitfalls & Solutions

| Pitfall | Solution |
|---------|----------|
| Mixing full/incremental causes orphans | Reload facts after dims OR use incremental for both |
| No watermark for incremental | Always add LOAD_TIMESTAMP in Silver |
| Over-normalized Gold layer | Denormalize common attributes in facts |
| No historical tracking | Use SCD Type 2 for changing dimensions |
| Inconsistent metrics | Calculate once in Silver/Gold, not in BI |

---

## Technology Stack

- **Orchestration**: Matillion Data Productivity Cloud
- **Warehouse**: Snowflake (MEDIUM ETL, LARGE reporting)
- **Version Control**: Git (GitHub/GitLab/Bitbucket)
- **BI Tools**: Tableau, Power BI, Looker (Phase 2)

**Why Matillion**: Low-code, rapid development, visual design, mixed skill levels

---

## Questions for Similar Projects

### Business
1. What business questions need answers?
2. Who are the users (skill level)?
3. Decision latency tolerance (hourly/daily/weekly)?
4. Expected data volume growth?
5. Regulatory/compliance requirements?

### Data
6. How many source systems?
7. Data quality level?
8. APIs or manual exports?
9. Historical data requirement?
10. Real-time needs?

### Technical
11. Existing tech stack?
12. Platform preferences?
13. Team technical skills?
14. Budget for tools/infrastructure?
15. BI tool investment?

### Success
16. How is success measured?
17. Expected ROI/payback period?
18. Critical KPIs?
19. Go-live deadline?
20. Maintenance model (team, skills)?

---

## When to Use This Pattern

### ✅ Use Medallion + This Pattern When:
- Multi-stage refinement needed
- Multiple user types (technical + business)
- Regulatory/audit requirements
- Scalability critical (many future sources)
- Medium-to-large volume
- Incremental loading needed
- Historical tracking required

### ❌ Consider Simpler When:
- Single, clean data source
- Small data volume (< 1M rows)
- Prototype/MVP
- Homogeneous users
- No growth expected

---

## Reusable Artifacts

### Copy Directly
1. Master DDL pattern
2. Incremental loading logic
3. SCD Type 2 implementation
4. Documentation structure (16 docs)
5. Deployment checklist
6. Data quality validations
7. ROI calculation template

### Adapt for Your Domain
8. Table structures
9. Pipeline naming conventions
10. Layer-specific transformations
11. Metric calculations

---

## Success Metrics

### Technical
- Pipeline success rate > 99%
- Execution time < 15 min
- Query response < 30 sec
- Data freshness < 24 hours

### Business
- 50+ active users daily
- 100+ queries/day
- 90% satisfaction
- 50% reduction in ad-hoc requests

### Adoption
- 100% target team adoption
- 10+ self-service users
- 20+ dashboards created

---

## Key Takeaways

1. **Separation of Concerns** - Layers serve different purposes
2. **Mixed Strategies** - Choose load/SCD type by table needs, not dogma
3. **Documentation = Deliverable** - Enables adoption and maintenance
4. **Incremental Build** - Test frequently, deploy confidently
5. **Business Value First** - Technical elegance serves outcomes
6. **Scalability by Design** - Patterns enable 10x growth
7. **Deployment Readiness** - Production deployment is part of project
8. **ROI Mindset** - Quantify and track business value

---

## Next Project Checklist

- [ ] Review this pattern document
- [ ] Identify similarities/differences
- [ ] Adapt table structures for domain
- [ ] Follow documentation structure
- [ ] Use deployment checklist
- [ ] Calculate ROI using template
- [ ] Build incrementally
- [ ] Test thoroughly
- [ ] Deploy with confidence

---

**Version**: 1.0  
**Created**: 2025-12-18  
**Based On**: Campaign Data Mart Project  
**Next Review**: After first reuse

**Use this document** to quickly understand the patterns, decisions, and best practices from this project when building similar data warehouse solutions.