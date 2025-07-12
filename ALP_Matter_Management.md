# ALP Matter Management
## Comprehensive Guide to Legal Matter Lifecycle & Analytics

### Overview & Purpose

The ALP matter management system is the operational heart of the legal practice, orchestrating the delivery of legal services from initial client contact through final resolution. Matters represent instances of legal service delivery, connecting clients, service offerings, resource allocation, time tracking, and billing into unified case management.

**Key Concepts:**
- **Matters**: Individual cases or legal engagements for specific clients
- **Matter Lifecycle**: Structured workflow from lead to completion
- **Status Management**: Formal progression tracking through defined stages
- **Offering Integration**: Service templates instantiated for specific client needs
- **Team Coordination**: Multi-user collaboration on matter delivery

---

## Database Schema

### 📊 **Core Tables**

```sql
-- Main matter entity
matters (
    id, name, description, client_id, reviewer_id, coordinator_id,
    status, estimated_budget, first_contact_date, office_id,
    -- Workflow flags
    waiting_for_external, waiting_for_internal, to_be_followed_up,
    -- Rate adjustments
    apply_rate_adjustment, rate_adjustment_percentage,
    -- Business classification
    law_area_id, law_sub_area_id, segment_id, sub_segment_id,
    offering_category_id, matter_lost_reason, matter_closed_check,
    inserted_at, updated_at, is_deleted
)

-- Matter-outcome relationships (copied from offerings)
matter_outcomes (
    id, matter_id, offering_outcome_id, description, failure, 
    weight, complete, completed_at,
    inserted_at, updated_at, is_deleted
)

-- Matter components (actual work breakdown)
matter_components (
    id, matter_outcome_id, offering_component_id, offering_outcome_component_id,
    title, description, estimated_units, budget, due_date, complete, weight,
    law_sub_area_id, total_units,
    inserted_at, updated_at, is_deleted
)

-- Matter team assignments
matter_team_members (
    matter_id, user_id, role, 
    inserted_at, updated_at, is_deleted
)

-- Matter-offering relationships (many-to-many)
matter_offerings (
    matter_id, offering_id,
    inserted_at, updated_at, is_deleted
)
```

### 🔗 **Key Relationships**

```sql
-- Client relationship
matters.client_id → clients.id

-- User relationships
matters.reviewer_id → users.id     -- Partner/senior oversight
matters.coordinator_id → users.id  -- Day-to-day management

-- Offering integration
matter_outcomes.offering_outcome_id → offering_outcomes.id
matter_components.offering_component_id → offering_components.id

-- Time tracking integration
time_entries.matter_component_id → matter_components.id

-- Invoicing integration
invoices.matter_id → matters.id
```

---

## Matter Status Lifecycle

### 📊 **Status Enum Mapping**

```sql
CASE 
  WHEN m.status = 1 THEN 'ToBeQuoted'
  WHEN m.status = 2 THEN 'QuotedAwaitingAcceptance'  
  WHEN m.status = 3 THEN 'Lost'
  WHEN m.status = 4 THEN 'Open'
  WHEN m.status = 5 THEN 'Closed'
  WHEN m.status = 6 THEN 'Finalised'
  WHEN m.status = 7 THEN 'Deleted'
END as status_description
```

### 🔄 **Business Process Flow**

1. **ToBeQuoted (1)**: Initial inquiry, scoping work required
2. **QuotedAwaitingAcceptance (2)**: Proposal sent, awaiting client decision
3. **Lost (3)**: Client declined or chose competitor ⚠️ **Terminal State**
4. **Open (4)**: Active work in progress
5. **Closed (5)**: Work completed, final billing in progress
6. **Finalised (6)**: Matter completely resolved, all billing complete ✅ **Success State**
7. **Deleted (7)**: Administrative deletion ⚠️ **Terminal State**

### 📈 **Conversion Analytics**

```sql
-- Matter pipeline conversion analysis
WITH matter_progression AS (
  SELECT 
    status,
    CASE 
      WHEN status = 1 THEN 'ToBeQuoted'
      WHEN status = 2 THEN 'QuotedAwaitingAcceptance'
      WHEN status = 3 THEN 'Lost'
      WHEN status = 4 THEN 'Open'
      WHEN status = 5 THEN 'Closed'
      WHEN status = 6 THEN 'Finalised'
      WHEN status = 7 THEN 'Deleted'
    END as status_description,
    COUNT(*) as matter_count,
    AVG(estimated_budget / 10.0) as avg_budget,
    SUM(estimated_budget / 10.0) as total_pipeline_value,
    AVG(EXTRACT(EPOCH FROM (updated_at - inserted_at))/86400) as avg_days_in_status
  FROM matters 
  WHERE is_deleted = false
  GROUP BY status
)
SELECT 
  status_description,
  matter_count,
  avg_budget,
  total_pipeline_value,
  avg_days_in_status,
  -- Conversion metrics
  ROUND(
    (matter_count * 100.0) / SUM(matter_count) OVER(), 2
  ) as percentage_of_total
FROM matter_progression
ORDER BY status;
```

---

## Workflow Management

### ⏰ **Status Flags**

The system uses boolean flags to track workflow dependencies:

```sql
-- Active workflow tracking
SELECT 
  m.name as matter_name,
  m.status,
  CASE 
    WHEN m.waiting_for_external = true THEN 'Waiting for External'
    WHEN m.waiting_for_internal = true THEN 'Waiting for Internal'  
    WHEN m.to_be_followed_up = true THEN 'Follow-up Required'
    ELSE 'Active'
  END as workflow_status,
  -- Days waiting calculation
  EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - m.updated_at))/86400 as days_waiting
FROM matters m
WHERE m.is_deleted = false
  AND m.status = 4  -- Open matters
  AND (m.waiting_for_external = true 
       OR m.waiting_for_internal = true 
       OR m.to_be_followed_up = true);
```

### 👥 **Team Coordination**

```sql
-- Matter team structure analysis
SELECT 
  m.name as matter_name,
  c.name as client_name,
  reviewer.first_name || ' ' || reviewer.last_name as reviewer,
  coordinator.first_name || ' ' || coordinator.last_name as coordinator,
  COUNT(tm.user_id) as team_size,
  STRING_AGG(
    team_member.first_name || ' ' || team_member.last_name, 
    ', ' ORDER BY team_member.last_name
  ) as team_members
FROM matters m
JOIN clients c ON m.client_id = c.id
LEFT JOIN users reviewer ON m.reviewer_id = reviewer.id  
LEFT JOIN users coordinator ON m.coordinator_id = coordinator.id
LEFT JOIN matter_team_members tm ON m.id = tm.matter_id AND tm.is_deleted = false
LEFT JOIN users team_member ON tm.user_id = team_member.id
WHERE m.is_deleted = false
  AND c.is_deleted = false
  AND m.status = 4  -- Open matters
GROUP BY m.id, m.name, c.name, reviewer.first_name, reviewer.last_name,
         coordinator.first_name, coordinator.last_name
ORDER BY team_size DESC;
```

---

## Financial Management

### 💰 **Rate Adjustments**

Matters can have rate adjustments that affect billing calculations:

```sql
-- Rate adjustment impact analysis
SELECT 
  m.name as matter_name,
  m.apply_rate_adjustment,
  m.rate_adjustment_percentage,
  COUNT(te.id) as time_entries,
  SUM(te.units / 10.0) as total_hours,
  -- Standard rates
  SUM((te.units / 10.0) * (te.rate / 10.0)) as standard_value,
  -- Adjusted rates  
  CASE 
    WHEN m.apply_rate_adjustment = true THEN
      SUM((te.units / 10.0) * (te.rate / 10.0) * (1 + m.rate_adjustment_percentage / 100.0))
    ELSE 
      SUM((te.units / 10.0) * (te.rate / 10.0))
  END as adjusted_value,
  -- Rate impact
  CASE 
    WHEN m.apply_rate_adjustment = true THEN
      SUM((te.units / 10.0) * (te.rate / 10.0) * (m.rate_adjustment_percentage / 100.0))
    ELSE 0
  END as rate_adjustment_impact
FROM matters m
JOIN matter_outcomes mo ON m.id = mo.matter_id
JOIN matter_components mc ON mo.id = mc.matter_outcome_id
JOIN time_entries te ON mc.id = te.matter_component_id
WHERE m.is_deleted = false
  AND mo.is_deleted = false
  AND mc.is_deleted = false
  AND te.is_deleted = false
  AND te.discriminator = 'MatterComponentTimeEntry'
  AND te.billable_type = 1  -- Billable time only
GROUP BY m.id, m.name, m.apply_rate_adjustment, m.rate_adjustment_percentage
HAVING COUNT(te.id) > 0
ORDER BY rate_adjustment_impact DESC;
```

### 📊 **Budget vs Actual Analysis**

```sql
-- Matter budget performance
WITH matter_financials AS (
  SELECT 
    m.id as matter_id,
    m.name as matter_name,
    m.estimated_budget / 10.0 as estimated_budget,
    m.status,
    -- Actual costs from time entries
    SUM((te.units / 10.0) * (te.rate / 10.0)) as actual_cost,
    SUM(te.units / 10.0) as total_hours,
    COUNT(te.id) as time_entry_count,
    -- Invoicing status
    SUM(CASE WHEN te.invoice_id IS NOT NULL THEN 
      (te.units / 10.0) * (te.rate / 10.0) ELSE 0 END) as invoiced_amount,
    SUM(CASE WHEN te.invoice_id IS NULL THEN 
      (te.units / 10.0) * (te.rate / 10.0) ELSE 0 END) as wip_amount
  FROM matters m
  LEFT JOIN matter_outcomes mo ON m.id = mo.matter_id AND mo.is_deleted = false
  LEFT JOIN matter_components mc ON mo.id = mc.matter_outcome_id AND mc.is_deleted = false
  LEFT JOIN time_entries te ON mc.id = te.matter_component_id 
    AND te.is_deleted = false 
    AND te.discriminator = 'MatterComponentTimeEntry'
    AND te.billable_type = 1
  WHERE m.is_deleted = false
    AND m.estimated_budget > 0
  GROUP BY m.id, m.name, m.estimated_budget, m.status
)
SELECT 
  matter_name,
  CASE 
    WHEN status = 1 THEN 'ToBeQuoted'
    WHEN status = 2 THEN 'QuotedAwaitingAcceptance'
    WHEN status = 3 THEN 'Lost'
    WHEN status = 4 THEN 'Open'
    WHEN status = 5 THEN 'Closed'
    WHEN status = 6 THEN 'Finalised'
  END as status_description,
  estimated_budget,
  COALESCE(actual_cost, 0) as actual_cost,
  COALESCE(total_hours, 0) as total_hours,
  COALESCE(invoiced_amount, 0) as invoiced_amount,
  COALESCE(wip_amount, 0) as wip_amount,
  -- Budget variance
  CASE 
    WHEN actual_cost > 0 THEN 
      ROUND(((actual_cost - estimated_budget) * 100.0) / estimated_budget, 2)
    ELSE NULL 
  END as budget_variance_percent,
  -- Profitability indicators
  CASE 
    WHEN actual_cost > 0 THEN estimated_budget - actual_cost
    ELSE NULL 
  END as estimated_profit
FROM matter_financials
WHERE time_entry_count > 0  -- Only matters with recorded work
ORDER BY ABS(budget_variance_percent) DESC NULLS LAST;
```

---

## Matter-Offering Integration

### 🔄 **Template Instantiation**

When offerings are applied to matters, the copy-on-create pattern ensures matter-specific customization:

```sql
-- Track offering usage across matters
SELECT 
  o.name as offering_name,
  oc.name as offering_category,
  COUNT(DISTINCT mo.matter_id) as matter_count,
  COUNT(DISTINCT mo.id) as outcome_instances,
  COUNT(DISTINCT mc.id) as component_instances,
  AVG(mc.estimated_units / 10.0) as avg_estimated_hours,
  AVG(mc.total_units / 10.0) as avg_actual_hours,
  -- Success rate analysis
  ROUND(
    (COUNT(CASE WHEN mo.complete = true THEN 1 END) * 100.0) / 
    COUNT(mo.id), 2
  ) as outcome_success_rate
FROM offerings o
JOIN offering_categories oc ON o.category_id = oc.id
LEFT JOIN offering_outcomes oo ON o.id = oo.offering_id
LEFT JOIN matter_outcomes mo ON oo.id = mo.offering_outcome_id
LEFT JOIN matter_components mc ON mo.id = mc.matter_outcome_id
WHERE o.is_deleted = false
  AND oc.is_deleted = false
  AND (oo.is_deleted = false OR oo.id IS NULL)
  AND (mo.is_deleted = false OR mo.id IS NULL)
  AND (mc.is_deleted = false OR mc.id IS NULL)
GROUP BY o.id, o.name, oc.name
HAVING COUNT(DISTINCT mo.matter_id) > 0
ORDER BY matter_count DESC;
```

### 📈 **Service Delivery Performance**

```sql
-- Offering performance by matter outcomes
WITH offering_delivery AS (
  SELECT 
    m.id as matter_id,
    m.name as matter_name,
    m.status as matter_status,
    o.name as offering_name,
    mo.id as matter_outcome_id,
    mo.description as outcome_description,
    mo.complete as outcome_complete,
    COUNT(mc.id) as component_count,
    SUM(mc.estimated_units) as total_estimated_units,
    SUM(COALESCE(mc.total_units, 0)) as total_actual_units,
    SUM(mc.budget) as total_estimated_cost,
    SUM(
      (SELECT SUM((te.units / 10.0) * (te.rate / 10.0))
       FROM time_entries te 
       WHERE te.matter_component_id = mc.id 
         AND te.is_deleted = false
         AND te.discriminator = 'MatterComponentTimeEntry'
      )
    ) as total_actual_cost
  FROM matters m
  JOIN matter_outcomes mo ON m.id = mo.matter_id
  JOIN offering_outcomes oo ON mo.offering_outcome_id = oo.id
  JOIN offerings o ON oo.offering_id = o.id
  LEFT JOIN matter_components mc ON mo.id = mc.matter_outcome_id AND mc.is_deleted = false
  WHERE m.is_deleted = false
    AND mo.is_deleted = false
    AND oo.is_deleted = false
    AND o.is_deleted = false
  GROUP BY m.id, m.name, m.status, o.name, mo.id, mo.description, mo.complete
)
SELECT 
  offering_name,
  COUNT(*) as delivery_instances,
  COUNT(CASE WHEN outcome_complete = true THEN 1 END) as successful_deliveries,
  ROUND(
    (COUNT(CASE WHEN outcome_complete = true THEN 1 END) * 100.0) / COUNT(*), 2
  ) as success_rate_percent,
  AVG(total_estimated_units / 10.0) as avg_estimated_hours,
  AVG(total_actual_units / 10.0) as avg_actual_hours,
  AVG(total_estimated_cost / 10.0) as avg_estimated_cost,
  AVG(total_actual_cost) as avg_actual_cost
FROM offering_delivery
GROUP BY offering_name
HAVING COUNT(*) >= 3  -- Sufficient sample size
ORDER BY success_rate_percent DESC;
```

---

## Analytics Patterns

### 📊 **Matter Pipeline Health**

```sql
-- Comprehensive pipeline analysis
WITH pipeline_metrics AS (
  SELECT 
    CASE 
      WHEN m.status IN (1,2) THEN 'Pipeline'
      WHEN m.status = 3 THEN 'Lost' 
      WHEN m.status = 4 THEN 'Active'
      WHEN m.status IN (5,6) THEN 'Completed'
      WHEN m.status = 7 THEN 'Deleted'
    END as stage,
    m.status,
    COUNT(*) as matter_count,
    SUM(m.estimated_budget / 10.0) as total_value,
    AVG(m.estimated_budget / 10.0) as avg_value,
    AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - m.first_contact_date))/86400) as avg_age_days,
    MIN(m.first_contact_date) as earliest_contact,
    MAX(m.first_contact_date) as latest_contact
  FROM matters m
  WHERE m.is_deleted = false
    AND m.first_contact_date IS NOT NULL
  GROUP BY 
    CASE 
      WHEN m.status IN (1,2) THEN 'Pipeline'
      WHEN m.status = 3 THEN 'Lost'
      WHEN m.status = 4 THEN 'Active' 
      WHEN m.status IN (5,6) THEN 'Completed'
      WHEN m.status = 7 THEN 'Deleted'
    END,
    m.status
)
SELECT 
  stage,
  matter_count,
  total_value,
  avg_value,
  avg_age_days,
  ROUND((matter_count * 100.0) / SUM(matter_count) OVER(), 2) as percentage_of_total,
  ROUND((total_value * 100.0) / SUM(total_value) OVER(), 2) as percentage_of_value
FROM pipeline_metrics
ORDER BY 
  CASE stage 
    WHEN 'Pipeline' THEN 1
    WHEN 'Active' THEN 2
    WHEN 'Completed' THEN 3
    WHEN 'Lost' THEN 4
    WHEN 'Deleted' THEN 5
  END;
```

### 🎯 **Client Portfolio Analysis**

```sql
-- Client matter portfolio overview
SELECT 
  c.name as client_name,
  CASE 
    WHEN c.status = 1 THEN 'Active'
    WHEN c.status = 2 THEN 'Dormant'
    WHEN c.status = 3 THEN 'Inactive'
    WHEN c.status = 4 THEN 'Blacklisted'
  END as client_status,
  COUNT(m.id) as total_matters,
  COUNT(CASE WHEN m.status = 4 THEN 1 END) as active_matters,
  COUNT(CASE WHEN m.status IN (5,6) THEN 1 END) as completed_matters,
  COUNT(CASE WHEN m.status = 3 THEN 1 END) as lost_matters,
  SUM(m.estimated_budget / 10.0) as total_estimated_value,
  AVG(m.estimated_budget / 10.0) as avg_matter_value,
  MIN(m.first_contact_date) as first_contact,
  MAX(m.first_contact_date) as last_contact,
  EXTRACT(EPOCH FROM (MAX(m.first_contact_date) - MIN(m.first_contact_date)))/86400 as client_tenure_days
FROM clients c
LEFT JOIN matters m ON c.id = m.client_id AND m.is_deleted = false
WHERE c.is_deleted = false
GROUP BY c.id, c.name, c.status
HAVING COUNT(m.id) > 0
ORDER BY total_estimated_value DESC;
```

---

## Integration Points with Other Modules

### 🔗 **Time Tracking Integration**
- **File**: [ALP_Time_Tracking.md](./ALP_Time_Tracking.md)
- **Relationship**: Time entries recorded against matter components
- **Key Logic**: Matter status affects time entry creation and billing eligibility

### 🔗 **Invoicing Integration**  
- **File**: [ALP_Invoicing_Business_Logic.md](./ALP_Invoicing_Business_Logic.md)
- **Relationship**: Invoices generated from matter work
- **Key Logic**: Matter rate adjustments affect invoice calculations

### 🔗 **Service Delivery Integration**
- **File**: [ALP_Offerings_Service_Delivery.md](./ALP_Offerings_Service_Delivery.md)
- **Relationship**: Matters instantiate offering templates
- **Key Logic**: Copy-on-create pattern for outcomes and components

### 🔗 **Trust Accounting Integration**
- **File**: [ALP_Trust_Accounting.md](./ALP_Trust_Accounting.md)
- **Relationship**: Matter funds management via trust accounts
- **Key Logic**: Client fund tracking by matter for settlements and payments

---

## Critical Enum Mappings

```sql
-- Matter Status
CASE 
  WHEN m.status = 1 THEN 'ToBeQuoted'
  WHEN m.status = 2 THEN 'QuotedAwaitingAcceptance'  
  WHEN m.status = 3 THEN 'Lost'
  WHEN m.status = 4 THEN 'Open'
  WHEN m.status = 5 THEN 'Closed'
  WHEN m.status = 6 THEN 'Finalised'
  WHEN m.status = 7 THEN 'Deleted'
END

-- Client Status (affects matter analytics)
CASE 
  WHEN c.status = 1 THEN 'Active'
  WHEN c.status = 2 THEN 'Dormant'
  WHEN c.status = 3 THEN 'Inactive' 
  WHEN c.status = 4 THEN 'Blacklisted'
END

-- Workflow Flags (boolean fields)
waiting_for_external = true   -- External dependency
waiting_for_internal = true   -- Internal dependency
to_be_followed_up = true      -- Follow-up required
apply_rate_adjustment = true  -- Custom rates apply
```

---

## Gotchas & Special Considerations

### ⚠️ **Status Transition Logic**

1. **Lost Matters**: Status 3 is terminal - no further work should be recorded
2. **Rate Adjustments**: Only apply to billable time, not disbursements
3. **Team Coordination**: Coordinator assignment required for active matters
4. **Budget Tracking**: Estimates vs actuals can vary significantly

### ⚠️ **Analytics Considerations**

1. **Pipeline Analysis**: Include estimated values for revenue forecasting
2. **Conversion Rates**: Track progression through status lifecycle
3. **Client Relationships**: Factor in client status when analyzing matter performance
4. **Temporal Analysis**: Matter age affects urgency and follow-up requirements

### ⚠️ **Performance Implications**

1. **Complex Joins**: Matter → Component → Time Entry chains are expensive
2. **Status Filtering**: Always filter by `is_deleted = false` and relevant status values
3. **Date Ranges**: Use appropriate date filtering for large datasets
4. **Team Queries**: Matter team joins can multiply result sets

---

## Example Metabase Queries

### Matter Dashboard Overview
```sql
-- Key matter metrics for dashboard
SELECT 
  DATE_TRUNC('month', m.first_contact_date) as month,
  COUNT(CASE WHEN m.status IN (1,2) THEN 1 END) as pipeline_matters,
  COUNT(CASE WHEN m.status = 4 THEN 1 END) as active_matters,
  COUNT(CASE WHEN m.status IN (5,6) THEN 1 END) as completed_matters,
  COUNT(CASE WHEN m.status = 3 THEN 1 END) as lost_matters,
  SUM(CASE WHEN m.status IN (1,2) THEN m.estimated_budget / 10.0 ELSE 0 END) as pipeline_value,
  SUM(CASE WHEN m.status = 4 THEN m.estimated_budget / 10.0 ELSE 0 END) as active_value
FROM matters m
WHERE m.is_deleted = false
  AND m.first_contact_date >= DATE_TRUNC('year', CURRENT_DATE)
GROUP BY DATE_TRUNC('month', m.first_contact_date)
ORDER BY month DESC;
```

### Workflow Management Report
```sql
-- Matters requiring attention
SELECT 
  m.name as matter_name,
  c.name as client_name,
  coordinator.first_name || ' ' || coordinator.last_name as coordinator,
  CASE 
    WHEN m.waiting_for_external = true THEN 'External Dependency'
    WHEN m.waiting_for_internal = true THEN 'Internal Dependency'
    WHEN m.to_be_followed_up = true THEN 'Follow-up Required'
    ELSE 'Active'
  END as workflow_status,
  EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - m.updated_at))/86400 as days_since_update,
  m.estimated_budget / 10.0 as estimated_value
FROM matters m
JOIN clients c ON m.client_id = c.id
LEFT JOIN users coordinator ON m.coordinator_id = coordinator.id
WHERE m.is_deleted = false
  AND c.is_deleted = false
  AND m.status = 4  -- Open matters only
  AND (m.waiting_for_external = true 
       OR m.waiting_for_internal = true 
       OR m.to_be_followed_up = true)
ORDER BY days_since_update DESC;
```

---

## Links to Related Modules

- **[Service Delivery](./ALP_Offerings_Service_Delivery.md)** - How offerings become matters
- **[Time Tracking](./ALP_Time_Tracking.md)** - Recording work against matter components  
- **[Invoicing](./ALP_Invoicing_Business_Logic.md)** - Billing for matter work
- **[Trust Accounting](./ALP_Trust_Accounting.md)** - Client funds management by matter
- **[Project Management](./ALP_Project_Management.md)** - Complex matter coordination

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Related Framework**: [Query Development Framework Summary](./Query_Development_Framework_Summary.md) 