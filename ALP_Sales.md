# ALP Sales Analysis & Methodology
## Comprehensive Guide to Lead, Matter & Offering Analytics

### Overview & Purpose

The ALP sales analysis system tracks the complete client acquisition journey from initial lead through to won matters and delivered offerings. This sophisticated methodology accounts for the complex many-to-many relationships between matters and offerings, providing accurate insights for business development and performance tracking.

**Key Metrics:**
- **Leads**: All new potential client matters (any status)
- **New Matters**: Won matters only (status 4, 5, 6)
- **New Offerings**: Specific services won within matters
- **Conversion Rates**: Lead to matter conversion analysis

---

## 🎯 **Critical Data Relationships**

### **Matter-Offering Relationship Structure**

**IMPORTANT DISCOVERY**: Matters can have multiple offerings, creating a many-to-many relationship that affects all counting methodologies.

```
MATTERS ←→ OFFERINGS (Many-to-Many)
├── Via matter_offering table: matters.id ↔ matter_offering.matters_id ↔ matter_offering.offerings_id ↔ offerings.id
└── Via matter_outcomes table: matters.id ↔ matter_outcomes.matter_id ↔ offering_outcomes.offering_outcome_id ↔ offerings.id

RESULT: 
- One matter can have multiple offerings
- Offering counts will be higher than matter counts
- Must use COUNT(DISTINCT matter_id) to avoid double-counting matters
```

### **Database Relationship Paths**

#### **Path 1: matter_offering (Used in Query #94)**
```sql
matters 
→ matter_offering (via matters_id)
→ offerings (via offerings_id)
→ offering_categories (via offering_category_id)
```

#### **Path 2: matter_outcomes (Used for conversion analysis)**
```sql
matters 
→ matter_outcomes (via matter_id)
→ offering_outcomes (via offering_outcome_id)
→ offerings (via offering_id)
→ offering_categories (via offering_category_id)
```

**When to Use Each Path:**
- **matter_offering**: For current matter-offering associations and sales reporting
- **matter_outcomes**: For detailed service delivery and conversion analysis

---

## 📊 **Sales Definitions & Methodology**

### **1. Leads Analysis**

**Definition**: All new potential client matters, regardless of outcome
- **Includes**: All statuses (1-7)
- **Date Field**: `lead_date` (or `first_contact_date` if lead_date is null)
- **Excludes**: Deleted matters (`is_deleted = true`)

```sql
-- Lead counting methodology
SELECT 
  COUNT(DISTINCT m.id) as total_leads,
  DATE_TRUNC('month', COALESCE(m.lead_date, m.first_contact_date)) as lead_month
FROM matters m
WHERE m.is_deleted IS NOT TRUE
  AND m.matter_status_tag_id <> 10 -- Exclude projects
  AND COALESCE(m.lead_date, m.first_contact_date) >= '2019-07-01'
GROUP BY lead_month
ORDER BY lead_month;
```

### **2. New Matters Analysis**

**Definition**: Won matters only - successfully converted leads
- **Includes**: Status 4 (Open), 5 (Closed), 6 (Finalised)
- **Excludes**: Status 1 (To be quoted), 2 (Quoted awaiting acceptance), 3 (Lost), 7 (Deleted)
- **Date Field**: `matter_date`
- **Key Principle**: Only count distinct matters to avoid double-counting

```sql
-- New matter counting methodology
SELECT 
  COUNT(DISTINCT m.id) as total_new_matters,
  DATE_TRUNC('month', m.matter_date) as matter_month
FROM matters m
WHERE m.is_deleted IS NOT TRUE
  AND m.matter_status_tag_id <> 10 -- Exclude projects
  AND m.status IN (4, 5, 6) -- Won matters only
  AND m.matter_date >= '2019-07-01'
GROUP BY matter_month
ORDER BY matter_month;
```

### **3. New Offerings Analysis**

**Definition**: Specific services won within matters
- **Count Method**: Count individual offerings, not matters
- **Relationship**: Via matter_offering table for current associations
- **Key Insight**: Offering count > Matter count (due to many-to-many relationship)

```sql
-- New offering counting methodology
SELECT 
  COUNT(*) as total_new_offerings,
  oc.name as offering_category,
  DATE_TRUNC('month', m.matter_date) as matter_month
FROM matters m
JOIN matter_offering mo ON m.id = mo.matters_id
JOIN offerings o ON mo.offerings_id = o.id
JOIN offering_categories oc ON o.offering_category_id = oc.id
WHERE m.is_deleted IS NOT TRUE
  AND m.matter_status_tag_id <> 10
  AND m.status IN (4, 5, 6) -- Won matters only
  AND m.matter_date >= '2019-07-01'
GROUP BY oc.name, matter_month
ORDER BY matter_month, oc.name;
```

---

## 🎯 **Financial Year Analysis**

### **Financial Year Structure**
- **FY Start**: July 1st
- **FY End**: June 30th
- **Quarters**: 
  - Q1: July, August, September
  - Q2: October, November, December
  - Q3: January, February, March
  - Q4: April, May, June

### **FY Calculation Logic**
```sql
-- Financial year calculation
CASE 
  WHEN EXTRACT(month FROM date_field) > 6 THEN 
    CONCAT(EXTRACT(year FROM date_field), '-', EXTRACT(year FROM date_field) + 1)
  ELSE 
    CONCAT(EXTRACT(year FROM date_field) - 1, '-', EXTRACT(year FROM date_field))
END as financial_year

-- Financial quarter calculation  
CASE 
  WHEN EXTRACT(month FROM date_field) BETWEEN 7 AND 9 THEN 1  -- Q1
  WHEN EXTRACT(month FROM date_field) BETWEEN 10 AND 12 THEN 2 -- Q2
  WHEN EXTRACT(month FROM date_field) BETWEEN 1 AND 3 THEN 3   -- Q3
  WHEN EXTRACT(month FROM date_field) BETWEEN 4 AND 6 THEN 4   -- Q4
END as financial_quarter
```

---

## 📈 **Conversion Analysis**

### **Lead to Matter Conversion**

**Methodology**: Track progression from lead to won matter
```sql
-- Conversion rate analysis
WITH lead_data AS (
  SELECT 
    DATE_TRUNC('month', COALESCE(lead_date, first_contact_date)) as period,
    COUNT(DISTINCT id) as total_leads
  FROM matters 
  WHERE is_deleted IS NOT TRUE 
    AND matter_status_tag_id <> 10
  GROUP BY period
),
matter_data AS (
  SELECT 
    DATE_TRUNC('month', COALESCE(lead_date, first_contact_date)) as period,
    COUNT(DISTINCT id) as won_matters
  FROM matters 
  WHERE is_deleted IS NOT TRUE 
    AND matter_status_tag_id <> 10
    AND status IN (4, 5, 6)
  GROUP BY period
)
SELECT 
  l.period,
  l.total_leads,
  COALESCE(m.won_matters, 0) as won_matters,
  ROUND(COALESCE(m.won_matters, 0) * 100.0 / l.total_leads, 2) as conversion_rate_percent
FROM lead_data l
LEFT JOIN matter_data m ON l.period = m.period
ORDER BY l.period;
```

### **Matter Status Definitions**
- **1**: To be quoted (Lead)
- **2**: Quoted awaiting acceptance (Lead)  
- **3**: Lost (Lead - unsuccessful)
- **4**: Open (Won matter)
- **5**: Closed (Won matter)
- **6**: Finalised (Won matter)
- **7**: Deleted (Excluded from analysis)

---

## 🔧 **Query Templates & Best Practices**

### **Template: Monthly Lead Analysis**
```sql
SELECT 
  DATE_TRUNC('month', COALESCE(lead_date, first_contact_date)) as month,
  COUNT(DISTINCT id) as total_leads,
  COUNT(DISTINCT CASE WHEN status IN (4,5,6) THEN id END) as won_matters,
  COUNT(DISTINCT CASE WHEN status = 3 THEN id END) as lost_matters,
  ROUND(
    COUNT(DISTINCT CASE WHEN status IN (4,5,6) THEN id END) * 100.0 / 
    NULLIF(COUNT(DISTINCT CASE WHEN status IN (3,4,5,6) THEN id END), 0), 
    2
  ) as conversion_rate_percent
FROM {{#94-firm-files-id}} as matters
WHERE month >= CURRENT_DATE - INTERVAL '24 months'
GROUP BY month
ORDER BY month;
```

### **Template: Offering Category Performance**
```sql
SELECT 
  oc.name as offering_category,
  DATE_TRUNC('month', m.matter_date) as month,
  COUNT(DISTINCT m.id) as unique_matters,
  COUNT(*) as total_offerings
FROM {{#94-firm-files-id}} as m
WHERE m.status_id IN (4, 5, 6) -- Won matters only
  AND month >= CURRENT_DATE - INTERVAL '24 months'
GROUP BY oc.name, month
ORDER BY month, oc.name;
```

---

## ⚠️ **Critical Considerations**

### **1. Double-Counting Prevention**
**ALWAYS use `COUNT(DISTINCT matter_id)`** when analyzing matters to avoid double-counting due to multiple offerings per matter.

### **2. Date Field Selection**
- **Lead Analysis**: Use `lead_date` (or `first_contact_date` if null)
- **Matter Analysis**: Use `matter_date`
- **Service Delivery**: Use outcome completion dates

### **3. Status Filtering**
- **Leads**: Include all statuses (1-6, exclude 7)
- **Won Matters**: Only include status 4, 5, 6
- **Lost Leads**: Only include status 3

### **4. Data Quality Checks**
```sql
-- Validate matter-offering relationships
SELECT 
  'Matters without offerings' as check_type,
  COUNT(*) as count
FROM matters m
LEFT JOIN matter_offering mo ON m.id = mo.matters_id
WHERE m.status IN (4,5,6) 
  AND m.is_deleted IS NOT TRUE
  AND mo.matters_id IS NULL

UNION ALL

SELECT 
  'Offerings without categories' as check_type,
  COUNT(*) as count  
FROM offerings o
LEFT JOIN offering_categories oc ON o.offering_category_id = oc.id
WHERE oc.id IS NULL
  AND o.is_deleted IS NOT TRUE;
```

---

## 📊 **Standard Reporting Periods**

### **Common Analysis Timeframes**
- **Last 12 months**: Rolling year analysis
- **Last 24 months**: Trend analysis with year-over-year comparison
- **Financial Year**: July 1 - June 30 analysis
- **Calendar Year**: January 1 - December 31 analysis

### **Parameter Formats for Metabase**
- **Month**: `YYYY-MM` (e.g., `2024-06`) Text
- **Quarter**: `1`, `2`, `3`, `4` Integer
- **Financial Year**: `YYYY-YYYY` (e.g., `2023-2024`) Text

---

## 🎯 **Key Performance Indicators (KPIs)**

### **Primary Sales Metrics**
1. **Monthly Lead Volume**: Total new leads per month
2. **Lead-to-Matter Conversion Rate**: % of leads that become won matters  
3. **Monthly Won Matters**: New matters secured per month
4. **Average Matter Value**: Estimated budget per won matter
5. **Service Mix**: Distribution of offerings by category
6. **Time to Conversion**: Days from lead to won matter

### **Secondary Metrics**
1. **Offering Diversity**: Average offerings per matter
2. **Category Performance**: Conversion rates by offering category
3. **Seasonal Trends**: Month-over-month and year-over-year patterns
4. **Pipeline Value**: Total estimated budget of active leads

---

## 🔗 **Integration with Other Modules**

### **Related Documentation**
- **[Matter Management](./ALP_Matter_Management.md)** - Matter lifecycle and status management
- **[Offerings & Service Delivery](./ALP_Offerings_Service_Delivery.md)** - Service template structure
- **[Time Tracking](./ALP_Time_Tracking.md)** - Service delivery execution
- **[Invoicing](./ALP_Invoicing_Business_Logic.md)** - Revenue realization

### **Data Dependencies**
- **matters**: Core entity for all sales analysis
- **matter_offering**: Current matter-offering associations
- **matter_outcomes**: Service delivery tracking
- **offerings**: Service templates and categories
- **offering_categories**: Service categorization

---

## 📝 **Change Log & Best Practices**

### **Recent Discoveries (December 2024)**
1. **Matter-Offering Many-to-Many Relationship**: Confirmed that matters can have multiple offerings, requiring distinct counting methodologies
2. **Two Relationship Paths**: Identified difference between `matter_offering` (current) and `matter_outcomes` (delivery) tables
3. **Query #94 vs #635**: Documented different approaches and their impact on counting

### **Best Practices**
1. **Always use DISTINCT** when counting matters in offering-related queries
2. **Document relationship path** used in each query
3. **Validate totals** against base matter counts when possible
4. **Use consistent date fields** across related analyses
5. **Include data quality checks** in complex analyses

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Related Framework**: [Query Development Framework Summary](./Query_Development_Framework_Summary.md)