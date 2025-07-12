# Metabase Implementation Guide
## Best Practices for Legal Practice Analytics Deployment

### Overview

This guide covers the practical aspects of implementing SQL queries in Metabase for legal practice analytics, including visualization strategies, parameter configuration, performance optimization, and user experience design.

---

## Phase 1: Query Preparation

### 1.1 Database Structure Essentials

**⚠️ Critical Database Structure Notes:**
- **Column naming**: All database columns use snake_case (e.g., `updated_at`, `is_deleted`)
- **Enum values**: All enums stored as integers - use CASE statements for display
- **Time entries**: Use table-per-hierarchy inheritance with `discriminator` field
- **Rate precision**: Stored ×10 (e.g., 450 = $45.00/hour) - always divide by 10 for display
- **Time tracking**: Uses `units` field (6-minute increments) - divide by 10 for hours
- **Soft deletes**: Always filter `WHERE is_deleted = false`

**Key Enum Mappings:**
```sql
-- Matter Status
CASE 
  WHEN status = 1 THEN 'ToBeQuoted'
  WHEN status = 2 THEN 'QuotedAwaitingAcceptance'
  WHEN status = 3 THEN 'Lost'
  WHEN status = 4 THEN 'Open'
  WHEN status = 5 THEN 'Closed'
  WHEN status = 6 THEN 'Finalised'
  WHEN status = 7 THEN 'Deleted'
END AS "Matter Status"

-- Billable Types (MatterComponentTimeEntry only)
CASE 
  WHEN billable_type = 1 THEN 'Billable'
  WHEN billable_type = 2 THEN 'NonBillable'
  WHEN billable_type = 3 THEN 'NonChargeable'
  WHEN billable_type = 4 THEN 'ProBono'
END AS "Billable Type"

-- Invoice Status  
CASE 
  WHEN status = 1 THEN 'Draft'
  WHEN status = 2 THEN 'AwaitingApproval'
  WHEN status = 3 THEN 'Approved'
  WHEN status = 4 THEN 'Sent'
  WHEN status = 5 THEN 'All'
END AS "Invoice Status"

-- Trust Transaction Types
CASE 
  WHEN transaction_type = 1 THEN 'Deposit'
  WHEN transaction_type = 2 THEN 'Withdrawal'
  WHEN transaction_type = 3 THEN 'TransferOut'
  WHEN transaction_type = 4 THEN 'TransferIn'
END AS "Transaction Type"
```

**Time Entry Queries:**
```sql
-- Time entries use table-per-hierarchy inheritance
SELECT 
  te.discriminator AS "Entry Type",
  te.units / 10.0 AS "Hours",                    -- Convert units to hours
  te.rate / 10.0 AS "Hourly Rate",              -- Convert rate to dollars
  (te.units / 10.0) * (te.rate / 10.0) AS "Value"
FROM time_entries te
WHERE te.is_deleted = false
  AND te.discriminator = 'MatterComponentTimeEntry'  -- Filter by entry type
  AND te.billable_type = 1                           -- billable_type only exists for MatterComponentTimeEntry
```

### 1.2 SQL Query Optimization for Metabase

**Query Structure Guidelines:**
```sql
-- Use descriptive column aliases that will become chart labels
SELECT 
  practice_area AS "Practice Area",           -- Good: Human-readable
  COUNT(*) AS "Number of Matters",           -- Good: Clear metric name
  AVG(billable_hours) AS "Avg Billable Hours" -- Good: Units implied
FROM matters_summary
ORDER BY "Number of Matters" DESC;          -- Reference alias consistently
```

**Column Naming Best Practices:**
- Use quoted aliases for multi-word column names
- Include units in column names where applicable ("Revenue ($)", "Hours", "Days")
- Use title case for better readability
- Avoid technical database terms in user-facing names

### 1.2 Data Type Considerations

**Ensure appropriate data types for visualization:**
```sql
-- Dates should be proper DATE/TIMESTAMP types
DATE_TRUNC('month', worked_date) AS "Month",

-- Numbers should be numeric, not text
ROUND(billable_hours, 2) AS "Billable Hours",

-- Percentages should be decimals (0.85) not integers (85)
billable_hours / total_hours AS "Utilization Rate",

-- Categories should be text with consistent naming
CASE 
  WHEN status = 1 THEN 'To Be Quoted'
  WHEN status = 2 THEN 'Quoted - Awaiting Acceptance'
  -- etc.
END AS "Matter Status"
```

---

## Phase 2: Metabase Question Configuration

### 2.1 Question Setup

**Basic Configuration:**
1. **Question Name**: Use clear, descriptive names that indicate purpose
   - Good: "Matter Pipeline by Status - Monthly View"
   - Bad: "Matter Query v2"

2. **Description**: Include business context and key insights
   ```
   Shows the distribution of matters across different status categories, 
   updated monthly. Use this to track conversion rates from quotes to 
   active matters and identify pipeline bottlenecks.
   
   Key Metrics:
   - Matter count by status
   - Percentage distribution
   - Month-over-month changes
   
   Data Refresh: Daily at 6:00 AM
   ```

3. **Database Selection**: Use the appropriate database connection
4. **SQL Mode**: Always use "Native Query" for complex legal practice analytics

### 2.2 Parameter Configuration

**Common Parameter Patterns:**

**Date Range Parameters:**
```sql
-- In the SQL query
WHERE worked_date BETWEEN {{start_date}} AND {{end_date}}

-- Parameter Configuration in Metabase:
-- Variable name: start_date
-- Variable type: Date
-- Default: 30 days ago
-- Required: Yes

-- Variable name: end_date  
-- Variable type: Date
-- Default: today
-- Required: Yes
```

**User Selection Parameter:**
```sql
-- In the SQL query
WHERE te.user_id = {{user_id}}
-- OR for optional filter:
WHERE ({{user_id}} IS NULL OR te.user_id = {{user_id}})

-- Parameter Configuration:
-- Variable name: user_id
-- Variable type: Number (or Field Filter if using UI picker)
-- Default: (empty for optional)
-- Required: No
```

**Practice Area Filter:**
```sql
-- Field Filter approach (recommended for UX)
WHERE {{practice_area_filter}}

-- Parameter Configuration:
-- Variable name: practice_area_filter
-- Variable type: Field Filter
-- Filter widget type: Dropdown
-- Mapped to: practice_areas.name
-- Default: No filter
```

---

## Phase 3: Visualization Selection

### 3.1 Chart Type Decision Matrix

| Data Type | Best Visualization | When to Use | Example |
|-----------|-------------------|-------------|---------|
| **Counts/Totals** | Number cards | Single key metrics | "Total Active Matters: 247" |
| **Trends over time** | Line chart | Performance tracking | Monthly revenue trends |
| **Comparisons** | Bar chart | Category comparisons | Revenue by practice area |
| **Proportions** | Pie chart | Part-to-whole relationships | Matter status distribution |
| **Progress to goal** | Gauge | Target tracking | Billing target achievement |
| **Detailed data** | Table | Drill-down analysis | Individual matter details |
| **Geographic** | Map | Location-based data | Client distribution by region |

### 3.2 Legal Practice-Specific Visualization Guidelines

**Financial Data:**
- Always format currency properly ($ symbol, 2 decimal places)
- Use consistent color coding (green for positive, red for negative)
- Include totals and subtotals where meaningful
- Consider both including and excluding GST views

**Time-based Data:**
- Use hours (not minutes) for display
- Show both billable and total time for context
- Include utilization percentages
- Use stacked bars for time type breakdowns

**Status/Pipeline Data:**
- Use consistent status colors across all charts
- Order statuses logically (pipeline flow)
- Include percentage and count views
- Show transitions between statuses over time

---

## Phase 4: Dashboard Design

### 4.1 Dashboard Layout Principles

**Information Hierarchy:**
1. **Top Level**: Key performance indicators (KPI cards)
2. **Second Level**: Trend analysis (time series charts)
3. **Third Level**: Categorical breakdowns (bar/pie charts)
4. **Bottom Level**: Detailed tables (drill-down data)

**Example Legal Practice Dashboard Layout:**
```
[KPI Row]
[Total Revenue $] [Total Hours] [Active Matters] [Utilization %]

[Trend Row]  
[Revenue Trend Chart                    ] [Hours Trend Chart                    ]

[Analysis Row]
[Revenue by Practice Area] [Matter Status Distribution] [Top Clients]

[Detail Row]
[Matter Performance Detail Table                                        ]
```

### 4.2 Dashboard Filters

**Implement consistent filtering across dashboard:**
```sql
-- Use shared filter parameters
WHERE worked_date BETWEEN {{dashboard_start_date}} AND {{dashboard_end_date}}
AND ({{practice_area}} IS NULL OR practice_area = {{practice_area}})
AND ({{responsible_lawyer}} IS NULL OR responsible_lawyer_id = {{responsible_lawyer}})
```

**Filter Best Practices:**
- Place most commonly used filters at the top
- Use field filters for better UX when possible
- Provide sensible defaults (current month, all practice areas)
- Group related filters together
- Test filter combinations for edge cases

---

## Phase 5: Performance Optimization

### 5.1 Query Performance

**Optimization Techniques:**
1. **Limit time ranges** in default views
2. **Use indexes** on commonly filtered columns
3. **Consider materialized views** for complex calculations
4. **Cache settings** appropriate for data freshness needs

**Metabase-Specific Optimizations:**
```sql
-- Use LIMIT for large datasets in table views
SELECT * FROM detailed_time_entries 
WHERE worked_date >= {{start_date}}
ORDER BY worked_date DESC
LIMIT 1000;

-- Pre-aggregate for dashboard summary cards
WITH daily_aggregates AS (
  SELECT 
    DATE(worked_date) as work_date,
    SUM(billable_value) as daily_revenue
  FROM time_entries_detailed
  WHERE worked_date >= {{start_date}}
  GROUP BY DATE(worked_date)
)
SELECT SUM(daily_revenue) as "Total Revenue"
FROM daily_aggregates;
```

### 5.2 Caching Strategy

**Cache Configuration by Question Type:**

| Question Type | Cache TTL | Reasoning |
|---------------|-----------|-----------|
| **Real-time dashboards** | 5 minutes | Critical operational data |
| **Daily reports** | 1 hour | Updated throughout day |
| **Weekly summaries** | 6 hours | Less time-sensitive |
| **Monthly analysis** | 24 hours | Historical data, infrequent changes |
| **Annual reports** | 7 days | Static historical data |

---

## Phase 6: User Experience Design

### 6.1 Progressive Disclosure

**Layer information complexity:**
1. **Executive Summary**: High-level KPIs only
2. **Operational Dashboard**: Department-specific metrics
3. **Analytical Deep-Dive**: Detailed breakdowns and comparisons
4. **Raw Data Access**: Full table views for power users

### 6.2 Responsive Design Considerations

**Mobile-Friendly Dashboards:**
- Limit dashboard width (max 3-4 cards per row)
- Use larger fonts for mobile readability
- Prioritize most important metrics at top
- Test on actual mobile devices
- Consider separate mobile dashboards for key metrics

### 6.3 User Training Materials

**Create documentation for each dashboard:**
```markdown
## Matter Pipeline Dashboard

### Purpose
Track the flow of matters through our pipeline from initial contact to completion.

### Key Metrics
- **Pipeline Value**: Total estimated value of matters in pipeline
- **Conversion Rate**: Percentage of quotes that become active matters  
- **Avg Time to Accept**: How long between quote and acceptance

### How to Use
1. Select date range for analysis period
2. Filter by practice area if needed
3. Click on chart elements to drill down
4. Export data using the download button

### Refresh Schedule
Updates every morning at 6:00 AM with previous day's data.

### Contact
For questions or issues, contact the Business Intelligence team.
```

---

## Phase 7: Security & Access Control

### 7.1 User Permissions

**Permission Strategy:**
- **Public Access**: Basic firm metrics (anonymized)
- **Staff Access**: Department-specific data
- **Manager Access**: All departmental data + some cross-department
- **Partner Access**: All firm data + financial details
- **Admin Access**: Raw data access + system configuration

### 7.2 Data Sensitivity

**Classification Guidelines:**
```sql
-- Public data (can be shared broadly)
SELECT practice_area, COUNT(*) as matter_count
FROM matters WHERE is_deleted = FALSE;

-- Restricted data (need permission)
SELECT client_name, billable_revenue, profit_margin
FROM client_profitability;

-- Confidential data (partners/admin only) 
SELECT lawyer_name, individual_billable_hours, hourly_rate
FROM user_productivity;
```

---

## Phase 8: Deployment & Maintenance

### 8.1 Release Process

**Development → Production Workflow:**
1. **Development**: Test with sample data
2. **Staging**: Validate with production-like data
3. **User Acceptance**: Key stakeholders review
4. **Production**: Deploy with monitoring
5. **Training**: User training and documentation
6. **Monitoring**: Track usage and performance

### 8.2 Monitoring & Maintenance

**Regular Maintenance Tasks:**
- **Weekly**: Check query performance and errors
- **Monthly**: Review user feedback and usage analytics
- **Quarterly**: Update business logic for any system changes
- **Annually**: Full review of all dashboards and questions

**Performance Monitoring:**
```sql
-- Query to identify slow-running questions
SELECT 
  question_name,
  AVG(execution_time_ms) as avg_execution_time,
  COUNT(*) as execution_count,
  MAX(execution_time_ms) as max_execution_time
FROM metabase_query_log
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY question_name
ORDER BY avg_execution_time DESC;
```

---

## Common Implementation Patterns

### Pattern 1: Executive Dashboard
- 4-6 KPI cards at top
- 2-3 trend charts below
- 1 summary table at bottom
- Minimal filters (date range only)

### Pattern 2: Operational Dashboard  
- Department-specific metrics
- Multiple filter options
- Mix of charts and tables
- Real-time or near-real-time data

### Pattern 3: Analytical Workbook
- Multiple related dashboards
- Extensive filtering capabilities
- Drill-down navigation
- Export functionality

### Pattern 4: Client-Facing Reports
- Clean, professional styling
- Limited interactivity
- Focus on client-specific data
- Scheduled delivery options

---

## Troubleshooting Guide

### Common Issues and Solutions

**Query Timeouts:**
- Add date range limits
- Review query execution plan
- Consider data pre-aggregation
- Check for missing indexes

**Incorrect Data:**
- Verify soft delete filtering
- Check business logic calculations
- Validate date range handling
- Test with known data samples

**Poor Performance:**
- Optimize JOIN operations
- Limit data volume
- Use appropriate caching
- Consider query restructuring

**User Experience Issues:**
- Test across different browsers
- Verify mobile responsiveness
- Check filter interactions
- Validate export functionality

---

**Document Version**: 1.0
**Last Updated**: [Date]
**Next Review**: [Date + 6 months] 