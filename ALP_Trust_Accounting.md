# ALP Trust Accounting System
## Comprehensive Guide to Client Fund Management & Compliance

### Overview & Purpose

The ALP trust accounting system manages client funds with strict regulatory compliance for legal practice requirements. Trust accounts are segregated client money accounts that lawyers hold on behalf of clients, with rigorous reporting, reconciliation, and audit trail requirements mandated by legal practice boards.

**Key Compliance Features:**
- **Segregated Client Funds**: Client money separate from firm operating accounts
- **Transaction Tracking**: Complete audit trail for all fund movements
- **Reconciliation Management**: Regular bank reconciliation with variance tracking
- **Regulatory Reporting**: Automated compliance reports for legal practice boards
- **Matter-Based Allocation**: Client fund tracking by specific legal matters
- **Overdraft Prevention**: System controls to prevent client fund misuse

---

## Database Schema

### 📊 **Core Tables**

```sql
-- Trust account setup and configuration
trust_accounts (
    id, name, account_number, bank_name, bsb,
    opening_balance, current_balance, 
    account_type, is_active,
    office_id, inserted_at, updated_at, is_deleted
)

-- Individual transaction records
trust_transactions (
    id, trust_account_id, matter_id, client_id,
    transaction_type, amount, description, reference,
    transaction_date, processed_date,
    -- Reconciliation tracking
    bank_statement_id, reconciled, reconciliation_date,
    -- Approval workflow
    requires_approval, approved_by_id, approved_at,
    inserted_at, updated_at, inserted_by_id, is_deleted
)

-- Double-entry bookkeeping records
trust_ledger_entries (
    id, trust_transaction_id, account_code, 
    debit_amount, credit_amount, description,
    inserted_at, updated_at, is_deleted
)

-- Bank statement reconciliation
trust_bank_statements (
    id, trust_account_id, statement_date, 
    opening_balance, closing_balance, 
    statement_reference, uploaded_by_id,
    reconciled, reconciliation_date,
    inserted_at, updated_at, is_deleted
)

-- Trust reconciliation tracking
trust_reconciliations (
    id, trust_account_id, reconciliation_date,
    book_balance, bank_balance, variance_amount,
    reconciled_by_id, notes,
    inserted_at, updated_at, is_deleted
)
```

### 🔗 **Key Relationships**

```sql
-- Matter and client relationships
trust_transactions.matter_id → matters.id
trust_transactions.client_id → clients.id

-- Account relationships
trust_transactions.trust_account_id → trust_accounts.id
trust_ledger_entries.trust_transaction_id → trust_transactions.id

-- User relationships (approval and processing)
trust_transactions.approved_by_id → users.id
trust_transactions.inserted_by_id → users.id
```

---

## Transaction Types & Business Logic

### 📊 **Transaction Type Enum Mapping**

```sql
CASE 
  WHEN tt.transaction_type = 1 THEN 'Deposit'
  WHEN tt.transaction_type = 2 THEN 'Withdrawal'
  WHEN tt.transaction_type = 3 THEN 'TransferOut'
  WHEN tt.transaction_type = 4 THEN 'TransferIn'
END as transaction_type_description
```

### 💰 **Transaction Types Explained**

#### **1. Deposit (Type 1)**
- **Purpose**: Client funds received into trust account
- **Examples**: Settlement funds, retainer payments, client deposits
- **Effect**: Increases trust account balance
- **Compliance**: Must be client money only, not firm funds

#### **2. Withdrawal (Type 2)**
- **Purpose**: Client funds disbursed from trust account
- **Examples**: Settlement payments, expense reimbursements, client refunds
- **Effect**: Decreases trust account balance
- **Compliance**: Requires client authorization and matter justification

#### **3. TransferOut (Type 3)**
- **Purpose**: Funds moved from this trust account to another account
- **Examples**: Inter-office transfers, bank account changes
- **Effect**: Decreases source trust account balance
- **Compliance**: Detailed documentation required for audit trail

#### **4. TransferIn (Type 4)**
- **Purpose**: Funds received from another trust account
- **Examples**: Office transfers, account consolidations
- **Effect**: Increases destination trust account balance
- **Compliance**: Must match corresponding TransferOut transaction

---

## Compliance & Regulatory Requirements

### 📋 **Audit Trail Requirements**

Every trust transaction must maintain complete audit trail:

```sql
-- Comprehensive trust transaction audit
SELECT 
  tt.id as transaction_id,
  tt.transaction_date,
  ta.name as trust_account_name,
  ta.account_number,
  CASE 
    WHEN tt.transaction_type = 1 THEN 'Deposit'
    WHEN tt.transaction_type = 2 THEN 'Withdrawal'
    WHEN tt.transaction_type = 3 THEN 'TransferOut'
    WHEN tt.transaction_type = 4 THEN 'TransferIn'
  END as transaction_type,
  tt.amount,
  tt.description,
  tt.reference,
  m.name as matter_name,
  c.name as client_name,
  creator.first_name || ' ' || creator.last_name as created_by,
  CASE WHEN tt.approved_by_id IS NOT NULL THEN
    approver.first_name || ' ' || approver.last_name
  ELSE 'Pending Approval'
  END as approved_by,
  tt.reconciled,
  tt.reconciliation_date
FROM trust_transactions tt
JOIN trust_accounts ta ON tt.trust_account_id = ta.id
LEFT JOIN matters m ON tt.matter_id = m.id
LEFT JOIN clients c ON tt.client_id = c.id
LEFT JOIN users creator ON tt.inserted_by_id = creator.id
LEFT JOIN users approver ON tt.approved_by_id = approver.id
WHERE tt.is_deleted = false
  AND ta.is_deleted = false
ORDER BY tt.transaction_date DESC, tt.id DESC;
```

### 🔍 **Balance Reconciliation**

```sql
-- Trust account balance verification
WITH account_balances AS (
  SELECT 
    ta.id as account_id,
    ta.name as account_name,
    ta.account_number,
    ta.opening_balance,
    -- Calculate current balance from transactions
    ta.opening_balance + 
    COALESCE(SUM(
      CASE 
        WHEN tt.transaction_type IN (1,4) THEN tt.amount  -- Deposits and TransferIn
        WHEN tt.transaction_type IN (2,3) THEN -tt.amount -- Withdrawals and TransferOut
        ELSE 0
      END
    ), 0) as calculated_balance,
    ta.current_balance as stored_balance,
    COUNT(tt.id) as transaction_count,
    MAX(tt.transaction_date) as last_transaction_date
  FROM trust_accounts ta
  LEFT JOIN trust_transactions tt ON ta.id = tt.trust_account_id 
    AND tt.is_deleted = false
    AND tt.reconciled = true  -- Only include reconciled transactions
  WHERE ta.is_deleted = false
    AND ta.is_active = true
  GROUP BY ta.id, ta.name, ta.account_number, ta.opening_balance, ta.current_balance
)
SELECT 
  account_name,
  account_number,
  calculated_balance,
  stored_balance,
  calculated_balance - stored_balance as variance,
  transaction_count,
  last_transaction_date,
  CASE 
    WHEN ABS(calculated_balance - stored_balance) < 0.01 THEN 'Balanced'
    ELSE 'VARIANCE DETECTED'
  END as balance_status
FROM account_balances
ORDER BY ABS(calculated_balance - stored_balance) DESC;
```

### 📊 **Client Fund Tracking**

```sql
-- Client-specific fund balances by matter
WITH client_fund_positions AS (
  SELECT 
    c.id as client_id,
    c.name as client_name,
    m.id as matter_id,
    m.name as matter_name,
    ta.name as trust_account_name,
    SUM(
      CASE 
        WHEN tt.transaction_type IN (1,4) THEN tt.amount  -- Funds in
        WHEN tt.transaction_type IN (2,3) THEN -tt.amount -- Funds out
        ELSE 0
      END
    ) as client_balance,
    COUNT(tt.id) as transaction_count,
    MIN(tt.transaction_date) as first_transaction,
    MAX(tt.transaction_date) as last_transaction,
    -- Identify potential issues
    CASE 
      WHEN SUM(
        CASE 
          WHEN tt.transaction_type IN (1,4) THEN tt.amount
          WHEN tt.transaction_type IN (2,3) THEN -tt.amount
          ELSE 0
        END
      ) < 0 THEN 'NEGATIVE BALANCE'
      WHEN SUM(
        CASE 
          WHEN tt.transaction_type IN (1,4) THEN tt.amount
          WHEN tt.transaction_type IN (2,3) THEN -tt.amount
          ELSE 0
        END
      ) = 0 THEN 'Zero Balance'
      ELSE 'Positive Balance'
    END as balance_status
  FROM clients c
  JOIN matters m ON c.id = m.client_id
  JOIN trust_transactions tt ON m.id = tt.matter_id
  JOIN trust_accounts ta ON tt.trust_account_id = ta.id
  WHERE c.is_deleted = false
    AND m.is_deleted = false
    AND tt.is_deleted = false
    AND ta.is_deleted = false
  GROUP BY c.id, c.name, m.id, m.name, ta.name
)
SELECT 
  client_name,
  matter_name,
  trust_account_name,
  client_balance,
  transaction_count,
  first_transaction,
  last_transaction,
  balance_status,
  EXTRACT(EPOCH FROM (CURRENT_DATE - last_transaction))/86400 as days_since_activity
FROM client_fund_positions
WHERE client_balance != 0  -- Only show non-zero balances
ORDER BY 
  CASE balance_status 
    WHEN 'NEGATIVE BALANCE' THEN 1
    WHEN 'Positive Balance' THEN 2
    WHEN 'Zero Balance' THEN 3
  END,
  ABS(client_balance) DESC;
```

---

## Analytics Patterns

### 📈 **Trust Account Activity Analysis**

```sql
-- Monthly trust account activity summary
SELECT 
  DATE_TRUNC('month', tt.transaction_date) as month,
  ta.name as trust_account_name,
  CASE 
    WHEN tt.transaction_type = 1 THEN 'Deposit'
    WHEN tt.transaction_type = 2 THEN 'Withdrawal'
    WHEN tt.transaction_type = 3 THEN 'TransferOut'
    WHEN tt.transaction_type = 4 THEN 'TransferIn'
  END as transaction_type,
  COUNT(*) as transaction_count,
  SUM(tt.amount) as total_amount,
  AVG(tt.amount) as avg_transaction_amount,
  MIN(tt.amount) as min_amount,
  MAX(tt.amount) as max_amount
FROM trust_transactions tt
JOIN trust_accounts ta ON tt.trust_account_id = ta.id
WHERE tt.is_deleted = false
  AND ta.is_deleted = false
  AND tt.transaction_date >= DATE_TRUNC('year', CURRENT_DATE)
GROUP BY 
  DATE_TRUNC('month', tt.transaction_date),
  ta.name,
  tt.transaction_type
ORDER BY month DESC, trust_account_name, transaction_type;
```

### 🔍 **Reconciliation Status Monitoring**

```sql
-- Unreconciled transaction monitoring
SELECT 
  ta.name as trust_account_name,
  COUNT(tt.id) as unreconciled_transactions,
  SUM(tt.amount) as unreconciled_amount,
  MIN(tt.transaction_date) as oldest_unreconciled,
  MAX(tt.transaction_date) as newest_unreconciled,
  AVG(EXTRACT(EPOCH FROM (CURRENT_DATE - tt.transaction_date))/86400) as avg_age_days,
  -- Age buckets
  COUNT(CASE WHEN EXTRACT(EPOCH FROM (CURRENT_DATE - tt.transaction_date))/86400 <= 7 THEN 1 END) as within_7_days,
  COUNT(CASE WHEN EXTRACT(EPOCH FROM (CURRENT_DATE - tt.transaction_date))/86400 BETWEEN 8 AND 30 THEN 1 END) as within_30_days,
  COUNT(CASE WHEN EXTRACT(EPOCH FROM (CURRENT_DATE - tt.transaction_date))/86400 > 30 THEN 1 END) as over_30_days
FROM trust_accounts ta
LEFT JOIN trust_transactions tt ON ta.id = tt.trust_account_id
  AND tt.reconciled = false
  AND tt.is_deleted = false
WHERE ta.is_deleted = false
  AND ta.is_active = true
GROUP BY ta.id, ta.name
ORDER BY unreconciled_amount DESC;
```

### 💼 **Matter Fund Utilization**

```sql
-- Trust fund usage by matter status
WITH matter_trust_summary AS (
  SELECT 
    m.id as matter_id,
    m.name as matter_name,
    m.status as matter_status,
    CASE 
      WHEN m.status = 1 THEN 'ToBeQuoted'
      WHEN m.status = 2 THEN 'QuotedAwaitingAcceptance'
      WHEN m.status = 3 THEN 'Lost'
      WHEN m.status = 4 THEN 'Open'
      WHEN m.status = 5 THEN 'Closed'
      WHEN m.status = 6 THEN 'Finalised'
    END as status_description,
    c.name as client_name,
    SUM(CASE WHEN tt.transaction_type IN (1,4) THEN tt.amount ELSE 0 END) as total_deposits,
    SUM(CASE WHEN tt.transaction_type IN (2,3) THEN tt.amount ELSE 0 END) as total_withdrawals,
    SUM(
      CASE 
        WHEN tt.transaction_type IN (1,4) THEN tt.amount
        WHEN tt.transaction_type IN (2,3) THEN -tt.amount
        ELSE 0
      END
    ) as current_balance,
    COUNT(tt.id) as transaction_count,
    MIN(tt.transaction_date) as first_trust_activity,
    MAX(tt.transaction_date) as last_trust_activity
  FROM matters m
  JOIN clients c ON m.client_id = c.id
  LEFT JOIN trust_transactions tt ON m.id = tt.matter_id AND tt.is_deleted = false
  WHERE m.is_deleted = false
    AND c.is_deleted = false
  GROUP BY m.id, m.name, m.status, c.name
  HAVING COUNT(tt.id) > 0  -- Only matters with trust activity
)
SELECT 
  status_description,
  COUNT(*) as matter_count,
  SUM(total_deposits) as total_deposits,
  SUM(total_withdrawals) as total_withdrawals,
  SUM(current_balance) as total_current_balance,
  AVG(current_balance) as avg_matter_balance,
  SUM(transaction_count) as total_transactions
FROM matter_trust_summary
GROUP BY status_description, matter_status
ORDER BY matter_status;
```

---

## Compliance Reporting

### 📋 **Regulatory Trust Report**

```sql
-- Standard regulatory trust account report
WITH trust_summary AS (
  SELECT 
    ta.name as account_name,
    ta.account_number,
    ta.bank_name,
    ta.opening_balance,
    -- Current month activity
    SUM(CASE 
      WHEN tt.transaction_type IN (1,4) 
        AND tt.transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
      THEN tt.amount ELSE 0 
    END) as month_deposits,
    SUM(CASE 
      WHEN tt.transaction_type IN (2,3) 
        AND tt.transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
      THEN tt.amount ELSE 0 
    END) as month_withdrawals,
    -- Year to date activity
    SUM(CASE 
      WHEN tt.transaction_type IN (1,4) 
        AND tt.transaction_date >= DATE_TRUNC('year', CURRENT_DATE)
      THEN tt.amount ELSE 0 
    END) as ytd_deposits,
    SUM(CASE 
      WHEN tt.transaction_type IN (2,3) 
        AND tt.transaction_date >= DATE_TRUNC('year', CURRENT_DATE)
      THEN tt.amount ELSE 0 
    END) as ytd_withdrawals,
    -- Current balance calculation
    ta.opening_balance + SUM(
      CASE 
        WHEN tt.transaction_type IN (1,4) THEN tt.amount
        WHEN tt.transaction_type IN (2,3) THEN -tt.amount
        ELSE 0
      END
    ) as calculated_balance,
    ta.current_balance as recorded_balance
  FROM trust_accounts ta
  LEFT JOIN trust_transactions tt ON ta.id = tt.trust_account_id 
    AND tt.is_deleted = false
    AND tt.reconciled = true
  WHERE ta.is_deleted = false
    AND ta.is_active = true
  GROUP BY ta.id, ta.name, ta.account_number, ta.bank_name, 
           ta.opening_balance, ta.current_balance
)
SELECT 
  account_name,
  account_number,
  bank_name,
  opening_balance,
  month_deposits,
  month_withdrawals,
  month_deposits - month_withdrawals as month_net_movement,
  ytd_deposits,
  ytd_withdrawals,
  ytd_deposits - ytd_withdrawals as ytd_net_movement,
  calculated_balance,
  recorded_balance,
  calculated_balance - recorded_balance as balance_variance,
  CASE 
    WHEN ABS(calculated_balance - recorded_balance) < 0.01 THEN 'Reconciled'
    ELSE 'VARIANCE - REQUIRES INVESTIGATION'
  END as reconciliation_status
FROM trust_summary
ORDER BY ABS(calculated_balance - recorded_balance) DESC;
```

### 🔍 **Client Fund Liability Report**

```sql
-- Client fund liability summary for regulatory reporting
SELECT 
  c.name as client_name,
  c.id as client_id,
  COUNT(DISTINCT m.id) as matter_count,
  SUM(
    CASE 
      WHEN tt.transaction_type IN (1,4) THEN tt.amount
      WHEN tt.transaction_type IN (2,3) THEN -tt.amount
      ELSE 0
    END
  ) as total_client_balance,
  STRING_AGG(DISTINCT ta.name, ', ') as trust_accounts,
  MIN(tt.transaction_date) as first_trust_activity,
  MAX(tt.transaction_date) as last_trust_activity,
  COUNT(tt.id) as total_transactions
FROM clients c
JOIN matters m ON c.id = m.client_id
JOIN trust_transactions tt ON m.id = tt.matter_id
JOIN trust_accounts ta ON tt.trust_account_id = ta.id
WHERE c.is_deleted = false
  AND m.is_deleted = false
  AND tt.is_deleted = false
  AND ta.is_deleted = false
GROUP BY c.id, c.name
HAVING SUM(
  CASE 
    WHEN tt.transaction_type IN (1,4) THEN tt.amount
    WHEN tt.transaction_type IN (2,3) THEN -tt.amount
    ELSE 0
  END
) != 0  -- Only clients with non-zero balances
ORDER BY total_client_balance DESC;
```

---

## Integration Points with Other Modules

### 🔗 **Matter Management Integration**
- **File**: [ALP_Matter_Management.md](./ALP_Matter_Management.md)
- **Relationship**: Trust transactions linked to specific matters
- **Key Logic**: Matter closure requires trust balance reconciliation

### 🔗 **Invoicing Integration**
- **File**: [ALP_Invoicing_Business_Logic.md](./ALP_Invoicing_Business_Logic.md)
- **Relationship**: Trust funds may be used for invoice payments
- **Key Logic**: Client payment processing via trust accounts

### 🔗 **Client Management Integration**
- **File**: [ALP_Client_Management.md](./ALP_Client_Management.md)
- **Relationship**: Client fund tracking and liability management
- **Key Logic**: Client status affects trust account access

---

## Critical Enum Mappings

```sql
-- Transaction Types
CASE 
  WHEN tt.transaction_type = 1 THEN 'Deposit'
  WHEN tt.transaction_type = 2 THEN 'Withdrawal'
  WHEN tt.transaction_type = 3 THEN 'TransferOut'
  WHEN tt.transaction_type = 4 THEN 'TransferIn'
END

-- Account Status
CASE 
  WHEN ta.is_active = true THEN 'Active'
  WHEN ta.is_active = false THEN 'Inactive'
END

-- Reconciliation Status
CASE 
  WHEN tt.reconciled = true THEN 'Reconciled'
  WHEN tt.reconciled = false THEN 'Unreconciled'
END

-- Approval Status
CASE 
  WHEN tt.requires_approval = false THEN 'No Approval Required'
  WHEN tt.requires_approval = true AND tt.approved_by_id IS NULL THEN 'Pending Approval'
  WHEN tt.requires_approval = true AND tt.approved_by_id IS NOT NULL THEN 'Approved'
END
```

---

## Gotchas & Special Considerations

### ⚠️ **Regulatory Compliance**

1. **Segregation Requirement**: Trust funds must never be mixed with firm operating funds
2. **Overdraft Prevention**: System must prevent negative client balances
3. **Audit Trail**: Complete transaction history required for compliance
4. **Approval Workflows**: Large transactions may require partner approval

### ⚠️ **Data Integrity**

1. **Double Entry**: All transactions should create corresponding ledger entries
2. **Reconciliation Timing**: Regular reconciliation required (monthly minimum)
3. **Balance Calculations**: Always verify calculated vs stored balances
4. **Transaction Reversal**: Corrections require offsetting transactions, not deletions

### ⚠️ **Analytics Considerations**

1. **Reconciled vs Unreconciled**: Only include reconciled transactions in balance calculations
2. **Date Sensitivity**: Transaction date vs processed date may differ
3. **Client Privacy**: Trust reports may require client confidentiality protections
4. **Regulatory Changes**: Compliance requirements may change by jurisdiction

---

## Example Metabase Queries

### Trust Account Dashboard
```sql
-- Executive trust account summary
SELECT 
  ta.name as account_name,
  ta.current_balance,
  COUNT(CASE WHEN tt.reconciled = false THEN 1 END) as unreconciled_count,
  SUM(CASE WHEN tt.reconciled = false THEN tt.amount ELSE 0 END) as unreconciled_amount,
  COUNT(CASE WHEN tt.transaction_date >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) as recent_transactions,
  SUM(CASE WHEN tt.transaction_date >= CURRENT_DATE - INTERVAL '30 days' 
           AND tt.transaction_type IN (1,4) THEN tt.amount ELSE 0 END) as recent_deposits,
  SUM(CASE WHEN tt.transaction_date >= CURRENT_DATE - INTERVAL '30 days' 
           AND tt.transaction_type IN (2,3) THEN tt.amount ELSE 0 END) as recent_withdrawals
FROM trust_accounts ta
LEFT JOIN trust_transactions tt ON ta.id = tt.trust_account_id 
  AND tt.is_deleted = false
WHERE ta.is_deleted = false
  AND ta.is_active = true
GROUP BY ta.id, ta.name, ta.current_balance
ORDER BY ta.current_balance DESC;
```

### Client Fund Summary
```sql
-- Client fund balances requiring attention
SELECT 
  c.name as client_name,
  COUNT(DISTINCT m.id) as active_matters,
  SUM(
    CASE 
      WHEN tt.transaction_type IN (1,4) THEN tt.amount
      WHEN tt.transaction_type IN (2,3) THEN -tt.amount
      ELSE 0
    END
  ) as current_balance,
  MAX(tt.transaction_date) as last_activity,
  EXTRACT(EPOCH FROM (CURRENT_DATE - MAX(tt.transaction_date)))/86400 as days_since_activity
FROM clients c
JOIN matters m ON c.id = m.client_id
JOIN trust_transactions tt ON m.id = tt.matter_id
WHERE c.is_deleted = false
  AND m.is_deleted = false
  AND tt.is_deleted = false
  AND m.status IN (4, 5)  -- Open or Closed matters only
GROUP BY c.id, c.name
HAVING SUM(
  CASE 
    WHEN tt.transaction_type IN (1,4) THEN tt.amount
    WHEN tt.transaction_type IN (2,3) THEN -tt.amount
    ELSE 0
  END
) > 0
ORDER BY current_balance DESC;
```

---

## Links to Related Modules

- **[Matter Management](./ALP_Matter_Management.md)** - Matter-specific fund tracking
- **[Invoicing](./ALP_Invoicing_Business_Logic.md)** - Payment processing integration
- **[Client Management](./ALP_Client_Management.md)** - Client fund liability management
- **[Financial Management](./ALP_Financial_Management.md)** - Overall financial reporting
- **[User Management](./ALP_User_Management.md)** - Trust account access permissions

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Related Framework**: [Query Development Framework Summary](./Query_Development_Framework_Summary.md) 