# Metabase Query Development Process
## Systematic Approach to Business Intelligence for Legal Practice Management

### Overview

This document outlines a structured process for translating business questions into accurate SQL queries for Metabase analytics. The process emphasizes iterative collaboration with users to ensure queries meet actual business needs and account for the complex relationships and business logic in our legal practice management system.

---

## Phase 1: Initial Question Analysis

### 1.1 Question Capture
**Goal**: Understand what the user really wants to know

**Process**:
1. **Record the exact question** as stated by the user
2. **Identify the question type**:
   - Operational metrics (current state)
   - Trend analysis (changes over time)
   - Comparative analysis (comparing groups/periods)
   - Forecast/projection (future planning)
   - Drill-down analysis (detailed breakdowns)
   - Performance metrics (KPIs/targets)

3. **Determine the business context**:
   - Who will use this information?
   - What decisions will be made based on this data?
   - How frequently will this be reviewed?
   - What level of detail is needed?

### 1.2 Initial Requirements Gathering

Use the **Business Question Template** (see separate document) to systematically gather:

- **Scope**: Time periods, organizational units, matter types, etc.
- **Metrics**: What exactly needs to be measured
- **Dimensions**: How data should be grouped/filtered
- **Business Rules**: Special calculations or exclusions
- **Output Format**: Dashboard, report, alert, export

---

## Phase 2: Technical Analysis & Query Planning

### 2.1 Data Mapping
**Goal**: Identify required tables, relationships, and calculations

**Process**:
1. **Map business concepts to database entities**:
   - Use the `ALP_Database_Structure.sql` as reference
   - Identify primary tables needed
   - Document required joins and relationships

2. **Identify business logic requirements**:
   - Reference `ALP_Analytics_Reference.md` for calculations
   - Note any special handling (soft deletes, status workflows, etc.)
   - Document required transformations

3. **Plan aggregations and groupings**:
   - Determine appropriate GROUP BY clauses
   - Identify required date/time aggregations
   - Plan any window functions or complex calculations

### 2.2 Query Architecture Planning

**Document the query structure**:
```sql
-- Template structure
WITH base_data AS (
  -- Core data selection with business rules
),
filtered_data AS (
  -- Apply filters and business logic
),
calculated_metrics AS (
  -- Perform calculations and aggregations
)
-- Final selection with proper formatting
```

---

## Phase 3: Iterative Development

### 3.1 Draft Query Development
1. **Start with a minimal viable query**
2. **Focus on core logic first**, add complexity incrementally
3. **Include extensive comments** explaining business logic
4. **Use meaningful aliases** that match business terminology

### 3.2 User Validation Cycle

**For each iteration**:
1. **Present sample results** (5-10 rows)
2. **Explain what the query is doing** in business terms
3. **Ask specific validation questions**:
   - "Does this match your expectations for [specific case]?"
   - "Should we include/exclude [specific scenario]?"
   - "How should we handle [edge case]?"

4. **Gather feedback on**:
   - Data accuracy
   - Missing scenarios
   - Calculation methods
   - Filtering logic
   - Output format

### 3.3 Refinement Process

**Common refinement areas**:
- **Date range handling**: Financial years, matter lifecycles, billing periods
- **Status filtering**: Active vs. archived, different status workflows
- **Financial calculations**: Billable vs. non-billable, GST handling, trust accounting
- **Grouping logic**: Client hierarchies, matter categorization, user roles
- **Performance optimization**: Indexes, query structure, data volumes

---

## Phase 4: Documentation & Deployment

### 4.1 Query Documentation
**Create comprehensive documentation including**:
- Business question and context
- Key assumptions and business rules
- Data sources and join logic
- Calculation explanations
- Known limitations or caveats
- Update frequency and data freshness

### 4.2 Metabase Implementation
1. **Create the query in Metabase** with proper title and description
2. **Set up appropriate visualizations**
3. **Configure filters and parameters**
4. **Test with different user scenarios**
5. **Set up sharing/permissions** as needed

### 4.3 User Training & Handoff
- **Demo the final result** to stakeholders
- **Explain how to interpret** the data
- **Document common use cases** and filter combinations
- **Establish review schedule** for ongoing accuracy

---

## Quality Assurance Checklist

### Data Accuracy
- [ ] Results reconcile with known manual calculations
- [ ] Edge cases are handled appropriately
- [ ] Soft deletes (`is_deleted = FALSE`) are properly filtered
- [ ] Date ranges align with business requirements
- [ ] Status workflows are correctly implemented

### Performance
- [ ] Query executes within acceptable time limits
- [ ] Appropriate indexes are being used
- [ ] Large data sets are handled efficiently
- [ ] Metabase caching is configured appropriately

### Business Logic
- [ ] Financial calculations follow firm standards
- [ ] Trust accounting rules are properly applied
- [ ] Matter status transitions are correctly interpreted
- [ ] Billing logic matches practice requirements
- [ ] User permissions are respected

### Usability
- [ ] Column names are clear and business-friendly
- [ ] Data types are appropriate for visualization
- [ ] Filters work as expected
- [ ] Results can be exported if needed
- [ ] Documentation is complete and accessible

---

## Common Pitfalls & Solutions

### 1. Incomplete Business Logic Understanding
**Problem**: Query produces technically correct but business-incorrect results
**Solution**: Extensive validation with domain experts, use real scenarios for testing

### 2. Performance Issues
**Problem**: Queries timeout or take too long
**Solution**: Incremental complexity, proper indexing, consider materialized views for complex calculations

### 3. Data Freshness Confusion
**Problem**: Users expect real-time data but reports are cached/delayed
**Solution**: Clear documentation of data refresh schedules, set appropriate expectations

### 4. Over-Complexity
**Problem**: Single query tries to answer too many questions
**Solution**: Break complex requirements into multiple focused queries

### 5. Inadequate Error Handling
**Problem**: Queries fail when data doesn't meet assumptions
**Solution**: Include data validation checks, handle null values, document limitations

---

## Success Metrics

### Query Quality
- Accuracy validated by business users
- Performance meets SLA requirements
- Minimal post-deployment revisions needed

### User Adoption
- Regular usage by intended audience
- Positive feedback on utility
- Integration into business processes

### Process Efficiency
- Reduced time from question to answer
- Fewer iterations needed per query
- Increased user confidence in data

---

## Templates & Resources

- **Business Question Template**: `Business_Question_Template.md`
- **Common Query Patterns**: `Common_Legal_Analytics_Patterns.md`
- **Database Reference**: `ALP_Database_Structure.sql`
- **Business Logic Guide**: `ALP_Analytics_Reference.md`
- **Metabase Best Practices**: `Metabase_Implementation_Guide.md`

---

## Continuous Improvement

### Regular Review Process
1. **Monthly query performance review**
2. **Quarterly business logic validation**
3. **Annual process refinement**
4. **User feedback integration**

### Knowledge Management
- Document common patterns and solutions
- Maintain library of proven query templates
- Share insights across team members
- Update process based on lessons learned 