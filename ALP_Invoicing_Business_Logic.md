# ALP Invoicing Business Logic
## Comprehensive Guide to Invoice Complexity & Analytics

### Overview & Purpose

The ALP invoicing system is one of the most complex modules in the application, featuring multiple invoice types, dynamic amount calculations, fixed-price allocation logic, and intricate relationships between time entries, line items, and final billing amounts.

**Key Complexity Areas:**
- **Dual Invoice Types**: Time Entry vs Fixed Price billing models
- **Dynamic Amount Calculation**: Invoice totals calculated from constituent components, not stored directly
- **Fixed-Price Allocation**: Proportional sharing of invoice totals across time entries
- **Line Item Dependency**: All amounts must be calculated from `invoice_line_items` table
- **GST Complexity**: Multiple GST types with automatic calculations

---

## Database Schema

### Core Tables
```sql
-- Invoice header with type and status
invoices (
    id, type, status, matter_id, total_invoice_amount, 
    total_invoice_amount_incl_gst, inserted_at, is_deleted
)

-- Constituent line items (THE SOURCE OF TRUTH for amounts)
invoice_line_items (
    id, invoice_id, description, amount, gst_type, 
    line_item_type, inserted_at, is_deleted
)

-- Time entries linked to invoices
time_entries (
    id, matter_component_id, invoice_id, units, rate, 
    billable_type, billed_amount, discriminator, is_deleted
)

-- Fixed price items for Type 1 invoices
fixed_price_items (
    id, invoice_id, description, cost, quantity, 
    gst_type, inserted_at, is_deleted
)

-- Disbursements (always included regardless of invoice type)
disbursements (
    id, invoice_id, description, amount, gst_type, 
    inserted_at, is_deleted
)

-- Discount items (always subtracted)
discount_items (
    id, invoice_id, description, amount, 
    inserted_at, is_deleted
)
```

### Relationships
- **One-to-Many**: `invoices` → `invoice_line_items`
- **Many-to-One**: `time_entries` → `invoices` (via `invoice_id`)
- **Matter-based**: All invoices belong to specific matters

---

## Invoice Types & Calculation Logic

### 🕐 **Type 2: TimeEntry Invoices**

**Calculation Formula:**
```
Total = Time Entry Values + Disbursements - Discounts
Time Entry Value = (units ÷ 10) × (rate ÷ 10) × GST multiplier
```

**Business Logic:**
- **Direct Billing**: Time entries billed at their recorded rates
- **Linear Calculation**: Each time entry contributes exactly `hours × rate`
- **Simple Aggregation**: Sum all time entry values, add disbursements, subtract discounts

**Analytics Implications:**
- Revenue directly traceable to individual time entries
- Profitability = billable time value - internal costs
- Rate analysis straightforward (actual rates used)

### 💰 **Type 1: FixedPrice Invoices**

**Calculation Formula:**
```
Total = Fixed Price Items + Disbursements - Discounts
Fixed Price Value = (cost × quantity) × GST multiplier
```

**⚠️ Critical Fixed-Price Allocation Logic:**
- **Time Entry Challenge**: Associated time entries don't have direct billing amounts
- **Proportional Allocation**: Each time entry receives a share of the total invoice value
- **Allocation Formula**: 
  ```
  Time Entry Billed Amount = (Time Entry Contribution ÷ Total Work) × Total Invoice Value
  ```
- **Contribution Calculation**: Based on time units, complexity weighting, or other business rules

**Business Logic Example:**
```
Fixed Price Invoice: $10,000
Time Entry A: 40 hours (40% of total work) → Allocated $4,000
Time Entry B: 60 hours (60% of total work) → Allocated $6,000
```

**Analytics Implications:**
- Revenue analysis must use allocated amounts, not time entry rates
- Profitability calculation more complex (allocated vs cost-based)
- Rate analysis meaningless (fixed price doesn't reflect hourly rates)

---

## Critical Business Logic Patterns

### 🚨 **Amount Storage Issue**

**Problem**: Invoice `total_invoice_amount` fields often show `0E-20` (essentially zero)

**Root Cause**: 
- Historic data migration issues
- Calculation logic relies on dynamic aggregation
- Stored totals not maintained consistently

**Solution for Analytics**:
```sql
-- NEVER use stored amounts
SELECT i.total_invoice_amount  -- ❌ DON'T DO THIS

-- ALWAYS calculate from line items  
SELECT SUM(ili.amount) as calculated_total  -- ✅ CORRECT APPROACH
FROM invoices i
JOIN invoice_line_items ili ON i.id = ili.invoice_id
WHERE ili.is_deleted = false
```

### 💡 **Line Item Dependency**

**All invoice analytics MUST aggregate from line items:**

```sql
-- Standard invoice amount calculation
WITH invoice_totals AS (
  SELECT 
    i.id,
    i.type,
    i.status,
    SUM(CASE 
      WHEN ili.gst_type = 1 THEN ili.amount * 1.1  -- Add 10% GST
      ELSE ili.amount 
    END) as calculated_amount_incl_gst,
    SUM(ili.amount) as calculated_amount_excl_gst,
    COUNT(ili.id) as line_item_count
  FROM invoices i
  JOIN invoice_line_items ili ON i.id = ili.invoice_id
  WHERE i.is_deleted = false 
    AND ili.is_deleted = false
  GROUP BY i.id, i.type, i.status
)
SELECT * FROM invoice_totals;
```

### 🔄 **GST Handling Logic**

**GST Types:**
- **Type 1**: GST applicable (add 10%)
- **Type 2**: GST-free (no addition)

**Automatic GST Calculation:**
```sql
-- GST calculation for line items
SELECT 
  ili.amount as base_amount,
  CASE 
    WHEN ili.gst_type = 1 THEN ili.amount * 0.1
    ELSE 0 
  END as gst_amount,
  CASE 
    WHEN ili.gst_type = 1 THEN ili.amount * 1.1
    ELSE ili.amount 
  END as total_including_gst
FROM invoice_line_items ili;
```

---

## Invoice Status Workflow

### Status Enum Mapping
```sql
CASE 
  WHEN i.status = 1 THEN 'Draft'
  WHEN i.status = 2 THEN 'AwaitingApproval' 
  WHEN i.status = 3 THEN 'Approved'
  WHEN i.status = 4 THEN 'Sent'
  WHEN i.status = 5 THEN 'All'  -- Special query status
END as status_description
```

### Business Process Flow
1. **Draft (1)**: Invoice created, can be edited freely
2. **AwaitingApproval (2)**: Submitted for partner review
3. **Approved (3)**: Approved by partner, ready to send
4. **Sent (4)**: Delivered to client, awaiting payment

### Analytics Implications
- **Revenue Recognition**: Only include status 3,4 for revenue reporting
- **Pipeline Analysis**: Track conversion rates between statuses
- **Aging Analysis**: Time spent in each status affects cash flow

---

## Common Analytics Patterns

### 📊 **Revenue Analysis**

```sql
-- Invoice revenue by type and period
WITH invoice_revenue AS (
  SELECT 
    i.id,
    i.type,
    CASE WHEN i.type = 1 THEN 'FixedPrice' ELSE 'TimeEntry' END as invoice_type,
    i.status,
    CASE 
      WHEN i.status = 1 THEN 'Draft'
      WHEN i.status = 2 THEN 'AwaitingApproval'
      WHEN i.status = 3 THEN 'Approved' 
      WHEN i.status = 4 THEN 'Sent'
    END as status_description,
    m.name as matter_name,
    c.name as client_name,
    SUM(ili.amount) as calculated_amount,
    COUNT(ili.id) as line_item_count,
    i.inserted_at::date as invoice_date
  FROM invoices i
  JOIN invoice_line_items ili ON i.id = ili.invoice_id
  JOIN matters m ON i.matter_id = m.id
  JOIN clients c ON m.client_id = c.id
  WHERE i.is_deleted = false 
    AND ili.is_deleted = false
    AND m.is_deleted = false
    AND c.is_deleted = false
  GROUP BY i.id, i.type, i.status, m.name, c.name, i.inserted_at
)
SELECT 
  invoice_type,
  status_description,
  COUNT(*) as invoice_count,
  SUM(calculated_amount) as total_revenue,
  AVG(calculated_amount) as avg_invoice_amount,
  AVG(line_item_count) as avg_line_items
FROM invoice_revenue
WHERE status_description IN ('Approved', 'Sent')  -- Only recognize revenue for sent invoices
GROUP BY invoice_type, status_description
ORDER BY invoice_type, total_revenue DESC;
```

### 📈 **WIP (Work in Progress) Analysis**

```sql
-- Unbilled work analysis  
SELECT 
  m.name as matter_name,
  c.name as client_name,
  COUNT(te.id) as unbilled_time_entries,
  SUM(te.units) / 10.0 as unbilled_hours,
  SUM((te.units / 10.0) * (te.rate / 10.0)) as unbilled_value,
  MAX(te.date) as last_unbilled_work_date
FROM time_entries te
JOIN matter_components mc ON te.matter_component_id = mc.id
JOIN matter_outcomes mo ON mc.matter_outcome_id = mo.id  
JOIN matters m ON mo.matter_id = m.id
JOIN clients c ON m.client_id = c.id
WHERE te.is_deleted = false
  AND te.discriminator = 'MatterComponentTimeEntry'
  AND te.billable_type = 1  -- Billable
  AND te.invoice_id IS NULL  -- Not yet invoiced
  AND mc.is_deleted = false
  AND mo.is_deleted = false
  AND m.is_deleted = false
  AND c.is_deleted = false
GROUP BY m.id, m.name, c.name
HAVING SUM((te.units / 10.0) * (te.rate / 10.0)) > 0
ORDER BY unbilled_value DESC;
```

### 🎯 **Fixed-Price Allocation Analysis**

```sql
-- Analysis of fixed-price invoice allocations
WITH fixed_price_invoices AS (
  SELECT 
    i.id as invoice_id,
    SUM(ili.amount) as total_invoice_amount,
    COUNT(DISTINCT te.id) as time_entry_count,
    SUM(te.units) as total_units,
    SUM(te.billed_amount) as total_allocated_amount
  FROM invoices i
  JOIN invoice_line_items ili ON i.id = ili.invoice_id
  JOIN time_entries te ON i.id = te.invoice_id
  WHERE i.type = 1  -- Fixed Price
    AND i.is_deleted = false
    AND ili.is_deleted = false
    AND te.is_deleted = false
    AND te.discriminator = 'MatterComponentTimeEntry'
  GROUP BY i.id
)
SELECT 
  invoice_id,
  total_invoice_amount,
  time_entry_count,
  total_units / 10.0 as total_hours,
  total_allocated_amount / 10.0 as total_allocated,
  (total_allocated_amount / 10.0) / (total_units / 10.0) as avg_allocated_rate
FROM fixed_price_invoices
ORDER BY total_invoice_amount DESC;
```

---

## Integration Points with Other Modules

### 🔗 **Time Tracking Integration**
- **File**: [ALP_Time_Tracking.md](./ALP_Time_Tracking.md)
- **Relationship**: Time entries linked via `invoice_id`
- **Key Logic**: Fixed-price allocation affects time entry `billed_amount`

### 🔗 **Matter Management Integration**  
- **File**: [ALP_Matter_Management.md](./ALP_Matter_Management.md)
- **Relationship**: All invoices belong to specific matters
- **Key Logic**: Matter status affects invoice creation and approval

### 🔗 **Trust Accounting Integration**
- **File**: [ALP_Trust_Accounting.md](./ALP_Trust_Accounting.md)  
- **Relationship**: Invoice payments may involve trust account transfers
- **Key Logic**: Client funds management for invoice settlement

---

## Critical Enum Mappings

```sql
-- Invoice Types
CASE 
  WHEN i.type = 1 THEN 'FixedPrice'
  WHEN i.type = 2 THEN 'TimeEntry'
END

-- Invoice Status  
CASE 
  WHEN i.status = 1 THEN 'Draft'
  WHEN i.status = 2 THEN 'AwaitingApproval'
  WHEN i.status = 3 THEN 'Approved'
  WHEN i.status = 4 THEN 'Sent'
  WHEN i.status = 5 THEN 'All'
END

-- GST Types
CASE 
  WHEN gst_type = 1 THEN 'GST Applicable'
  WHEN gst_type = 2 THEN 'GST Free'
END

-- Billable Types (for time entries)
CASE 
  WHEN billable_type = 1 THEN 'Billable'
  WHEN billable_type = 2 THEN 'NonBillable' 
  WHEN billable_type = 3 THEN 'NonChargeable'
  WHEN billable_type = 4 THEN 'ProBono'
END
```

---

## Gotchas & Special Considerations

### ⚠️ **Fixed-Price Allocation Gotchas**

1. **Rate Analysis Invalid**: Don't analyze "rates" on fixed-price matters - use allocated amounts
2. **Profitability Complex**: Cost = actual time cost, Revenue = allocated portion of fixed price
3. **Historical Changes**: Allocation formulas may change over time
4. **Partial Delivery**: Fixed-price invoices may not include all planned work

### ⚠️ **Amount Calculation Gotchas**

1. **Never Trust Stored Totals**: Always calculate from line items
2. **GST Consistency**: Ensure GST calculations match business rules
3. **Soft Deletes**: Always filter `is_deleted = false`
4. **Null Invoice IDs**: Time entries with `invoice_id IS NULL` represent unbilled work

### ⚠️ **Performance Considerations**

1. **Large Joins**: Invoice line item joins can be expensive on large datasets
2. **Date Filtering**: Always include date ranges in analytics queries
3. **Indexing**: Ensure `invoice_id`, `matter_id`, `status` fields are indexed
4. **Aggregation**: Use CTEs for complex multi-step calculations

---

## Example Metabase Queries

### Quick Revenue Dashboard
```sql
-- Monthly revenue summary
SELECT 
  DATE_TRUNC('month', i.inserted_at) as month,
  CASE WHEN i.type = 1 THEN 'Fixed Price' ELSE 'Time Entry' END as invoice_type,
  COUNT(*) as invoice_count,
  SUM(ili.amount) as revenue,
  AVG(ili.amount) as avg_invoice_amount
FROM invoices i
JOIN invoice_line_items ili ON i.id = ili.invoice_id  
WHERE i.status IN (3,4)  -- Approved/Sent only
  AND i.is_deleted = false
  AND ili.is_deleted = false
  AND i.inserted_at >= DATE_TRUNC('year', CURRENT_DATE)
GROUP BY DATE_TRUNC('month', i.inserted_at), i.type
ORDER BY month DESC, invoice_type;
```

### Invoice Pipeline Health
```sql
-- Invoice workflow analysis
SELECT 
  CASE 
    WHEN i.status = 1 THEN 'Draft'
    WHEN i.status = 2 THEN 'Awaiting Approval'
    WHEN i.status = 3 THEN 'Approved' 
    WHEN i.status = 4 THEN 'Sent'
  END as status,
  COUNT(*) as invoice_count,
  SUM(ili.amount) as total_value,
  AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - i.inserted_at))/86400) as avg_age_days
FROM invoices i
JOIN invoice_line_items ili ON i.id = ili.invoice_id
WHERE i.is_deleted = false 
  AND ili.is_deleted = false
GROUP BY i.status
ORDER BY i.status;
```

---

## Links to Related Modules

- **[Time Tracking](./ALP_Time_Tracking.md)** - Time entry allocation and billing logic
- **[Matter Management](./ALP_Matter_Management.md)** - Matter-invoice relationships and workflows  
- **[Trust Accounting](./ALP_Trust_Accounting.md)** - Payment processing and client funds
- **[Financial Management](./ALP_Financial_Management.md)** - Revenue recognition and reporting
- **[Service Delivery](./ALP_Offerings_Service_Delivery.md)** - How offerings translate to billable work

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Related Framework**: [Query Development Framework Summary](./Query_Development_Framework_Summary.md) 