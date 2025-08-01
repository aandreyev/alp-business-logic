# ALP Analytics Reference Guide

## Overview
This document provides essential reference information for writing analytics queries against the ALP legal practice management system database. Use this in conjunction with the `ALP_Database_Structure.sql` file.

## Critical Business Logic & Calculations

### 1. Time Tracking & Billing Calculations

**Time Entry Rate Calculation:**
```sql
-- Time entries store rates in 10ths (e.g., 450 = $45.00)
-- All time calculations use: Units * Rate / 10.0
SELECT 
    units * rate / 10.0 as time_value,
    units * rate / 10.0 * (CASE WHEN gst_type = 1 THEN 1.10 ELSE 1.0 END) as time_value_inc_gst
FROM time_entries;
```

**Billable Types:**
- `1` = Billable
- `2` = Non-Billable  
- `3` = Non-Chargeable
- `4` = Pro Bono

**GST Types:**
- `1` = GST (10% GST applicable)
- `2` = GST Export (0% GST)
- `3` = GST BAS Exclude (0% GST)

### 2. Invoice Calculations

**Total Invoice Value (Complex Business Logic):**
```sql
-- Fixed Price Invoices
SELECT 
    COALESCE(SUM(fpi.cost * fpi.quantity * 
        CASE WHEN fpi.gst_type = 1 THEN 1.10 ELSE 1.0 END), 0) +
    COALESCE(SUM(d.cost * d.units * 
        CASE WHEN d.gst_type = 1 THEN 1.10 ELSE 1.0 END), 0) -
    COALESCE(SUM(di.amount * 
        CASE WHEN di.gst_type = 1 THEN 1.10 ELSE 1.0 END), 0) as total_invoice_value_inc_gst
FROM invoices i
LEFT JOIN fixed_price_items fpi ON i.id = fpi.invoice_id AND fpi.billable_type = 1
LEFT JOIN disbursements d ON i.id = d.invoice_id AND d.billable_type = 1  
LEFT JOIN discount_items di ON i.id = di.invoice_id
WHERE i.type = 1; -- Fixed Price

-- Time Entry Invoices
SELECT 
    COALESCE(SUM(te.units * te.rate / 10.0 * 
        CASE WHEN te.gst_type = 1 THEN 1.10 ELSE 1.0 END), 0) +
    COALESCE(SUM(d.cost * d.units * 
        CASE WHEN d.gst_type = 1 THEN 1.10 ELSE 1.0 END), 0) -
    COALESCE(SUM(di.amount * 
        CASE WHEN di.gst_type = 1 THEN 1.10 ELSE 1.0 END), 0) as total_invoice_value_inc_gst
FROM invoices i
LEFT JOIN matter_component_time_entries te ON i.id = te.invoice_id AND te.billable_type = 1
LEFT JOIN disbursements d ON i.id = d.invoice_id AND d.billable_type = 1
LEFT JOIN discount_items di ON i.id = di.invoice_id  
WHERE i.type = 2; -- Time Entry
```

### 3. Trust Account Calculations

**Matter Trust Balance:**
```sql
SELECT 
    m.id as matter_id,
    COALESCE(SUM(CASE WHEN tt.transaction_type = 1 THEN tt.amount ELSE 0 END), 0) as deposits,
    COALESCE(SUM(CASE WHEN tt.transaction_type = 2 THEN tt.amount ELSE 0 END), 0) as withdrawals,
    COALESCE(SUM(CASE WHEN tt.transaction_type = 3 THEN tt.amount ELSE 0 END), 0) as transfers_out,
    COALESCE(SUM(CASE WHEN tt.transaction_type = 4 THEN tt.amount ELSE 0 END), 0) as transfers_in,
    COALESCE(SUM(CASE WHEN tt.transaction_type = 1 THEN tt.amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN tt.transaction_type = 2 THEN tt.amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN tt.transaction_type = 3 THEN tt.amount ELSE 0 END), 0) +
    COALESCE(SUM(CASE WHEN tt.transaction_type = 4 THEN tt.amount ELSE 0 END), 0) as trust_balance
FROM matters m
LEFT JOIN trust_transactions tt ON m.id = tt.matter_id 
    AND tt.trust_account_transaction_type = 1 -- MatterTransaction
GROUP BY m.id;
```

**Trust Transaction Types:**
- `1` = Deposit
- `2` = Withdrawal  
- `3` = Transfer Out
- `4` = Transfer In

## Enum Values Reference

### Matter Status Values
```sql
-- matters.status values:
-- 1 = ToBeQuoted
-- 2 = QuotedAwaitingAcceptance  
-- 3 = Lost
-- 4 = Open
-- 5 = Closed
-- 6 = Finalised
-- 7 = Deleted
```

### Contact Status Values
```sql
-- contacts.status values:
-- 1 = Active
-- 2 = Dormant
-- 3 = Inactive
-- 4 = Blacklisted
-- 5 = Deceased
```

### Invoice Status Values
```sql
-- invoices.status values:
-- 1 = Draft
-- 2 = AwaitingApproval
-- 3 = Approved
-- 4 = Sent
-- 5 = All (used for filtering)
```

### Contract Status Values
```sql
-- contracts.status values:
-- 0 = All
-- 1 = Draft
-- 2 = InProgress
-- 3 = Signed
-- 4 = Expired
-- 5 = Terminated
-- 6 = Archived
-- 7 = Declined
```

### Asset Status Values
```sql
-- assets.status values:
-- 1 = Available
-- 2 = AssignPendingApproval
-- 3 = Assigned
-- 4 = ReturnPendingApproval
-- 5 = DisposePendingApproval
-- 6 = Disposed
```

## Key Relationships & Joins

### 1. Client Hierarchy
```sql
-- Complete client view with contacts and organizations
SELECT 
    c.id as client_id,
    pc.first_name || ' ' || pc.last_name as primary_contact,
    sc.first_name || ' ' || sc.last_name as secondary_contact,
    o.name as organisation_name,
    CASE 
        WHEN sc.id IS NOT NULL AND o.id IS NOT NULL THEN 
            o.name || ' - ' || pc.first_name || ' ' || pc.last_name || ' and ' || sc.first_name || ' ' || sc.last_name
        WHEN sc.id IS NOT NULL THEN 
            pc.first_name || ' ' || pc.last_name || ' and ' || sc.first_name || ' ' || sc.last_name
        WHEN o.id IS NOT NULL THEN 
            o.name || ' - ' || pc.first_name || ' ' || pc.last_name
        ELSE 
            pc.first_name || ' ' || pc.last_name
    END as client_name
FROM clients c
JOIN contacts pc ON c.primary_contact_id = pc.id
LEFT JOIN contacts sc ON c.secondary_contact_id = sc.id  
LEFT JOIN organisations o ON c.organisation_id = o.id;
```

### 2. Matter Performance Analytics
```sql
-- Matter profitability and performance
SELECT 
    m.id,
    m.name,
    m.status,
    m.estimated_budget,
    reviewer.first_name || ' ' || reviewer.last_name as reviewer_name,
    coordinator.first_name || ' ' || coordinator.last_name as coordinator_name,
    -- Time tracking
    COALESCE(SUM(te.units), 0) as total_time_units,
    COALESCE(SUM(te.units * te.rate / 10.0), 0) as total_time_value,
    COALESCE(SUM(CASE WHEN te.billable_type = 1 THEN te.units * te.rate / 10.0 ELSE 0 END), 0) as billable_time_value,
    COALESCE(SUM(CASE WHEN te.billable_type = 1 AND te.invoice_id IS NOT NULL THEN te.units * te.rate / 10.0 ELSE 0 END), 0) as invoiced_time_value,
    -- Invoice summary
    COUNT(DISTINCT inv.id) as invoice_count,
    COALESCE(SUM(inv.total_invoice_amount_incl_gst), 0) as total_invoiced,
    COALESCE(SUM(inv.received_payments), 0) as total_received,
    COALESCE(SUM(inv.outstanding_amount), 0) as total_outstanding
FROM matters m
LEFT JOIN users reviewer ON m.reviewer_id = reviewer.id
LEFT JOIN users coordinator ON m.coordinator_id = coordinator.id
LEFT JOIN matter_components mc ON m.id = mc.matter_id
LEFT JOIN matter_component_time_entries te ON mc.id = te.matter_component_id
LEFT JOIN invoices inv ON m.id = inv.matter_id
WHERE m.is_deleted = FALSE
GROUP BY m.id, reviewer.id, coordinator.id;
```

### 3. User Productivity Analytics
```sql
-- User time tracking and productivity
SELECT 
    u.id,
    u.first_name || ' ' || u.last_name as user_name,
    u.is_legal,
    COALESCE(o.abbreviation, 'No Office') as office_name,
    COALESCE(be.legal_entity_name, 'No Entity') as business_entity,
    -- Matter time
    COALESCE(SUM(mte.units), 0) as matter_time_units,
    COALESCE(SUM(mte.units * mte.rate / 10.0), 0) as matter_time_value,
    COALESCE(SUM(CASE WHEN mte.billable_type = 1 THEN mte.units * mte.rate / 10.0 ELSE 0 END), 0) as billable_matter_value,
    -- Project time  
    COALESCE(SUM(pte.units), 0) as project_time_units,
    COALESCE(SUM(pte.units * pte.rate / 10.0), 0) as project_time_value,
    -- Sales time
    COALESCE(SUM(ste.units), 0) as sales_time_units,
    COALESCE(SUM(ste.units * ste.rate / 10.0), 0) as sales_time_value,
    -- Totals
    COALESCE(SUM(mte.units), 0) + COALESCE(SUM(pte.units), 0) + COALESCE(SUM(ste.units), 0) as total_time_units,
    COALESCE(SUM(mte.units * mte.rate / 10.0), 0) + COALESCE(SUM(pte.units * pte.rate / 10.0), 0) + COALESCE(SUM(ste.units * ste.rate / 10.0), 0) as total_time_value
FROM users u
LEFT JOIN offices o ON u.office_id = o.id
LEFT JOIN business_entities be ON o.business_entity_id = be.id
LEFT JOIN matter_component_time_entries mte ON u.id = mte.user_id
LEFT JOIN project_task_time_entries pte ON u.id = pte.user_id  
LEFT JOIN sales_time_entries ste ON u.id = ste.user_id
WHERE u.is_deleted = FALSE
GROUP BY u.id, u.first_name, u.last_name, u.is_legal, o.abbreviation, be.legal_entity_name;
```

## Important Table Relationships

### Document Inheritance Pattern
The `documents` table uses a discriminator pattern:
```sql
-- Documents are categorized by discriminator field:
-- 'MatterDocument' = Matter-related documents
-- 'ProjectDocument' = Project-related documents  
-- 'ContactDocument' = Contact-related documents
-- 'OrganisationDocument' = Organisation documents
-- 'ClientDocument' = Client documents
-- 'OfferingDocument' = Offering documents
-- 'ResourceDocument' = Resource documents
-- 'NotesDocument' = Note attachments
-- 'ContractDocument' = Contract documents
```

### Dynamic Parameters System
```sql
-- Custom fields for any entity
SELECT 
    e.entity_name,
    dp.name as parameter_name,
    dp.data_type,
    dpv.value as parameter_value
FROM (
    SELECT 'Contact' as entity_name, id as entity_id FROM contacts
    UNION ALL
    SELECT 'Matter' as entity_name, id as entity_id FROM matters
    UNION ALL  
    SELECT 'Project' as entity_name, id as entity_id FROM projects
) e
JOIN contact_dynamic_parameter_values cdpv ON e.entity_id = cdpv.contact_id AND e.entity_name = 'Contact'
JOIN dynamic_parameters dp ON cdpv.dynamic_parameter_id = dp.id;
```

## Performance Considerations

### 1. Important Indexes
```sql
-- Key indexes for analytics queries:
-- contacts: email (unique), name
-- matters: client_id, reviewer_id, coordinator_id, status  
-- invoices: matter_id, status, invoice_date
-- time_entries: user_id, matter_component_id, invoice_id, billable_type
-- trust_transactions: matter_id, transaction_type, transaction_date
-- documents: discriminator, extracted_text_search_vector (GIN)
```

### 2. Soft Deletes
All entities use soft deletes - always include `is_deleted = FALSE` in WHERE clauses:
```sql
WHERE entity.is_deleted = FALSE
```

### 3. Audit Fields
All entities include audit fields for tracking:
- `inserted_at` - Creation timestamp
- `updated_at` - Last modification timestamp  
- `inserted_by_id` - Creator user ID
- `last_updated_by_id` - Last modifier user ID

## Common Analytics Queries

### 1. Matter Pipeline Analysis
```sql
-- Matter status distribution and progression
SELECT 
    CASE status 
        WHEN 1 THEN 'To Be Quoted'
        WHEN 2 THEN 'Quoted Awaiting Acceptance'
        WHEN 3 THEN 'Lost'
        WHEN 4 THEN 'Open'
        WHEN 5 THEN 'Closed'
        WHEN 6 THEN 'Finalised'
        WHEN 7 THEN 'Deleted'
    END as matter_status,
    COUNT(*) as matter_count,
    SUM(estimated_budget) as total_estimated_budget,
    AVG(estimated_budget) as avg_estimated_budget
FROM matters 
WHERE is_deleted = FALSE
GROUP BY status
ORDER BY status;
```

### 2. Revenue Analysis
```sql
-- Monthly revenue breakdown
SELECT 
    DATE_TRUNC('month', i.invoice_date) as month,
    COUNT(*) as invoice_count,
    SUM(i.total_invoice_amount_incl_gst) as total_invoiced,
    SUM(i.received_payments) as total_received,
    SUM(i.outstanding_amount) as total_outstanding,
    SUM(i.received_payments) / SUM(i.total_invoice_amount_incl_gst) * 100 as collection_rate
FROM invoices i
WHERE i.is_deleted = FALSE 
  AND i.status = 4 -- Sent
  AND i.invoice_date >= '2023-01-01'
GROUP BY DATE_TRUNC('month', i.invoice_date)
ORDER BY month;
```

### 3. Client Profitability
```sql
-- Top clients by revenue
SELECT 
    c.id as client_id,
    CASE 
        WHEN sc.id IS NOT NULL AND o.id IS NOT NULL THEN 
            o.name || ' - ' || pc.first_name || ' ' || pc.last_name || ' and ' || sc.first_name || ' ' || sc.last_name
        WHEN sc.id IS NOT NULL THEN 
            pc.first_name || ' ' || pc.last_name || ' and ' || sc.first_name || ' ' || sc.last_name
        WHEN o.id IS NOT NULL THEN 
            o.name || ' - ' || pc.first_name || ' ' || pc.last_name
        ELSE 
            pc.first_name || ' ' || pc.last_name
    END as client_name,
    COUNT(DISTINCT m.id) as matter_count,
    COUNT(DISTINCT i.id) as invoice_count,
    SUM(i.total_invoice_amount_incl_gst) as total_invoiced,
    SUM(i.received_payments) as total_received,
    SUM(i.outstanding_amount) as total_outstanding
FROM clients c
JOIN contacts pc ON c.primary_contact_id = pc.id
LEFT JOIN contacts sc ON c.secondary_contact_id = sc.id
LEFT JOIN organisations o ON c.organisation_id = o.id
JOIN matters m ON c.id = m.client_id
JOIN invoices i ON m.id = i.matter_id
WHERE c.is_deleted = FALSE
  AND m.is_deleted = FALSE  
  AND i.is_deleted = FALSE
  AND i.status = 4 -- Sent
GROUP BY c.id, pc.id, sc.id, o.id
ORDER BY total_invoiced DESC;
```

## Metabase Integration

The system includes built-in Metabase integration with:
- Report groups for organizing dashboards
- Parameter passing (user context, etc.)
- Permission-based access control
- Embedded dashboard URLs with JWT tokens

### Key Metabase Tables:
- `metabase_reports` - Report definitions
- `metabase_report_groups` - Report groupings  
- `metabase_report_parameters` - Dynamic parameters
- `metabase_report_group_users` - Access control (many-to-many)

## Security Considerations

### 1. Row-Level Security
Consider implementing row-level security based on:
- User office associations
- Matter team membership
- Client access restrictions
- Role-based permissions

### 2. Data Privacy
Be mindful of:
- Client confidentiality requirements
- Trust account compliance
- Document access controls
- Personal information protection

## Common Pitfalls to Avoid

1. **Forgetting Soft Deletes**: Always include `is_deleted = FALSE`
2. **Rate Calculations**: Remember rates are stored * 10 (divide by 10.0)
3. **GST Calculations**: Different GST types have different multipliers
4. **Trust Calculations**: Complex transaction type logic
5. **Time Zones**: All timestamps are stored without timezone
6. **Discriminator Patterns**: Documents and other inherited entities use discriminator fields
7. **Many-to-Many Relationships**: Use proper junction tables for complex relationships

## Recommended Analytics Views

Consider creating these views for common analytics:

```sql
-- Client summary view
CREATE VIEW client_summary AS 
SELECT 
    c.id,
    -- Client name logic
    -- Matter counts
    -- Revenue totals
    -- etc.
FROM clients c
-- Full implementation in actual views
```

This reference should be used alongside the database structure SQL file to write comprehensive, accurate analytics queries for the ALP system. 