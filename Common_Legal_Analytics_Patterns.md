# Common Legal Analytics Patterns
## Proven SQL Query Templates for Legal Practice Management

### Overview

This document provides tested SQL patterns for common legal practice analytics scenarios. Each pattern includes the business logic, common variations, and performance considerations specific to our legal practice management system.

**⚠️ Important Database Structure Notes:**
- **Column naming**: All database columns use snake_case (e.g., `updated_at`, `is_deleted`)
- **Enums**: All stored as integers, use CASE statements for display values
- **Time entries**: Use table-per-hierarchy inheritance with `discriminator` field
- **Rates**: Stored ×10 (e.g., 450 = $45.00/hour)
- **Soft deletes**: Always filter `WHERE is_deleted = false`

---

## Pattern 1: Matter Pipeline Analysis

### Business Question
"What's the current state of our matter pipeline by status?"

### Core Pattern
```sql
WITH matter_pipeline AS (
  SELECT 
    m.id AS matter_id,
    m.name AS matter_title,
    m.status AS matter_status,
    CASE 
      WHEN m.status = 1 THEN 'ToBeQuoted'
      WHEN m.status = 2 THEN 'QuotedAwaitingAcceptance'
      WHEN m.status = 3 THEN 'Lost'
      WHEN m.status = 4 THEN 'Open'
      WHEN m.status = 5 THEN 'Closed'
      WHEN m.status = 6 THEN 'Finalised'
      WHEN m.status = 7 THEN 'Deleted'
      ELSE 'Unknown'
    END AS status_description,
    c.first_name || ' ' || c.last_name AS client_name,
    o.name AS organisation_name,
    u.first_name || ' ' || u.last_name AS reviewer,
    u2.first_name || ' ' || u2.last_name AS coordinator,
    m.estimated_budget,
    m.inserted_at AS matter_created_date,
    m.updated_at AS last_updated,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - m.updated_at))/86400 AS days_since_update
  FROM matters m
    LEFT JOIN clients cl ON m.client_id = cl.id AND cl.is_deleted = false
    LEFT JOIN contacts c ON cl.primary_contact_id = c.id AND c.is_deleted = false
    LEFT JOIN organisations o ON cl.organisation_id = o.id AND o.is_deleted = false
    LEFT JOIN users u ON m.reviewer_id = u.id AND u.is_deleted = false
    LEFT JOIN users u2 ON m.coordinator_id = u2.id AND u2.is_deleted = false
  WHERE m.is_deleted = false
)
SELECT 
  status_description,
  COUNT(*) AS matter_count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS percentage,
  AVG(estimated_budget) AS avg_estimated_budget,
  SUM(estimated_budget) AS total_pipeline_value,
  AVG(days_since_update) AS avg_days_since_update
FROM matter_pipeline
GROUP BY status_description, matter_status
ORDER BY matter_status;
```

### Variations
- **With Date Filters**: Add `AND m.inserted_at >= CURRENT_DATE - INTERVAL '6 months'`
- **By Office**: Add office joins and grouping
- **With Age Buckets**: Use CASE statements for age ranges

---

## Pattern 2: Revenue Analysis (Billable Time)

### Business Question
"What's our billable revenue by period/user/matter?"

### ⚠️ Critical Business Logic - Invoice Allocation
For **Fixed Price invoices**, time entries don't have direct billing amounts. Instead:
- Each time entry gets allocated a proportional share of the total invoice value
- The 'billed' amount is calculated based on the time entry's contribution to the total work
- This affects profitability analysis - use allocated amounts, not time entry rates
- For revenue analysis, distinguish between:
  - **Time-based invoices**: Revenue = time × rate
  - **Fixed-price invoices**: Revenue = allocated portion of invoice total

### Core Pattern
```sql
WITH billable_revenue AS (
  SELECT 
    te.id AS time_entry_id,
    te.matter_component_id,
    mc.matter_id,
    m.name AS matter_title,
    te.user_id,
    u.first_name || ' ' || u.last_name AS fee_earner,
    te.units,
    te.units / 10.0 AS hours_worked,  -- Convert units to hours (6-minute increments)
    te.billable_type,
    CASE 
      WHEN te.billable_type = 1 THEN 'Billable'
      WHEN te.billable_type = 2 THEN 'NonBillable'
      WHEN te.billable_type = 3 THEN 'NonChargeable'
      WHEN te.billable_type = 4 THEN 'ProBono'
      ELSE 'Unknown'
    END AS billable_type_description,
    te.rate / 10.0 AS hourly_rate,  -- Convert from stored rate (×10)
    CASE WHEN te.billable_type = 1 THEN 
      (te.units / 10.0) * (te.rate / 10.0)
    ELSE 0 
    END AS billable_value,
    te.date AS worked_date,
    te.inserted_at AS entry_created_date
  FROM time_entries te
    INNER JOIN matter_components mc ON te.matter_component_id = mc.id AND mc.is_deleted = false
    INNER JOIN matters m ON mc.matter_id = m.id AND m.is_deleted = false
    INNER JOIN users u ON te.user_id = u.id AND u.is_deleted = false
  WHERE te.is_deleted = false
    AND te.discriminator = 'MatterComponentTimeEntry'
    AND te.billable_type = 1  -- Only billable time
)
SELECT 
  DATE_TRUNC('month', worked_date) AS month,
  fee_earner,
  COUNT(*) AS time_entries,
  SUM(hours_worked) AS total_hours,
  AVG(hourly_rate) AS avg_hourly_rate,
  SUM(billable_value) AS total_revenue
FROM billable_revenue
WHERE worked_date >= DATE_TRUNC('year', CURRENT_DATE)
GROUP BY DATE_TRUNC('month', worked_date), fee_earner
ORDER BY month DESC, total_revenue DESC;
```

### Variations
- **WIP vs Invoiced**: Join to invoice line items using `te.invoice_id`
- **By Matter**: Group by matter details
- **Target vs Actual**: Compare to user targets

---

## Pattern 3: Client Profitability Analysis

### Business Question
"Which clients are most profitable and what's driving the profitability?"

### Core Pattern
```sql
WITH client_metrics AS (
  SELECT 
    cl.id AS client_id,
    COALESCE(
      c.first_name || ' ' || c.last_name,
      o.name,
      'Unknown Client'
    ) AS client_name,
    CASE 
      WHEN cl.status = 1 THEN 'Active'
      WHEN cl.status = 2 THEN 'Dormant'
      WHEN cl.status = 3 THEN 'Inactive'
      WHEN cl.status = 4 THEN 'Blacklisted'
      ELSE 'Unknown'
    END AS client_status,
    COUNT(DISTINCT m.id) AS matter_count,
    COUNT(DISTINCT te.id) AS time_entry_count,
    SUM(te.units) / 10.0 AS total_hours,
    SUM(CASE WHEN te.billable_type = 1 THEN 
      (te.units / 10.0) * (te.rate / 10.0)
    ELSE 0 END) AS billable_revenue,
    SUM(CASE WHEN te.billable_type IN (2,3,4) THEN 
      (te.units / 10.0) * (te.rate / 10.0)
    ELSE 0 END) AS non_billable_cost,
    MIN(m.inserted_at) AS first_matter_date,
    MAX(te.date) AS last_activity_date
  FROM clients cl
    LEFT JOIN contacts c ON cl.primary_contact_id = c.id AND c.is_deleted = false
    LEFT JOIN organisations o ON cl.organisation_id = o.id AND o.is_deleted = false
    LEFT JOIN matters m ON cl.id = m.client_id AND m.is_deleted = false
    LEFT JOIN matter_components mc ON m.id = mc.matter_id AND mc.is_deleted = false
    LEFT JOIN time_entries te ON mc.id = te.matter_component_id 
      AND te.is_deleted = false 
      AND te.discriminator = 'MatterComponentTimeEntry'
  WHERE cl.is_deleted = false
  GROUP BY cl.id, client_name, cl.status
),
client_invoicing AS (
  SELECT 
    cl.id AS client_id,
    COUNT(DISTINCT i.id) AS invoice_count,
    SUM(i.total_invoice_amount) AS total_invoiced,
    SUM(i.total_invoice_amount_incl_gst) AS total_invoiced_incl_gst,
    SUM(CASE WHEN i.status IN (3,4) THEN i.total_invoice_amount ELSE 0 END) AS invoiced_amount,
    SUM(CASE WHEN i.status IN (1,2) THEN i.total_invoice_amount ELSE 0 END) AS draft_amount
  FROM clients cl
    LEFT JOIN matters m ON cl.id = m.client_id AND m.is_deleted = false
    LEFT JOIN invoices i ON m.id = i.matter_id AND i.is_deleted = false
  WHERE cl.is_deleted = false
  GROUP BY cl.id
)
SELECT 
  cm.client_name,
  cm.client_status,
  cm.matter_count,
  cm.total_hours,
  cm.billable_revenue,
  cm.non_billable_cost,
  COALESCE(ci.total_invoiced, 0) AS total_invoiced,
  COALESCE(ci.invoice_count, 0) AS invoice_count,
  -- Profitability metrics
  cm.billable_revenue - cm.non_billable_cost AS net_value,
  CASE WHEN cm.billable_revenue > 0 THEN 
    (cm.billable_revenue - cm.non_billable_cost) / cm.billable_revenue * 100 
  ELSE 0 END AS profit_margin_pct,
  cm.billable_revenue - COALESCE(ci.total_invoiced, 0) AS unbilled_wip,
  -- Client lifecycle
  cm.first_matter_date,
  cm.last_activity_date,
  EXTRACT(EPOCH FROM (cm.last_activity_date - cm.first_matter_date))/86400 AS client_tenure_days
FROM client_metrics cm
  LEFT JOIN client_invoicing ci ON cm.client_id = ci.client_id
WHERE cm.billable_revenue > 0
ORDER BY net_value DESC;
```

---

## Pattern 4: Trust Account Reconciliation

### Business Question
"What's the current trust account balance and recent transaction activity?"

### Core Pattern
```sql
WITH trust_transactions AS (
  SELECT 
    tt.id AS transaction_id,
    ta.name AS trust_account_name,
    ta.account_number,
    tt.transaction_type,
    CASE 
      WHEN tt.transaction_type = 1 THEN 'Deposit'
      WHEN tt.transaction_type = 2 THEN 'Withdrawal'
      WHEN tt.transaction_type = 3 THEN 'TransferOut'
      WHEN tt.transaction_type = 4 THEN 'TransferIn'
      ELSE 'Unknown'
    END AS transaction_type_description,
    tt.amount,
    tt.description,
    tt.transaction_date,
    m.name AS matter_title,
    COALESCE(
      c.first_name || ' ' || c.last_name,
      o.name
    ) AS client_name,
    u.first_name || ' ' || u.last_name AS processed_by,
    tt.inserted_at AS entry_date
  FROM trust_transactions tt
    INNER JOIN trust_accounts ta ON tt.trust_account_id = ta.id AND ta.is_deleted = false
    LEFT JOIN matters m ON tt.matter_id = m.id AND m.is_deleted = false
    LEFT JOIN clients cl ON m.client_id = cl.id AND cl.is_deleted = false
    LEFT JOIN contacts c ON cl.primary_contact_id = c.id AND c.is_deleted = false
    LEFT JOIN organisations o ON cl.organisation_id = o.id AND o.is_deleted = false
    LEFT JOIN users u ON tt.inserted_by_id = u.id AND u.is_deleted = false
  WHERE tt.is_deleted = false
),
account_balances AS (
  SELECT 
    trust_account_name,
    account_number,
    SUM(CASE 
      WHEN transaction_type IN (1, 4) THEN amount  -- Deposits and Transfers In
      WHEN transaction_type IN (2, 3) THEN -amount -- Withdrawals and Transfers Out
      ELSE 0 
    END) AS current_balance,
    COUNT(*) AS total_transactions,
    MAX(transaction_date) AS last_transaction_date
  FROM trust_transactions
  GROUP BY trust_account_name, account_number
)
SELECT 
  ab.trust_account_name,
  ab.account_number,
  ab.current_balance,
  ab.total_transactions,
  ab.last_transaction_date,
  CASE 
    WHEN ab.current_balance < 0 THEN 'OVERDRAWN'
    WHEN ab.current_balance = 0 THEN 'Zero Balance'
    WHEN ab.current_balance > 0 THEN 'Positive Balance'
  END AS balance_status
FROM account_balances ab
ORDER BY ab.current_balance DESC;
```

---

## Pattern 5: Matter Performance Dashboard

### Business Question
"How are our matters performing across key metrics?"

### Core Pattern
```sql
WITH matter_performance AS (
  SELECT 
    m.id AS matter_id,
    m.name AS matter_title,
    m.status,
    CASE 
      WHEN m.status = 1 THEN 'ToBeQuoted'
      WHEN m.status = 2 THEN 'QuotedAwaitingAcceptance'
      WHEN m.status = 3 THEN 'Lost'
      WHEN m.status = 4 THEN 'Open'
      WHEN m.status = 5 THEN 'Closed'
      WHEN m.status = 6 THEN 'Finalised'
      WHEN m.status = 7 THEN 'Deleted'
    END AS status_description,
    COALESCE(
      c.first_name || ' ' || c.last_name,
      o.name
    ) AS client_name,
    u.first_name || ' ' || u.last_name AS reviewer,
    m.estimated_budget,
    m.inserted_at AS matter_start_date,
    m.updated_at AS last_updated,
    -- Time metrics
    COUNT(te.id) AS time_entry_count,
    SUM(te.units) / 10.0 AS total_hours,
    SUM(CASE WHEN te.billable_type = 1 THEN te.units ELSE 0 END) / 10.0 AS billable_hours,
    SUM(CASE WHEN te.billable_type IN (2,3,4) THEN te.units ELSE 0 END) / 10.0 AS non_billable_hours,
    -- Financial metrics
    SUM(CASE WHEN te.billable_type = 1 THEN 
      (te.units / 10.0) * (te.rate / 10.0)
    ELSE 0 END) AS billable_value,
    -- Recent activity
    MAX(te.date) AS last_time_entry_date,
    COUNT(DISTINCT te.user_id) AS contributors_count
  FROM matters m
    LEFT JOIN clients cl ON m.client_id = cl.id AND cl.is_deleted = false
    LEFT JOIN contacts c ON cl.primary_contact_id = c.id AND c.is_deleted = false
    LEFT JOIN organisations o ON cl.organisation_id = o.id AND o.is_deleted = false
    LEFT JOIN users u ON m.reviewer_id = u.id AND u.is_deleted = false
    LEFT JOIN matter_components mc ON m.id = mc.matter_id AND mc.is_deleted = false
    LEFT JOIN time_entries te ON mc.id = te.matter_component_id 
      AND te.is_deleted = false 
      AND te.discriminator = 'MatterComponentTimeEntry'
  WHERE m.is_deleted = false
    AND m.status IN (2, 4)  -- Only quoted/open matters
  GROUP BY 
    m.id, m.name, m.status, client_name, u.first_name || ' ' || u.last_name,
    m.estimated_budget, m.inserted_at, m.updated_at
),
matter_invoicing AS (
  SELECT 
    m.id AS matter_id,
    COUNT(i.id) AS invoice_count,
    SUM(i.total_invoice_amount) AS total_invoiced,
    SUM(CASE WHEN i.status IN (3,4) THEN i.total_invoice_amount ELSE 0 END) AS invoiced_amount,
    SUM(CASE WHEN i.status IN (1,2) THEN i.total_invoice_amount ELSE 0 END) AS draft_amount
  FROM matters m
    LEFT JOIN invoices i ON m.id = i.matter_id AND i.is_deleted = false
  WHERE m.is_deleted = false
  GROUP BY m.id
)
SELECT 
  mp.matter_title,
  mp.status_description,
  mp.client_name,
  mp.reviewer,
  mp.estimated_budget,
  mp.total_hours,
  mp.billable_hours,
  CASE WHEN mp.total_hours > 0 THEN 
    mp.billable_hours / mp.total_hours * 100 
  ELSE 0 END AS billable_percentage,
  mp.billable_value,
  COALESCE(mi.total_invoiced, 0) AS total_invoiced,
  mp.billable_value - COALESCE(mi.total_invoiced, 0) AS unbilled_wip,
  mp.time_entry_count,
  mp.contributors_count,
  mp.matter_start_date,
  mp.last_time_entry_date,
  CURRENT_DATE - mp.last_time_entry_date AS days_since_activity
FROM matter_performance mp
  LEFT JOIN matter_invoicing mi ON mp.matter_id = mi.matter_id
ORDER BY mp.billable_value DESC;
```

---

## Pattern 6: User Productivity Analysis

### Business Question
"How productive are our fee earners and what's their utilization?"

### Core Pattern
```sql
WITH user_productivity AS (
  SELECT 
    u.id AS user_id,
    u.first_name || ' ' || u.last_name AS fee_earner,
    -- Time analysis
    COUNT(te.id) AS time_entry_count,
    SUM(te.units) / 10.0 AS total_hours,
    SUM(CASE WHEN te.billable_type = 1 THEN te.units ELSE 0 END) / 10.0 AS billable_hours,
    SUM(CASE WHEN te.billable_type IN (2,3,4) THEN te.units ELSE 0 END) / 10.0 AS non_billable_hours,
    -- Revenue analysis
    SUM(CASE WHEN te.billable_type = 1 THEN 
      (te.units / 10.0) * (te.rate / 10.0)
    ELSE 0 END) AS billable_revenue,
    AVG(CASE WHEN te.billable_type = 1 THEN te.rate / 10.0 ELSE NULL END) AS avg_billable_rate,
    -- Activity analysis
    COUNT(DISTINCT te.matter_component_id) AS matters_worked_on,
    COUNT(DISTINCT DATE(te.date)) AS active_days,
    MIN(te.date) AS first_entry_date,
    MAX(te.date) AS last_entry_date
  FROM users u
    LEFT JOIN time_entries te ON u.id = te.user_id 
      AND te.is_deleted = false 
      AND te.discriminator = 'MatterComponentTimeEntry'
      AND te.date >= CURRENT_DATE - INTERVAL '3 months'
  WHERE u.is_deleted = false
    AND u.user_type = 1  -- Internal users only
  GROUP BY u.id, u.first_name || ' ' || u.last_name
)
SELECT 
  fee_earner,
  time_entry_count,
  total_hours,
  billable_hours,
  non_billable_hours,
  CASE WHEN total_hours > 0 THEN 
    billable_hours / total_hours * 100 
  ELSE 0 END AS utilization_percentage,
  billable_revenue,
  CASE WHEN billable_hours > 0 THEN 
    billable_revenue / billable_hours 
  ELSE 0 END AS effective_rate,
  avg_billable_rate,
  matters_worked_on,
  active_days,
  CASE WHEN active_days > 0 THEN 
    total_hours / active_days 
  ELSE 0 END AS avg_hours_per_active_day,
  first_entry_date,
  last_entry_date
FROM user_productivity
WHERE time_entry_count > 0
ORDER BY billable_revenue DESC;
```

---

## Performance Optimization Notes

### Recommended Indexes
```sql
-- Core indexes for analytics queries
CREATE INDEX CONCURRENTLY idx_matters_status_deleted ON matters(status, is_deleted);
CREATE INDEX CONCURRENTLY idx_time_entries_discriminator_deleted ON time_entries(discriminator, is_deleted);
CREATE INDEX CONCURRENTLY idx_time_entries_date_billable ON time_entries(date, billable_type) WHERE is_deleted = false;
CREATE INDEX CONCURRENTLY idx_trust_transactions_type_date ON trust_transactions(transaction_type, transaction_date) WHERE is_deleted = false;
CREATE INDEX CONCURRENTLY idx_invoices_status_deleted ON invoices(status, is_deleted);
```

### Query Performance Tips
1. **Always filter by `is_deleted = false`** - This enables index usage
2. **Use discriminator filters early** - For time_entries queries
3. **Date range filters** - Always include reasonable date ranges
4. **Limit result sets** - Use LIMIT for large datasets
5. **Consider materialized views** - For frequently run dashboard queries

### Data Quality Considerations
- **Enum integrity**: Validate that enum values match expected ranges
- **Rate calculations**: Always divide by 10 for display
- **Time calculations**: Units represent 6-minute increments
- **Null handling**: Use COALESCE for client names and optional fields

---

## Pattern 7: Complex Invoice Analytics & WIP Analysis

### Business Question
"What are our actual invoice amounts and how much unbilled work (WIP) do we have?"

### Core Pattern
```sql
-- Complex Invoice Amount Calculation
-- ⚠️ CRITICAL: Invoice amounts are calculated dynamically from components
WITH invoice_calculations AS (
  SELECT 
    i.id as invoice_id,
    i.status,
    i.type as invoice_type,
    CASE 
      WHEN i.status = 1 THEN 'Draft'
      WHEN i.status = 2 THEN 'AwaitingApproval'
      WHEN i.status = 3 THEN 'Approved'
      WHEN i.status = 4 THEN 'Sent'
      WHEN i.status = 5 THEN 'All'
    END as status_name,
    CASE 
      WHEN i.type = 1 THEN 'FixedPrice'
      WHEN i.type = 2 THEN 'TimeEntry'
    END as type_name,
    m.name as matter_name,
    
    -- Time Entry Values (for TimeEntry invoices)
    COALESCE(te_values.time_value, 0) as time_entry_value,
    COALESCE(te_values.time_count, 0) as time_entry_count,
    
    -- Fixed Price Values (for FixedPrice invoices)  
    COALESCE(fp_values.fixed_value, 0) as fixed_price_value,
    COALESCE(fp_values.fixed_count, 0) as fixed_price_count,
    
    -- Disbursements (always included)
    COALESCE(disb_values.disbursement_value, 0) as disbursement_value,
    COALESCE(disb_values.disbursement_count, 0) as disbursement_count,
    
    -- Discounts (always subtracted)
    COALESCE(disc_values.discount_value, 0) as discount_value,
    COALESCE(disc_values.discount_count, 0) as discount_count
    
  FROM invoices i
  INNER JOIN matters m ON i.matter_id = m.id AND m.is_deleted = false
  
  -- Time Entry Values
  LEFT JOIN (
    SELECT 
      te.invoice_id,
      COUNT(*) as time_count,
      SUM(te.units * te.rate / 10.0 * 
          CASE WHEN te.gst_type = 1 THEN 1.10 ELSE 1.0 END) as time_value
    FROM time_entries te
    WHERE te.is_deleted = false
      AND te.discriminator = 'MatterComponentTimeEntry'
      AND te.billable_type = 1
      AND te.invoice_id IS NOT NULL
    GROUP BY te.invoice_id
  ) te_values ON i.id = te_values.invoice_id
  
  -- Fixed Price Values
  LEFT JOIN (
    SELECT 
      fp.invoice_id,
      COUNT(*) as fixed_count,
      SUM(fp.cost * fp.quantity * 
          CASE WHEN fp.gst_type = 1 THEN 1.10 ELSE 1.0 END) as fixed_value
    FROM fixed_price_items fp
    WHERE fp.is_deleted = false
      AND fp.billable_type = 1
      AND fp.invoice_id IS NOT NULL
    GROUP BY fp.invoice_id
  ) fp_values ON i.id = fp_values.invoice_id
  
  -- Disbursement Values
  LEFT JOIN (
    SELECT 
      d.invoice_id,
      COUNT(*) as disbursement_count,
      SUM(d.cost * d.units * 
          CASE WHEN d.gst_type = 1 THEN 1.10 ELSE 1.0 END) as disbursement_value
    FROM disbursements d
    WHERE d.is_deleted = false
      AND d.billable_type = 1
      AND d.invoice_id IS NOT NULL
    GROUP BY d.invoice_id
  ) disb_values ON i.id = disb_values.invoice_id
  
  -- Discount Values
  LEFT JOIN (
    SELECT 
      dc.invoice_id,
      COUNT(*) as discount_count,
      SUM(dc.amount * 
          CASE WHEN dc.gst_type = 1 THEN 1.10 ELSE 1.0 END) as discount_value
    FROM discount_items dc
    WHERE dc.is_deleted = false
      AND dc.invoice_id IS NOT NULL
    GROUP BY dc.invoice_id
  ) disc_values ON i.id = disc_values.invoice_id
  
  WHERE i.is_deleted = false
)
SELECT 
  invoice_id,
  status_name,
  type_name,
  matter_name,
  -- Calculate total based on invoice type (business logic)
  CASE 
    WHEN invoice_type = 1 THEN  -- FixedPrice
      fixed_price_value + disbursement_value - discount_value
    WHEN invoice_type = 2 THEN  -- TimeEntry
      time_entry_value + disbursement_value - discount_value
    ELSE 0
  END as calculated_invoice_total,
  time_entry_count,
  fixed_price_count,
  disbursement_count,
  discount_count
FROM invoice_calculations
ORDER BY calculated_invoice_total DESC;
```

### Variations
- **WIP Analysis**: Filter `te.invoice_id IS NULL` for unbilled time
- **Billing Efficiency**: Calculate invoiced vs unbilled time ratios
- **Component Breakdown**: Analyze by time vs fixed price vs disbursements

---

## Pattern 8: Work in Progress (WIP) Analysis

### Business Question
"How much billable work is completed but not yet invoiced?"

### Core Pattern
```sql
-- WIP (Work in Progress) Analysis
WITH wip_summary AS (
  SELECT 
    m.id as matter_id,
    m.name as matter_name,
    CASE 
      WHEN m.status = 4 THEN 'Open'
      WHEN m.status = 5 THEN 'Closed'
      ELSE 'Other'
    END as matter_status,
    cl.client_name,
    u.first_name || ' ' || u.last_name as responsible_lawyer,
    
    -- Total billable time
    COUNT(te_all.id) as total_time_entries,
    SUM(te_all.units) / 10.0 as total_billable_hours,
    SUM(te_all.units * te_all.rate / 100.0) as total_billable_value,
    
    -- Invoiced time
    COUNT(te_invoiced.id) as invoiced_time_entries,
    SUM(te_invoiced.units) / 10.0 as invoiced_hours,
    SUM(te_invoiced.units * te_invoiced.rate / 100.0) as invoiced_value,
    
    -- WIP (unbilled) time
    COUNT(te_wip.id) as wip_time_entries,
    SUM(te_wip.units) / 10.0 as wip_hours,
    SUM(te_wip.units * te_wip.rate / 100.0) as wip_value,
    
    -- Calculate billing efficiency
    CASE WHEN COUNT(te_all.id) > 0 THEN 
      COUNT(te_invoiced.id) * 100.0 / COUNT(te_all.id)
    ELSE 0 END as billing_efficiency_pct
    
  FROM matters m
  INNER JOIN clients cl ON m.client_id = cl.id AND cl.is_deleted = false
  INNER JOIN contacts c ON cl.primary_contact_id = c.id AND c.is_deleted = false
  INNER JOIN users u ON m.reviewer_id = u.id AND u.is_deleted = false
  
  -- All billable time entries
  LEFT JOIN time_entries te_all ON m.id = te_all.matter_id
    AND te_all.is_deleted = false
    AND te_all.discriminator = 'MatterComponentTimeEntry'
    AND te_all.billable_type = 1
    
  -- Invoiced time entries
  LEFT JOIN time_entries te_invoiced ON m.id = te_invoiced.matter_id
    AND te_invoiced.is_deleted = false
    AND te_invoiced.discriminator = 'MatterComponentTimeEntry'
    AND te_invoiced.billable_type = 1
    AND te_invoiced.invoice_id IS NOT NULL
    
  -- WIP time entries (not yet invoiced)
  LEFT JOIN time_entries te_wip ON m.id = te_wip.matter_id
    AND te_wip.is_deleted = false
    AND te_wip.discriminator = 'MatterComponentTimeEntry'
    AND te_wip.billable_type = 1
    AND te_wip.invoice_id IS NULL
    
  WHERE m.is_deleted = false
    AND m.status IN (4, 5)  -- Open or Closed matters
  GROUP BY m.id, m.name, m.status, cl.client_name, u.first_name, u.last_name
)
SELECT 
  matter_name,
  matter_status,
  client_name,
  responsible_lawyer,
  total_billable_hours,
  invoiced_hours,
  wip_hours,
  wip_value,
  billing_efficiency_pct,
  -- Age of oldest WIP
  CASE WHEN wip_hours > 0 THEN 
    'Has unbilled work'
  ELSE 'Fully billed'
  END as wip_status
FROM wip_summary
WHERE total_billable_value > 0
ORDER BY wip_value DESC, billing_efficiency_pct ASC;
```

### Variations
- **By Fee Earner**: Group by individual lawyers
- **Aging Analysis**: Include time since last WIP entry
- **Target Analysis**: Compare to billing target percentages

### Business Value
- **Cash Flow Management**: Identify billable work ready for invoicing
- **Efficiency Monitoring**: Track billing conversion rates
- **Resource Planning**: Understand true revenue pipeline 