# ALP Business Application Overview
## Master Navigation & System Architecture Summary

### Purpose & Scope

This document serves as the **master navigation hub** for comprehensive ALP business application documentation. The ALP system is a sophisticated legal practice management platform built on .NET Core with Vue.js frontend, PostgreSQL database, and integrated business intelligence via Metabase.

**Documentation Structure**: Each business module has been separated into focused documentation files for detailed analysis and development. This overview provides system-wide context and navigation to specific modules.

---

## 🎯 **System Architecture Summary**

### Technology Stack
- **Backend**: .NET Core 6+ with Entity Framework Core
- **Frontend**: Vue.js 3 with TypeScript
- **Database**: PostgreSQL with extensive stored procedures
- **Cloud Platform**: Microsoft Azure with integrated services
- **Analytics**: Metabase embedded for business intelligence
- **Integration**: Microsoft Graph, SharePoint, Xero, Active Campaign

### Single-Firm Architecture with Multi-Entity Support
- **Single firm application** supporting multiple legal entities and offices
- **Business Entity structure** for different legal entities within the firm (`BusinessEntity` table)
- **Office management** for multiple physical locations (`Office` table linked to `BusinessEntity`)
- **Soft delete pattern** throughout (`is_deleted = false`)
- **Audit trail maintenance** with `inserted_at`, `updated_at` tracking
- **User-based security** with role-based access control

---

## 📋 **Business Module Navigation**

### 🧾 **Core Financial Operations**

#### [Invoicing & Billing System](./ALP_Invoicing_Business_Logic.md)
**Complexity Level**: ⚠️ **CRITICAL - HIGHEST COMPLEXITY**
- **Dual invoice types**: Fixed-price vs time-based billing
- **Dynamic amount calculation** from line items (never use stored totals)
- **Fixed-price allocation logic** for time entry revenue distribution
- **GST handling** and regulatory compliance
- **Multi-stage approval workflows**

#### [Trust Accounting System](./ALP_Trust_Accounting.md)
**Compliance Level**: 🏛️ **REGULATORY CRITICAL**
- **Client fund management** with strict segregation requirements
- **Transaction audit trails** for legal compliance
- **Reconciliation management** with variance tracking
- **Regulatory reporting** for legal practice boards
- **Matter-based fund allocation**

### 📊 **Core Business Operations**

#### [Matter Management](./ALP_Matter_Management.md)
**Business Criticality**: 🎯 **BUSINESS CORE**
- **Matter lifecycle** from quote to finalization
- **Status workflow management** with conversion tracking
- **Team coordination** and workload distribution
- **Financial management** with rate adjustments and budget tracking
- **Client relationship integration**

#### [Service Delivery & Offerings](./ALP_Offerings_Service_Delivery.md)
**Strategic Importance**: 🚀 **SERVICE EXCELLENCE**
- **Service template system** with rich marketing content
- **Offering architecture** from categories to components
- **Copy-on-create pattern** for matter instantiation
- **Service delivery analytics** and template optimization
- **Business framework integration** (Zippy Scooter, Grunt Test, etc.)

#### [Time Tracking System](./ALP_Time_Tracking.md)
**Technical Complexity**: ⚙️ **ARCHITECTURAL SOPHISTICATION**
- **Table-per-hierarchy inheritance** with discriminator pattern
- **Multiple entry types**: Matter, Project, Sales time
- **6-minute increment system** with rate precision
- **Billable type classification** and invoice integration
- **Cross-module time allocation**

#### [Project Management](./ALP_Project_Management.md)
**Operational Scope**: 🔧 **INTERNAL OPERATIONS**
- **Internal vs client work** distinction
- **BAU vs strategic project** classification
- **Template-based project** creation and management
- **Resource allocation** and workload analytics
- **Team coordination** and milestone tracking

---

## 🔗 **Cross-Module Integration Map**

### Primary Data Flow
```
Offerings (Templates)
    ↓ (Copy-on-Create)
Matters (Client Work)
    ↓ (Component Breakdown)
Matter Components
    ↓ (Work Recording)
Time Entries
    ↓ (Billing Process)
Invoices
    ↓ (Payment Processing)
Trust Accounts
```

### Secondary Workflows
```
Projects (Internal) → Project Tasks → Time Entries
Sales Activities → Sales Time Entries
Matter Components → Document Generation
Trust Transactions → Matter Fund Tracking
```

---

## 📊 **Critical Business Logic Insights**

### ⚠️ **Universal Data Patterns**
- **Soft Deletes**: Always filter `WHERE is_deleted = false`
- **Entity/Office Structure**: Single-firm application with multiple business entities and offices
- **Audit Trails**: Complete user and timestamp tracking
- **Enum Storage**: All enums as integers requiring CASE statements

### 💡 **Key Calculation Rules**
- **Time Units**: Divide by 10 for hours (6-minute increments)
- **Rate Precision**: Divide by 10 for dollar amounts (×10 storage)
- **Invoice Amounts**: Calculate from line items, never use stored totals
- **Fixed-Price Allocation**: Use allocated amounts, not rate × time

### 🎯 **Essential Enum Mappings**
```sql
-- Matter Status
1=ToBeQuoted, 2=QuotedAwaitingAcceptance, 3=Lost, 4=Open, 5=Closed, 6=Finalised

-- Billable Types  
1=Billable, 2=NonBillable, 3=NonChargeable, 4=ProBono

-- Invoice Types
1=FixedPrice, 2=TimeEntry

-- Trust Transaction Types
1=Deposit, 2=Withdrawal, 3=TransferOut, 4=TransferIn
```

---

## 🔧 **Analytics Framework Integration**

### Query Development Process
Follow the structured approach documented in:
- **[Query Development Framework Summary](./Query_Development_Framework_Summary.md)** - Master framework overview
- **[Business Question Template](./Business_Question_Template.md)** - Requirements gathering
- **[Common Legal Analytics Patterns](./Common_Legal_Analytics_Patterns.md)** - Proven query patterns

### Module-Specific Analytics
Each module document contains:
- **Database schema details**
- **Business logic explanations** 
- **Common analytics patterns**
- **Example Metabase queries**
- **Performance considerations**
- **Integration points**

---

## 🎯 **Quick Navigation by Use Case**

### **Revenue Analysis** 
→ [Invoicing System](./ALP_Invoicing_Business_Logic.md) + [Time Tracking](./ALP_Time_Tracking.md)

### **Client Profitability**
→ [Matter Management](./ALP_Matter_Management.md) + [Trust Accounting](./ALP_Trust_Accounting.md)

### **Service Delivery Optimization**
→ [Offerings](./ALP_Offerings_Service_Delivery.md) + [Matter Management](./ALP_Matter_Management.md)

### **Resource Utilization**
→ [Time Tracking](./ALP_Time_Tracking.md) + [Project Management](./ALP_Project_Management.md)

### **Financial Compliance**
→ [Trust Accounting](./ALP_Trust_Accounting.md) + [Invoicing](./ALP_Invoicing_Business_Logic.md)

### **Workflow Optimization**
→ [Matter Management](./ALP_Matter_Management.md) + [Project Management](./ALP_Project_Management.md)

---

## 🚨 **Critical Considerations for Analytics**

### ⚠️ **High-Risk Areas**
1. **Invoice Amount Calculations**: Always use line items, never stored totals
2. **Fixed-Price Revenue**: Use allocated amounts, not rate calculations
3. **Time Entry Inheritance**: Filter by correct discriminator values
4. **Trust Account Compliance**: Maintain complete audit trails

### 💡 **Performance Optimization**
1. **Date Range Filtering**: Always include for large datasets
2. **Index Utilization**: Leverage discriminator, status, and date indexes
3. **CTE Structure**: Use for complex multi-step calculations
4. **Soft Delete Filtering**: Essential for data integrity

### 🎯 **Business Value Focus**
1. **Service Profitability**: Template vs actual delivery analysis
2. **Client Value**: Long-term relationship and matter success tracking
3. **Operational Efficiency**: Resource allocation and workflow optimization
4. **Compliance Reporting**: Regulatory and audit requirement satisfaction

---

## 📈 **System Performance Metrics**

### Target Performance Standards
- **Query Response Time**: <2 seconds for standard reports
- **Dashboard Load Time**: <5 seconds for complex dashboards
- **Concurrent Users**: 500+ supported simultaneously
- **Data Accuracy**: 99.9% integrity across all modules
- **Uptime**: 99.9% availability target

### Key Business Metrics
- **Matter Conversion Rate**: Pipeline to active matter progression
- **Service Delivery Success**: Offering outcome completion rates
- **Revenue Recognition**: Billable to invoiced conversion efficiency
- **Client Satisfaction**: Service delivery vs expectation alignment
- **Resource Utilization**: Billable percentage and productivity metrics

---

## 🔄 **Module Interdependencies**

### Core Dependencies
```
Offerings → Matters → Time Entries → Invoices
Projects → Project Tasks → Time Entries
Trust Transactions → Matters → Clients
```

### Analytics Dependencies
```
Revenue Analysis: Invoicing + Time Tracking + Matter Management
Profitability Analysis: All Core Modules + Trust Accounting
Service Optimization: Offerings + Matter Management + Time Tracking
Resource Planning: Time Tracking + Project Management + Matter Management
```

---

## 📚 **Additional Resources**

### Development Framework
- **[Metabase Query Development Process](./Metabase_Query_Development_Process.md)** - Structured development methodology
- **[Metabase Implementation Guide](./Metabase_Implementation_Guide.md)** - Technical implementation best practices
- **[Query Development Framework Summary](./Query_Development_Framework_Summary.md)** - Complete framework overview

### Business Context
- **Database Structure**: Comprehensive schema documentation available in module files
- **Business Logic**: Detailed explanations in each module's business logic sections
- **Analytics Patterns**: Proven query patterns documented per module

---

## 🎯 **Getting Started Guide**

### For Analytics Development
1. **Start with** [Query Development Framework Summary](./Query_Development_Framework_Summary.md)
2. **Identify module** relevant to your business question
3. **Review module documentation** for business logic and patterns
4. **Use** [Business Question Template](./Business_Question_Template.md) for requirements
5. **Reference** proven patterns from module analytics sections

### For System Understanding
1. **Begin with** this overview for system architecture
2. **Deep dive** into relevant module documentation
3. **Study** cross-module integration patterns
4. **Review** critical business logic insights
5. **Practice** with provided example queries

---

**Last Updated**: December 2024  
**Version**: 2.0 - Modular Architecture  
**Documentation Coverage**: Complete system with modular deep-dive references

---

## 🗂️ **Complete Module Library**

| Module | Complexity | File Link | Primary Focus |
|--------|------------|-----------|---------------|
| **Invoicing & Billing** | ⚠️ Critical | [ALP_Invoicing_Business_Logic.md](./ALP_Invoicing_Business_Logic.md) | Revenue & billing complexity |
| **Service Delivery** | 🚀 Strategic | [ALP_Offerings_Service_Delivery.md](./ALP_Offerings_Service_Delivery.md) | Service templates & delivery |
| **Matter Management** | 🎯 Core | [ALP_Matter_Management.md](./ALP_Matter_Management.md) | Client work lifecycle |
| **Time Tracking** | ⚙️ Technical | [ALP_Time_Tracking.md](./ALP_Time_Tracking.md) | Multi-type time recording |
| **Trust Accounting** | 🏛️ Compliance | [ALP_Trust_Accounting.md](./ALP_Trust_Accounting.md) | Client fund management |
| **Project Management** | 🔧 Operational | [ALP_Project_Management.md](./ALP_Project_Management.md) | Internal project coordination | 
