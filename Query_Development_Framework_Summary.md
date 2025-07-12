# Query Development Framework Summary
## Complete System for Legal Practice Analytics

### Framework Overview

This document summarizes the complete framework for developing SQL queries for Metabase analytics in our legal practice management system. The framework consists of structured processes, templates, and best practices designed to efficiently translate business questions into accurate, performant analytics.

---

## Framework Components

### 📋 Process Documents
1. **[Metabase_Query_Development_Process.md](./Metabase_Query_Development_Process.md)**
   - Core methodology for query development
   - 4-phase iterative process
   - Quality assurance checklist
   - Common pitfalls and solutions

2. **[Business_Question_Template.md](./Business_Question_Template.md)**
   - Structured requirements gathering
   - 9-section comprehensive template
   - Ensures all aspects are considered
   - Reduces back-and-forth iterations

### 🔧 Technical Resources
3. **[Common_Legal_Analytics_Patterns.md](./Common_Legal_Analytics_Patterns.md)**
   - 6 proven SQL query patterns
   - Legal practice-specific business logic
   - Performance optimization guidelines
   - Anti-patterns to avoid

4. **[Metabase_Implementation_Guide.md](./Metabase_Implementation_Guide.md)**
   - Metabase-specific best practices
   - Visualization selection guidelines
   - Dashboard design patterns
   - Security and maintenance procedures

### 📊 Database References
5. **[ALP_Database_Structure.sql](./ALP_Database_Structure.sql)** *(Already created)*
   - Complete schema documentation
   - 100+ tables with relationships
   - Critical for data mapping

6. **[ALP_Business_Application_Overview.md](./ALP_Business_Application_Overview.md)** - Master navigation hub
   - System architecture summary
   - Cross-module integration map
   - Navigation by business use case

### 🎯 Business Module Deep Dives
7. **[ALP_Invoicing_Business_Logic.md](./ALP_Invoicing_Business_Logic.md)** - Revenue & billing complexity
8. **[ALP_Offerings_Service_Delivery.md](./ALP_Offerings_Service_Delivery.md)** - Service templates & delivery
9. **[ALP_Matter_Management.md](./ALP_Matter_Management.md)** - Client work lifecycle
10. **[ALP_Time_Tracking.md](./ALP_Time_Tracking.md)** - Multi-type time recording
11. **[ALP_Trust_Accounting.md](./ALP_Trust_Accounting.md)** - Client fund management
12. **[ALP_Project_Management.md](./ALP_Project_Management.md)** - Internal project coordination

---

## How to Use the Framework

### Phase 1: Requirements Gathering (Use Business_Question_Template.md)

**When someone requests analytics:**
1. **Start with the template** - Don't skip this step, even for "simple" requests
2. **Fill out all 9 sections** - Each section uncovers important requirements
3. **Focus on business context** - Understanding the "why" is crucial
4. **Document assumptions** - Make implicit knowledge explicit

**Example workflow:**
```
User Request: "I want to see our revenue by practice area"

Template Application:
✅ Section 1: Primary question and classification
✅ Section 2: Time scope (current FY? historical?)  
✅ Section 3: Revenue calculation method (billable time? invoiced? including GST?)
✅ Section 4: Filtering needs (by user? matter status?)
✅ Section 5: Output format (dashboard? export?)
✅ Section 6: Business rules (how handle multi-practice matters?)
✅ Section 7: Success criteria (what constitutes "correct"?)
✅ Section 8: Example scenarios for testing
✅ Section 9: Follow-up questions identified
```

### Phase 2: Technical Planning (Use Common_Legal_Analytics_Patterns.md)

**Map business requirements to technical implementation:**
1. **Review existing patterns** - Does this fit Pattern 1-6?
2. **Identify relevant modules** - Use [Business Application Overview](./ALP_Business_Application_Overview.md)
3. **Study module documentation** - Deep dive into specific business logic
4. **Plan query architecture** - Use CTE structure from patterns

**Pattern Selection Guide:**
- **Revenue questions** → Pattern 2 (Revenue Analysis)
- **Client performance** → Pattern 3 (Client Profitability)
- **Matter status** → Pattern 1 (Matter Pipeline)
- **Trust accounting** → Pattern 4 (Trust Account Reconciliation)
- **Individual performance** → Pattern 6 (User Productivity)
- **Multiple metrics** → Pattern 5 (Matter Performance Dashboard)

### Phase 3: Iterative Development (Use Metabase_Query_Development_Process.md)

**Follow the 4-phase process:**
1. **Initial Question Analysis** - Understand what's really needed
2. **Technical Analysis** - Map to database and plan query
3. **Iterative Development** - Build incrementally with user validation
4. **Documentation & Deployment** - Proper handoff and maintenance

**Key iteration points:**
- Start with minimal viable query
- Test with sample data first
- Validate business logic with domain experts
- Refine based on edge cases
- Optimize for performance

### Phase 4: Metabase Implementation (Use Metabase_Implementation_Guide.md)

**Deploy following best practices:**
1. **Query optimization** - Human-readable column names, proper data types
2. **Visualization selection** - Use the decision matrix
3. **Dashboard design** - Follow layout principles
4. **Performance tuning** - Apply caching strategy
5. **User experience** - Progressive disclosure, mobile considerations

---

## ⚠️ Critical Business Logic Insights

### Database Architecture
- **Multi-tenant**: All tables include tenant-based data separation
- **Soft Deletes**: Use `WHERE is_deleted = false` in all queries
- **Inheritance Pattern**: Time entries use table-per-hierarchy with `discriminator` field
- **Naming Convention**: snake_case throughout (e.g., `client_id`, `updated_at`)

### Data Storage Patterns
- **Enum Storage**: All enums stored as integers, require CASE statements for display
- **Rate Precision**: Stored ×10 (450 = $45.00/hour) - always divide by 10
- **Time Tracking**: Uses `units` field (6-minute increments) - divide by 10 for hours
- **Amount Calculations**: Invoice totals often stored as 0/null - calculate from line items

### Invoice Allocation Logic
- **Fixed-Price Complexity**: Time entries on fixed-price invoices receive proportional shares of total invoice value
- **Allocation Formula**: Each time entry's billed amount = (time entry contribution ÷ total work) × total invoice value
- **Revenue Analysis Impact**: Always distinguish between:
  - **Time-based invoices**: Revenue = time × rate
  - **Fixed-price invoices**: Revenue = allocated portion of invoice total
- **Profitability Calculations**: Use allocated amounts, not time entry rates, for fixed-price matters

### Critical Enum Mappings
- **Matter Status**: 1=ToBeQuoted, 2=QuotedAwaitingAcceptance, 3=Lost, 4=Open, 5=Closed, 6=Finalised, 7=Deleted
- **Billable Types**: 1=Billable, 2=NonBillable, 3=NonChargeable, 4=ProBono
- **Invoice Status**: 1=Draft, 2=AwaitingApproval, 3=Approved, 4=Sent, 5=All
- **Trust Transaction Types**: 1=Deposit, 2=Withdrawal, 3=TransferOut, 4=TransferIn

---

## Framework Benefits

### 🎯 For Analysts
- **Reduced rework** - Comprehensive requirements gathering upfront
- **Faster development** - Proven patterns and templates
- **Better quality** - Built-in quality assurance processes
- **Knowledge sharing** - Documented patterns for team use

### 👥 For Users
- **Better outcomes** - Structured process ensures needs are met
- **Faster delivery** - Less back-and-forth iteration
- **Self-service** - Clear documentation enables independence
- **Consistent experience** - Standardized dashboard patterns

### 🏢 For Organization
- **Scalable analytics** - Repeatable processes for growing needs
- **Knowledge preservation** - Documented institutional knowledge
- **Quality control** - Consistent standards across all analytics
- **ROI optimization** - Focus on high-value analytics patterns

---

## Quick Reference Guide

### 🚀 Starting a New Analytics Request

1. **Copy** `Business_Question_Template.md` → `New_Request_[Date].md`
2. **Fill out** all sections with the requestor
3. **Review** `Common_Legal_Analytics_Patterns.md` for similar patterns
4. **Reference** database structure and business logic documents
5. **Follow** the iterative development process
6. **Implement** using Metabase best practices
7. **Document** the final solution for future reference

### 🔍 Troubleshooting Common Issues

| Issue | Check | Solution |
|-------|-------|----------|
| **Wrong results** | Business logic reference | Verify calculations, status meanings, soft deletes |
| **Slow performance** | Query patterns guide | Add indexes, limit date ranges, optimize JOINs |
| **User confusion** | Metabase implementation guide | Better column names, visualization choice, documentation |
| **Missing requirements** | Business question template | Go back through template sections systematically |

### 📈 Success Metrics

Track these metrics to measure framework effectiveness:
- **Time from request to delivery** (target: 50% reduction)
- **Number of iterations required** (target: ≤3 iterations)
- **User satisfaction scores** (target: >4.5/5)
- **Query performance** (target: <10 seconds)
- **Reuse of patterns** (target: 80% of new queries use existing patterns)

---

## Continuous Improvement

### 📝 Documentation Maintenance

**Monthly:**
- Review new queries for emerging patterns
- Update common patterns with new variations
- Collect user feedback on process effectiveness

**Quarterly:**
- Update business logic reference for any system changes
- Review and refresh query performance optimization
- Validate that database structure documentation is current

**Annually:**
- Complete framework review and updates
- Training refresh for team members
- Process refinement based on lessons learned

### 🔄 Pattern Evolution

**When to create new patterns:**
- Similar business questions asked >3 times
- Complex logic that could be reused
- New business processes or data sources
- Performance optimizations that are broadly applicable

**When to update existing patterns:**
- Business logic changes
- Performance improvements discovered
- User experience enhancements
- New visualization capabilities

---

## Getting Started

### For New Team Members
1. **Read** `Metabase_Query_Development_Process.md` first
2. **Practice** with `Business_Question_Template.md` on a simple request
3. **Study** existing patterns in `Common_Legal_Analytics_Patterns.md`
4. **Shadow** experienced analyst through full process
5. **Start** with simple requests, gradually increase complexity

### For Requestors
1. **Review** `Business_Question_Template.md` before making requests
2. **Prepare** examples and scenarios you want to test
3. **Consider** how the analytics will be used in business processes
4. **Plan** for iteration - requirements often evolve during development

### For Management
1. **Prioritize** requests using business impact and effort matrix
2. **Allocate** time for proper requirements gathering (don't skip it)
3. **Invest** in pattern development for frequently requested analytics
4. **Monitor** success metrics to validate framework effectiveness

---

## Success Stories Template

Document successful implementations to build institutional knowledge:

```markdown
## [Analytics Project Name]

**Business Question**: [Original request]
**Pattern Used**: [Which pattern from the library]
**Development Time**: [Hours/days from start to finish]
**Iterations Required**: [Number of feedback cycles]
**User Feedback**: [Satisfaction score and comments]
**Usage Statistics**: [How often it's accessed]
**Business Impact**: [Decisions made, process improvements, etc.]

### Key Learnings
- [What worked well]
- [What could be improved]
- [New patterns discovered]

### Reusability
- [Which parts can be reused for similar requests]
- [Variations created for other departments]
```

---

**Framework Version**: 1.0  
**Created**: [Date]  
**Next Review**: [Date + 6 months]

---

## Quick Links

### Framework Documents
- [Main Process Guide](./Metabase_Query_Development_Process.md)
- [Requirements Template](./Business_Question_Template.md) 
- [Query Patterns Library](./Common_Legal_Analytics_Patterns.md)
- [Metabase Best Practices](./Metabase_Implementation_Guide.md)

### Business Application
- [Master Overview](./ALP_Business_Application_Overview.md) - Start here for navigation
- [Invoicing](./ALP_Invoicing_Business_Logic.md) - Revenue & billing complexity
- [Matter Management](./ALP_Matter_Management.md) - Client work lifecycle
- [Time Tracking](./ALP_Time_Tracking.md) - Multi-type time recording
- [Trust Accounting](./ALP_Trust_Accounting.md) - Client fund management
- [Service Delivery](./ALP_Offerings_Service_Delivery.md) - Service templates
- [Project Management](./ALP_Project_Management.md) - Internal coordination 