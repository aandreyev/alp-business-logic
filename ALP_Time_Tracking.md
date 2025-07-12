# ALP Time Tracking System
## Comprehensive Guide to Time Entry Architecture & Analytics

### Overview & Purpose

The ALP time tracking system is built on a sophisticated table-per-hierarchy inheritance pattern that supports multiple types of time entries within a unified data structure. This architecture enables comprehensive time management across legal matters, internal projects, sales activities, and other business functions while maintaining referential integrity and analytical consistency.

**Key Architecture Features:**
- **Inheritance Pattern**: Single `time_entries` table with `discriminator` field for type identification
- **Multiple Entry Types**: Matter work, project tasks, sales activities, and administrative time
- **Billing Integration**: Complex billable/non-billable classification with invoice allocation
- **Rate Management**: Dynamic rate calculation with matter-specific adjustments
- **Units System**: 6-minute increment tracking (divide by 10 for hours)

---

## Database Schema & Inheritance

### 📊 **Core Table Structure**

```sql
-- Main time entries table (table-per-hierarchy inheritance)
time_entries (
    id, user_id, description, date, units, rate,
    -- Inheritance discriminator
    discriminator,  -- 'MatterComponentTimeEntry', 'ProjectTaskTimeEntry', 'SalesTimeEntry'
    -- Billing fields
    billable_type, gst_type, invoice_id, billed_amount, pre_units,
    -- Type-specific foreign keys (only one populated per entry)
    matter_component_id,  -- For MatterComponentTimeEntry
    project_task_id,      -- For ProjectTaskTimeEntry  
    sales_activity_id,    -- For SalesTimeEntry
    -- Standard audit fields
    inserted_at, updated_at, inserted_by_id, last_updated_by_id, is_deleted
)

-- Related timers table (active time tracking)
timers (
    id, user_id, description, start_time, is_running,
    discriminator, matter_component_id, project_task_id, sales_activity_id,
    inserted_at, updated_at, inserted_by_id, last_updated_by_id, is_deleted
)
```

### 🏗️ **Inheritance Pattern Breakdown**

#### **1. MatterComponentTimeEntry** (Legal billable work)
- **Discriminator**: `'MatterComponentTimeEntry'`
- **Foreign Key**: `matter_component_id → matter_components.id`
- **Billing**: Full billable/non-billable classification
- **Invoice Integration**: Links to invoices via `invoice_id`
- **Rate Adjustments**: Subject to matter-specific rate modifications

#### **2. ProjectTaskTimeEntry** (Internal project work)
- **Discriminator**: `'ProjectTaskTimeEntry'`
- **Foreign Key**: `project_task_id → project_tasks.id`
- **Billing**: Typically non-billable (internal work)
- **Use Cases**: Firm development, admin projects, training

#### **3. SalesTimeEntry** (Business development)
- **Discriminator**: `'SalesTimeEntry'`  
- **Foreign Key**: `sales_activity_id → sales_activities.id`
- **Billing**: Generally non-billable
- **Use Cases**: Client development, proposals, networking

---

## Time Units & Rate System

### ⏰ **6-Minute Increment System**

**Critical Data Conversion:**
```sql
-- Units to Hours
time_entries.units / 10.0 = actual_hours

-- Examples:
-- 15 units = 1.5 hours (90 minutes)
-- 10 units = 1.0 hour (60 minutes)
-- 5 units = 0.5 hour (30 minutes)
-- 1 unit = 0.1 hour (6 minutes)
```

### 💰 **Rate Storage & Calculation**

**Rate Precision (×10 storage):**
```sql
-- Stored rates are multiplied by 10
-- 450 in database = $45.00/hour
time_entries.rate / 10.0 = actual_hourly_rate

-- Billable value calculation
(time_entries.units / 10.0) * (time_entries.rate / 10.0) = billable_amount
```

### 🔧 **Matter Rate Adjustments**

```sql
-- Rate adjustment calculation
WITH adjusted_rates AS (
  SELECT 
    te.*,
    m.apply_rate_adjustment,
    m.rate_adjustment_percentage,
    CASE 
      WHEN m.apply_rate_adjustment = true THEN
        (te.rate / 10.0) * (1 + m.rate_adjustment_percentage / 100.0)
      ELSE 
        te.rate / 10.0
    END as effective_rate
  FROM time_entries te
  JOIN matter_components mc ON te.matter_component_id = mc.id
  JOIN matter_outcomes mo ON mc.matter_outcome_id = mo.id
  JOIN matters m ON mo.matter_id = m.id
  WHERE te.discriminator = 'MatterComponentTimeEntry'
    AND te.is_deleted = false
)
SELECT 
  user_id,
  SUM(units / 10.0) as total_hours,
  SUM((units / 10.0) * effective_rate) as adjusted_billable_value
FROM adjusted_rates
WHERE billable_type = 1  -- Billable only
GROUP BY user_id;
```

---

## Billable Type Classification

### 📊 **Billable Type Enum Mapping**

```sql
CASE 
  WHEN te.billable_type = 1 THEN 'Billable'
  WHEN te.billable_type = 2 THEN 'NonBillable'
  WHEN te.billable_type = 3 THEN 'NonChargeable'  
  WHEN te.billable_type = 4 THEN 'ProBono'
END as billable_classification
```

### 🎯 **Business Logic by Type**

#### **1. Billable (Type 1)**
- **Revenue Impact**: Direct client billing
- **Invoice Inclusion**: Appears on client invoices
- **Performance Metrics**: Counts toward billable hour targets
- **Profitability**: Revenue-generating time

#### **2. NonBillable (Type 2)**  
- **Revenue Impact**: No direct billing but necessary for matter
- **Examples**: Internal research, case strategy, file management
- **Cost Analysis**: Counts as cost against matter profitability
- **Business Value**: Essential but non-revenue work

#### **3. NonChargeable (Type 3)**
- **Revenue Impact**: No billing, typically administrative
- **Examples**: Email correspondence, brief calls, minor tasks
- **Client Relations**: Work performed but not charged as goodwill
- **Analytics**: Track efficiency and client value delivery

#### **4. ProBono (Type 4)**
- **Revenue Impact**: No billing, community service  
- **Legal Requirement**: Satisfies professional obligations
- **Marketing Value**: Demonstrates social responsibility
- **Tax Implications**: May qualify for business deductions

---

## Invoice Integration & Allocation

### 🔗 **Invoice Linkage**

```sql
-- Time entries linked to invoices
time_entries.invoice_id → invoices.id

-- WIP (Work in Progress) vs Invoiced
CASE 
  WHEN te.invoice_id IS NULL THEN 'WIP'
  WHEN te.invoice_id IS NOT NULL THEN 'Invoiced'
END as billing_status
```

### ⚠️ **Fixed-Price Invoice Allocation**

For fixed-price invoices, time entries receive allocated portions of total invoice value:

```sql
-- Fixed-price allocation analysis
WITH fixed_price_allocations AS (
  SELECT 
    te.id as time_entry_id,
    te.units,
    te.rate,
    te.billed_amount,  -- Allocated amount from fixed-price invoice
    i.type as invoice_type,
    -- Compare standard rate vs allocated amount
    (te.units / 10.0) * (te.rate / 10.0) as standard_value,
    te.billed_amount / 10.0 as allocated_value,
    (te.billed_amount / 10.0) - ((te.units / 10.0) * (te.rate / 10.0)) as allocation_variance
  FROM time_entries te
  JOIN invoices i ON te.invoice_id = i.id
  WHERE te.discriminator = 'MatterComponentTimeEntry'
    AND i.type = 1  -- Fixed price invoices
    AND te.is_deleted = false
    AND i.is_deleted = false
)
SELECT 
  COUNT(*) as entry_count,
  AVG(units / 10.0) as avg_hours,
  AVG(standard_value) as avg_standard_value,
  AVG(allocated_value) as avg_allocated_value,
  AVG(allocation_variance) as avg_allocation_variance,
  ROUND(AVG(allocation_variance / NULLIF(standard_value, 0) * 100), 2) as avg_variance_percent
FROM fixed_price_allocations;
```

---

## Analytics Patterns

### 📊 **Utilization Analysis**

```sql
-- Comprehensive time utilization breakdown
WITH time_analysis AS (
  SELECT 
    u.first_name || ' ' || u.last_name as fee_earner,
    u.billing_rate / 10.0 as standard_rate,
    -- Time breakdown by billable type
    SUM(CASE WHEN te.billable_type = 1 THEN te.units ELSE 0 END) / 10.0 as billable_hours,
    SUM(CASE WHEN te.billable_type = 2 THEN te.units ELSE 0 END) / 10.0 as non_billable_hours,
    SUM(CASE WHEN te.billable_type = 3 THEN te.units ELSE 0 END) / 10.0 as non_chargeable_hours,
    SUM(CASE WHEN te.billable_type = 4 THEN te.units ELSE 0 END) / 10.0 as pro_bono_hours,
    SUM(te.units) / 10.0 as total_hours,
    -- Revenue analysis
    SUM(CASE WHEN te.billable_type = 1 THEN 
      (te.units / 10.0) * (te.rate / 10.0) ELSE 0 END) as billable_value,
    -- Time entry type breakdown
    SUM(CASE WHEN te.discriminator = 'MatterComponentTimeEntry' THEN te.units ELSE 0 END) / 10.0 as matter_hours,
    SUM(CASE WHEN te.discriminator = 'ProjectTaskTimeEntry' THEN te.units ELSE 0 END) / 10.0 as project_hours,
    SUM(CASE WHEN te.discriminator = 'SalesTimeEntry' THEN te.units ELSE 0 END) / 10.0 as sales_hours
  FROM users u
  LEFT JOIN time_entries te ON u.id = te.user_id 
    AND te.is_deleted = false
    AND te.date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months')
  WHERE u.is_deleted = false
    AND u.billing_rate > 0  -- Active billing users only
  GROUP BY u.id, u.first_name, u.last_name, u.billing_rate
)
SELECT 
  fee_earner,
  standard_rate,
  billable_hours,
  non_billable_hours,
  non_chargeable_hours,
  pro_bono_hours,
  total_hours,
  matter_hours,
  project_hours,
  sales_hours,
  billable_value,
  -- Utilization metrics
  ROUND((billable_hours / NULLIF(total_hours, 0)) * 100, 1) as billable_percentage,
  ROUND((matter_hours / NULLIF(total_hours, 0)) * 100, 1) as matter_percentage,
  ROUND(billable_value / NULLIF(billable_hours, 0), 2) as effective_rate
FROM time_analysis
WHERE total_hours > 0
ORDER BY billable_value DESC;
```

### 📈 **WIP (Work in Progress) Analysis**

```sql
-- Unbilled work analysis by age
WITH wip_analysis AS (
  SELECT 
    te.id,
    te.user_id,
    u.first_name || ' ' || u.last_name as fee_earner,
    te.date as work_date,
    te.units / 10.0 as hours,
    (te.units / 10.0) * (te.rate / 10.0) as value,
    m.name as matter_name,
    c.name as client_name,
    EXTRACT(EPOCH FROM (CURRENT_DATE - te.date))/86400 as age_days,
    CASE 
      WHEN EXTRACT(EPOCH FROM (CURRENT_DATE - te.date))/86400 <= 30 THEN '0-30 days'
      WHEN EXTRACT(EPOCH FROM (CURRENT_DATE - te.date))/86400 <= 60 THEN '31-60 days'
      WHEN EXTRACT(EPOCH FROM (CURRENT_DATE - te.date))/86400 <= 90 THEN '61-90 days'
      ELSE '90+ days'
    END as age_bucket
  FROM time_entries te
  JOIN users u ON te.user_id = u.id
  JOIN matter_components mc ON te.matter_component_id = mc.id
  JOIN matter_outcomes mo ON mc.matter_outcome_id = mo.id
  JOIN matters m ON mo.matter_id = m.id
  JOIN clients c ON m.client_id = c.id
  WHERE te.discriminator = 'MatterComponentTimeEntry'
    AND te.billable_type = 1  -- Billable only
    AND te.invoice_id IS NULL  -- Unbilled
    AND te.is_deleted = false
    AND mc.is_deleted = false
    AND mo.is_deleted = false
    AND m.is_deleted = false
    AND c.is_deleted = false
)
SELECT 
  age_bucket,
  COUNT(*) as entry_count,
  SUM(hours) as total_hours,
  SUM(value) as total_value,
  AVG(age_days) as avg_age_days,
  COUNT(DISTINCT user_id) as fee_earner_count,
  COUNT(DISTINCT matter_name) as matter_count
FROM wip_analysis
GROUP BY age_bucket
ORDER BY 
  CASE age_bucket
    WHEN '0-30 days' THEN 1
    WHEN '31-60 days' THEN 2  
    WHEN '61-90 days' THEN 3
    WHEN '90+ days' THEN 4
  END;
```

### 🎯 **Productivity Analysis**

```sql
-- Daily productivity patterns
SELECT 
  EXTRACT(DOW FROM te.date) as day_of_week,
  CASE EXTRACT(DOW FROM te.date)
    WHEN 0 THEN 'Sunday'
    WHEN 1 THEN 'Monday'
    WHEN 2 THEN 'Tuesday'
    WHEN 3 THEN 'Wednesday'
    WHEN 4 THEN 'Thursday'
    WHEN 5 THEN 'Friday'
    WHEN 6 THEN 'Saturday'
  END as day_name,
  COUNT(*) as entry_count,
  SUM(te.units) / 10.0 as total_hours,
  AVG(te.units) / 10.0 as avg_entry_duration,
  SUM(CASE WHEN te.billable_type = 1 THEN te.units ELSE 0 END) / 10.0 as billable_hours,
  ROUND(
    (SUM(CASE WHEN te.billable_type = 1 THEN te.units ELSE 0 END) * 100.0) / 
    SUM(te.units), 1
  ) as billable_percentage
FROM time_entries te
WHERE te.discriminator = 'MatterComponentTimeEntry'
  AND te.is_deleted = false
  AND te.date >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY EXTRACT(DOW FROM te.date)
ORDER BY day_of_week;
```

---

## Integration Points with Other Modules

### 🔗 **Matter Management Integration**
- **File**: [ALP_Matter_Management.md](./ALP_Matter_Management.md)
- **Relationship**: Time entries recorded against matter components
- **Key Logic**: Matter status and rate adjustments affect time entry billing

### 🔗 **Invoicing Integration**
- **File**: [ALP_Invoicing_Business_Logic.md](./ALP_Invoicing_Business_Logic.md)
- **Relationship**: Time entries linked to invoices for billing
- **Key Logic**: Fixed-price allocation affects time entry `billed_amount`

### 🔗 **Service Delivery Integration**  
- **File**: [ALP_Offerings_Service_Delivery.md](./ALP_Offerings_Service_Delivery.md)
- **Relationship**: Time entries recorded against offering-derived matter components
- **Key Logic**: Component estimates vs actual time for template optimization

### 🔗 **Project Management Integration**
- **File**: [ALP_Project_Management.md](./ALP_Project_Management.md)
- **Relationship**: ProjectTaskTimeEntry for internal project tracking
- **Key Logic**: Separate time tracking for firm development vs client work

---

## Critical Enum Mappings

```sql
-- Time Entry Discriminator Types
CASE 
  WHEN te.discriminator = 'MatterComponentTimeEntry' THEN 'Matter Work'
  WHEN te.discriminator = 'ProjectTaskTimeEntry' THEN 'Project Work'
  WHEN te.discriminator = 'SalesTimeEntry' THEN 'Sales Activity'
END

-- Billable Types
CASE 
  WHEN te.billable_type = 1 THEN 'Billable'
  WHEN te.billable_type = 2 THEN 'NonBillable'
  WHEN te.billable_type = 3 THEN 'NonChargeable'
  WHEN te.billable_type = 4 THEN 'ProBono'
END

-- GST Types (for billable entries)
CASE 
  WHEN te.gst_type = 1 THEN 'GST Applicable'
  WHEN te.gst_type = 2 THEN 'GST Free'
END
```

---

## Gotchas & Special Considerations

### ⚠️ **Data Quality Issues**

1. **Units Conversion**: Always divide by 10 for hour calculations
2. **Rate Conversion**: Always divide by 10 for dollar amounts
3. **Discriminator Filtering**: Always filter by appropriate discriminator value
4. **Inheritance Joins**: Only join to tables matching the discriminator type

### ⚠️ **Business Logic Complexities**

1. **Fixed-Price Allocation**: Use `billed_amount` not `rate × units` for revenue
2. **Rate Adjustments**: Matter-level adjustments override user billing rates
3. **WIP Identification**: `invoice_id IS NULL` indicates unbilled work
4. **Time Entry Deletion**: May require invoice reversal for billed entries

### ⚠️ **Performance Considerations**

1. **Discriminator Indexing**: Ensure discriminator field is indexed
2. **Date Range Filtering**: Always include date ranges for large datasets
3. **Matter Component Joins**: Can be expensive for large time entry sets
4. **User Permission Filtering**: Consider user-level security in queries

---

## Example Metabase Queries

### Time Entry Dashboard
```sql
-- Key time metrics for executive dashboard
SELECT 
  DATE_TRUNC('week', te.date) as week_starting,
  COUNT(DISTINCT te.user_id) as active_users,
  SUM(te.units) / 10.0 as total_hours,
  SUM(CASE WHEN te.billable_type = 1 THEN te.units ELSE 0 END) / 10.0 as billable_hours,
  SUM(CASE WHEN te.billable_type = 1 THEN 
    (te.units / 10.0) * (te.rate / 10.0) ELSE 0 END) as billable_value,
  ROUND(
    (SUM(CASE WHEN te.billable_type = 1 THEN te.units ELSE 0 END) * 100.0) / 
    SUM(te.units), 1
  ) as billable_percentage
FROM time_entries te
WHERE te.discriminator = 'MatterComponentTimeEntry'
  AND te.is_deleted = false
  AND te.date >= CURRENT_DATE - INTERVAL '12 weeks'
GROUP BY DATE_TRUNC('week', te.date)
ORDER BY week_starting DESC;
```

### Fee Earner Performance
```sql
-- Individual performance tracking
SELECT 
  u.first_name || ' ' || u.last_name as fee_earner,
  COUNT(te.id) as time_entries,
  SUM(te.units) / 10.0 as total_hours,
  SUM(CASE WHEN te.billable_type = 1 THEN te.units ELSE 0 END) / 10.0 as billable_hours,
  SUM(CASE WHEN te.invoice_id IS NOT NULL THEN te.units ELSE 0 END) / 10.0 as invoiced_hours,
  SUM(CASE WHEN te.invoice_id IS NULL AND te.billable_type = 1 THEN te.units ELSE 0 END) / 10.0 as wip_hours,
  SUM(CASE WHEN te.billable_type = 1 THEN 
    (te.units / 10.0) * (te.rate / 10.0) ELSE 0 END) as total_billable_value
FROM users u
LEFT JOIN time_entries te ON u.id = te.user_id 
  AND te.discriminator = 'MatterComponentTimeEntry'
  AND te.is_deleted = false
  AND te.date >= DATE_TRUNC('month', CURRENT_DATE)
WHERE u.is_deleted = false
  AND u.billing_rate > 0
GROUP BY u.id, u.first_name, u.last_name
HAVING SUM(te.units) > 0
ORDER BY total_billable_value DESC;
```

---

## Links to Related Modules

- **[Matter Management](./ALP_Matter_Management.md)** - Matter components and workflow integration
- **[Invoicing](./ALP_Invoicing_Business_Logic.md)** - Time entry billing and allocation
- **[Service Delivery](./ALP_Offerings_Service_Delivery.md)** - Component estimation vs actual tracking
- **[Project Management](./ALP_Project_Management.md)** - Internal project time tracking
- **[User Management](./ALP_User_Management.md)** - Fee earner rates and permissions

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Related Framework**: [Query Development Framework Summary](./Query_Development_Framework_Summary.md) 