# ALP Analytics Offerings/Matters
## Data Relationships & Metrics for Offerings, Matters, Time & Revenue

### Overview

This framework outlines key metrics and analytics patterns for the ALP system, focusing on the complex relationships between offerings (templates), matters (client work), and time entries (actual execution). Understanding these relationships is crucial for accurate business intelligence and performance measurement.

---

## 🏗️ **Core Data Relationships**

### **Relationship Architecture**
```
OfferingCategory
├── Offerings (Templates)
    ├── OfferingOutcomes
        ├── OfferingOutcomeComponents (Bridge Table)
            └── OfferingComponents
    
    ↓ MANY-TO-MANY RELATIONSHIP ↓
    
    └── Matters (Client Work) 
        ├── MatterOutcomes (Copied from OfferingOutcomes)
            └── MatterComponents (Copied from OfferingOutcomeComponents)
                └── TimeEntries (Actual Work)
```

### **Critical Distinction: Matter Count vs Offering Instance Count**

**Your understanding is absolutely correct:**

#### **"How many matters have offering X?"**
```sql
SELECT COUNT(DISTINCT m.id) as matter_count
FROM matters m
JOIN matter_offerings mo ON m.id = mo.matter_id  -- Many-to-many join table
WHERE mo.offering_id = X;
```
**Result**: Each matter counted once, regardless of how many offerings it has

#### **"How many instances of offering X have we delivered?"**
```sql
SELECT COUNT(*) as offering_instances
FROM matter_offerings mo
WHERE mo.offering_id = X;
```
**Result**: Each matter-offering association counted (could be higher than matter count)

**Why Different**: A single matter might combine multiple offerings (e.g., Property Purchase + Mortgage + Insurance offerings), so the offering instance count includes each association.

---

## 📊 **Analytics Access Patterns**

### **🔽 Top-Down Analysis (Offering Category → Time)**

**Use Cases**: Template performance, service portfolio analysis, capacity planning

#### **Level 1: Offering Category Metrics**
```sql
-- Service portfolio overview
SELECT 
    oc.name as category,
    COUNT(DISTINCT o.id) as total_offerings,
    COUNT(DISTINCT mo.matter_id) as matters_using_category,
    COUNT(mo.matter_id) as total_offering_instances,
    SUM(te.units) as total_time_units
FROM offering_categories oc
LEFT JOIN offerings o ON oc.id = o.category_id
LEFT JOIN matter_offerings mo ON o.id = mo.offering_id
LEFT JOIN matter_outcomes mout ON mo.matter_id = mout.matter_id
LEFT JOIN matter_components mc ON mout.id = mc.matter_outcome_id
LEFT JOIN time_entries te ON mc.id = te.matter_component_id
GROUP BY oc.id, oc.name;
```

#### **Level 2: Individual Offering Metrics**
```sql
-- Specific offering performance
SELECT 
    o.name as offering,
    COUNT(DISTINCT mo.matter_id) as unique_matters,
    COUNT(mo.matter_id) as offering_instances,
    AVG(m.estimated_budget) as avg_matter_budget,
    SUM(te.units) as total_time_units,
    COUNT(DISTINCT mc.id) as components_executed
FROM offerings o
LEFT JOIN matter_offerings mo ON o.id = mo.offering_id
LEFT JOIN matters m ON mo.matter_id = m.id
LEFT JOIN matter_outcomes mout ON m.id = mout.matter_id AND mout.offering_outcome_id IS NOT NULL
LEFT JOIN matter_components mc ON mout.id = mc.matter_outcome_id
LEFT JOIN time_entries te ON mc.id = te.matter_component_id
WHERE o.id = X
GROUP BY o.id, o.name;
```

#### **Level 3: Component Performance Analysis**
```sql
-- Component efficiency across offerings
SELECT 
    oc.title as component,
    COUNT(DISTINCT ooc.outcome_id) as outcomes_used_in,
    COUNT(DISTINCT mo.matter_id) as matters_using_component,
    AVG(ooc.estimated_units) as template_estimate,
    AVG(actual_time.units) as actual_average,
    (AVG(actual_time.units) - AVG(ooc.estimated_units)) as variance
FROM offering_components oc
JOIN offering_outcome_components ooc ON oc.id = ooc.component_id
JOIN matter_components mc ON ooc.id = mc.offering_outcome_component_id
JOIN matter_offerings mo ON mc.matter_outcome.matter_id = mo.matter_id
LEFT JOIN (
    SELECT matter_component_id, SUM(units) as units
    FROM time_entries 
    GROUP BY matter_component_id
) actual_time ON mc.id = actual_time.matter_component_id
GROUP BY oc.id, oc.title;
```

### **🔼 Bottom-Up Analysis (Time Entry → Offering)**

**Use Cases**: Profitability analysis, resource allocation, actual vs planned analysis

#### **Level 1: Time Entry Aggregation**
```sql
-- Time utilization by offering category
SELECT 
    oc.name as category,
    SUM(te.units) as total_time,
    COUNT(DISTINCT te.user_id) as unique_lawyers,
    COUNT(DISTINCT mc.matter_outcome_id) as matter_outcomes_worked,
    SUM(te.units * u.hourly_rate) as total_value
FROM time_entries te
JOIN matter_components mc ON te.matter_component_id = mc.id
JOIN matter_outcomes mout ON mc.matter_outcome_id = mout.id
JOIN matter_offerings mo ON mout.matter_id = mo.matter_id
JOIN offerings o ON mo.offering_id = o.id
JOIN offering_categories oc ON o.category_id = oc.id
JOIN users u ON te.user_id = u.id
GROUP BY oc.id, oc.name;
```

#### **Level 2: Matter Profitability**
```sql
-- Matter profitability with offering breakdown
SELECT 
    m.name as matter,
    STRING_AGG(o.name, ', ') as offerings_used,
    SUM(te.units) as total_time,
    SUM(te.units * u.hourly_rate) as total_cost,
    m.estimated_budget,
    (m.estimated_budget - SUM(te.units * u.hourly_rate)) as profit_margin
FROM matters m
JOIN matter_offerings mo ON m.id = mo.matter_id
JOIN offerings o ON mo.offering_id = o.id
JOIN matter_outcomes mout ON m.id = mout.matter_id
JOIN matter_components mc ON mout.id = mc.matter_outcome_id
JOIN time_entries te ON mc.id = te.matter_component_id
JOIN users u ON te.user_id = u.id
GROUP BY m.id, m.name, m.estimated_budget;
```

### **🔄 Cross-Linking Analysis**

**Use Cases**: Template optimization, client pattern analysis, service combinations

#### **Offering Combination Analysis**
```sql
-- Most common offering combinations
WITH matter_offering_combinations AS (
    SELECT 
        m.id as matter_id,
        STRING_AGG(o.name ORDER BY o.name, ', ') as offering_combination,
        COUNT(o.id) as offering_count
    FROM matters m
    JOIN matter_offerings mo ON m.id = mo.matter_id
    JOIN offerings o ON mo.offering_id = o.id
    GROUP BY m.id
)
SELECT 
    offering_combination,
    offering_count,
    COUNT(*) as matter_count,
    AVG(total_time.units) as avg_time_per_matter
FROM matter_offering_combinations moc
LEFT JOIN (
    SELECT 
        mout.matter_id,
        SUM(te.units) as units
    FROM matter_outcomes mout
    JOIN matter_components mc ON mout.id = mc.matter_outcome_id
    JOIN time_entries te ON mc.id = te.matter_component_id
    GROUP BY mout.matter_id
) total_time ON moc.matter_id = total_time.matter_id
GROUP BY offering_combination, offering_count
ORDER BY matter_count DESC;
```

---

## 📈 **Key Metrics Categories**

### **🎯 Offering Template Metrics**

#### **Usage & Adoption**
- **Offering utilization rate**: `matters_using_offering / total_active_matters`
- **Template market share**: `offering_instances / total_offering_instances`
- **Component reuse factor**: `components_in_multiple_outcomes / total_components`

#### **Performance & Accuracy**
- **Estimation accuracy**: `(actual_time - estimated_time) / estimated_time`
- **Template completion rate**: `completed_components / total_components`
- **Outcome success rate**: `successful_outcomes / total_outcomes`

#### **Evolution & Optimization**
- **Template modification frequency**: Changes to offering structure over time
- **Component retirement rate**: Components removed from active use
- **Cross-offering component usage**: Same components used across different offerings

### **⚖️ Matter Execution Metrics**

#### **Delivery Performance**
- **Matter completion time**: `actual_delivery_date - start_date`
- **Scope adherence**: `planned_components_executed / total_components_executed`
- **Budget variance**: `(actual_cost - estimated_budget) / estimated_budget`

#### **Resource Utilization**
- **Lawyer efficiency**: `time_per_component / estimated_time_per_component`
- **Multi-offering complexity**: `total_offerings_per_matter`
- **Component customization rate**: `modified_components / copied_components`

#### **Client & Business Value**
- **Matter profitability**: `revenue - (time_cost + overhead)`
- **Client satisfaction correlation**: Link to outcome delivery success
- **Repeat engagement rate**: Clients using same offerings multiple times

### **⏱️ Time & Resource Metrics**

#### **Operational Efficiency**
- **Time allocation accuracy**: Planned vs actual time distribution
- **Peak resource utilization**: Capacity planning for high-demand offerings
- **Skill-specific efficiency**: Component performance by lawyer specialization

#### **Financial Performance**
- **Revenue per offering instance**: `total_revenue / offering_instances`
- **Cost per component type**: Resource allocation by component category
- **Margin by service category**: Profitability across offering categories

### **🏢 Law Area & Specialization Metrics**

#### **Practice Area Performance**
- **Law area revenue concentration**: `revenue_per_law_area / total_revenue`
- **Specialization efficiency**: Component performance within law sub-areas
- **Cross-area collaboration**: Matters spanning multiple law areas

#### **Market Intelligence**
- **Service demand trends**: Offering popularity over time periods
- **Client segment preferences**: Offering usage by client characteristics
- **Competitive positioning**: Service delivery efficiency benchmarks

---

## 🎯 **Analytics Principles for Accurate Reporting**

### **1. Relationship Disambiguation**
- **Always specify** whether counting unique matters or offering instances
- **Use explicit joins** to avoid double-counting in many-to-many relationships
- **Clearly label metrics** with their counting methodology

### **2. Historical Data Integrity**
- **Respect connector fields**: Use `OfferingOutcomeId` and `OfferingOutcomeComponentId` for analytics
- **Preserve matter state**: Analyze matters as they were originally scoped, not current template state
- **Handle template evolution**: Account for structural changes in offerings over time

### **3. Cross-Dimensional Analysis**
- **Start with business question**: Determine top-down vs bottom-up approach
- **Cross-link strategically**: Only join across dimensions when necessary for specific insights
- **Aggregate thoughtfully**: Consider the right granularity for each metric

### **4. Performance Considerations**
- **Index connector fields**: Ensure `OfferingOutcomeId`, `OfferingOutcomeComponentId` are properly indexed
- **Use date filtering**: Historical analyses should include appropriate time boundaries
- **Cache expensive calculations**: Template performance metrics can be pre-computed

---

## 🔍 **Example Business Questions & Approaches**

| **Business Question** | **Count Type** | **Access Pattern** | **Key Joins** |
|----------------------|----------------|-------------------|---------------|
| "How popular is offering X?" | Unique matters | Top-down | matter_offerings |
| "What's our revenue from offering X?" | Offering instances | Bottom-up | time_entries → matter_components |
| "Which lawyers are most efficient at component Y?" | Component instances | Cross-link | time_entries ↔ offering_components |
| "What offering combinations are most profitable?" | Matter groups | Cross-link | matter_offerings + time_entries |
| "How accurate are our component estimates?" | Component instances | Bottom-up | matter_components → time_entries |

This framework ensures accurate, meaningful analytics while respecting the complex data relationships and maintaining historical integrity.