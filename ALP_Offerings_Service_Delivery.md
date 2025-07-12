# ALP Service Delivery & Offerings
## Comprehensive Guide to Legal Service Templates & Delivery

### Overview & Purpose

The ALP service delivery system is built around **Offerings** - structured templates that define how legal services are delivered to clients. This sophisticated architecture moves beyond simple time tracking to provide standardized, repeatable service delivery frameworks with built-in quality control and resource management.

**Key Components:**
- **Offering Categories**: High-level service groupings (e.g., Corporate Law, Property Law)
- **Offerings**: Specific service templates with rich marketing and delivery content
- **Offering Outcomes**: Specific deliverables/results within each offering
- **Offering Components**: Individual tasks/activities required to achieve outcomes
- **Matter Implementation**: How offering templates are instantiated for real client work

---

## Architecture & Hierarchy

### 🏗️ **Service Delivery Hierarchy**

```
Offering Categories
├── Offerings (Service Templates)
    ├── Offering Outcomes (Deliverables)
        ├── Offering Components (Tasks)
            └── Resources (Templates, Tools, References)

INSTANTIATION FOR CLIENT WORK:
Matters
├── Matter Outcomes (Copied from Offering Outcomes)
    ├── Matter Components (Copied from Offering Components)
        └── Time Entries (Actual work performed)
```

### 📊 **Database Schema**

```sql
-- High-level service categories
offering_categories (
    id, name, description, active, 
    inserted_at, updated_at, is_deleted
)

-- Service templates with rich content
offerings (
    id, name, title, category_id, active,
    -- Marketing content
    zippy_heading, key_problem, solution,
    grunt_line, situation, what_we_do, why_better,
    -- Storytelling content  
    quick_story_heading, story_external_problem,
    story_problem_ignored, story_problem_solution, story_problem_solved,
    -- Positioning content
    character, scenario, salt, villain,
    -- Action content
    call_to_action_heading, call_to_action,
    expressions_of_empathy, indicators_of_authority,
    -- Process content
    step_plan_heading, step_plan_tag_line_1, step_plan_tag_line_2,
    sharepoint_folder,
    inserted_at, updated_at, is_deleted
)

-- Deliverables within offerings
offering_outcomes (
    id, offering_id, name, description, failure,
    inserted_at, updated_at, is_deleted
)

-- Tasks/activities to achieve outcomes
offering_components (
    id, offering_id, name, description, 
    duration_days, buffer_days, estimated_units, budget,
    law_sub_area_id, weight,
    inserted_at, updated_at, is_deleted
)

-- Bridge table: outcomes to components
offering_outcome_components (
    id, outcome_id, component_id, title, description,
    estimated_units, budget, law_sub_area_id, weight,
    inserted_at, updated_at, is_deleted
)
```

---

## Offering Categories

### 🎯 **Purpose & Structure**

**Function**: High-level organization of legal services
**Examples**: 
- Corporate & Commercial Law
- Property & Conveyancing  
- Family Law & Relationships
- Employment Law
- Litigation & Dispute Resolution

**Business Logic**:
- Simple categorization system
- `active` flag controls visibility
- Used for reporting and service mix analysis

### 📊 **Analytics Patterns**

```sql
-- Service mix analysis by category
SELECT 
    oc.name as category_name,
    COUNT(DISTINCT o.id) as offering_count,
    COUNT(DISTINCT m.id) as matter_count,
    SUM(CASE WHEN m.status = 4 THEN 1 ELSE 0 END) as open_matters,
    AVG(m.estimated_budget) as avg_estimated_budget
FROM offering_categories oc
LEFT JOIN offerings o ON oc.id = o.category_id AND o.is_deleted = false
LEFT JOIN matters m ON o.id = ANY(m.offering_ids) AND m.is_deleted = false
WHERE oc.is_deleted = false
GROUP BY oc.id, oc.name
ORDER BY matter_count DESC;
```

---

## Offerings (Service Templates)

### 🎯 **Rich Content Structure**

Offerings contain extensive marketing and delivery content structured around proven business frameworks:

#### **Zippy Scooter Line** (Problem/Solution Framework)
- `zippy_heading`: Attention-grabbing headline
- `key_problem`: Core client pain point
- `solution`: How the firm addresses the problem

#### **Grunt Test** (Value Proposition Framework)  
- `grunt_line`: Elevator pitch
- `situation`: Client circumstances
- `what_we_do`: Service description
- `why_better`: Competitive advantage

#### **Quick Story** (Narrative Framework)
- `story_external_problem`: Observable challenge
- `story_problem_ignored`: Consequences of inaction
- `story_problem_solution`: Intervention approach
- `story_problem_solved`: Successful outcome

#### **Scenario Positioning** (Character Framework)
- `character`: Ideal client persona
- `scenario`: Typical situation
- `salt`: Pain point amplification
- `villain`: What works against the client

#### **Call to Action** (Engagement Framework)
- `call_to_action`: Next steps for clients
- `expressions_of_empathy`: Understanding statements
- `indicators_of_authority`: Credibility markers

#### **Step Plan** (Process Framework)
- `step_plan_heading`: Process overview
- `step_plan`: Detailed implementation steps
- Value points and deliverable breakdowns

### 🔗 **Integration Points**

```sql
-- Offerings can be linked to multiple areas
offerings.law_area_id → law_areas.id
offerings.law_sub_area_id → law_sub_areas.id  
offerings.segment_id → segments.id
offerings.sub_segment_id → sub_segments.id

-- SharePoint integration
offerings.sharepoint_folder → Document templates and resources

-- User relationships
offering_permitted_reviewers → Review/approval workflows
offering_sales_team → Sales responsibility
```

---

## Offering Outcomes & Components

### 🎯 **Outcomes: Service Deliverables**

**Purpose**: Define specific results the firm commits to deliver

**Structure**:
- **Name**: Outcome title (e.g., "Property Purchase Complete") 
- **Description**: Detailed outcome specification
- **Failure**: What constitutes unsuccessful delivery

**Analytics Value**:
- Track delivery success rates
- Identify common failure points
- Measure client satisfaction by outcome

### ⚙️ **Components: Task Breakdown** 

**Purpose**: Granular tasks required to achieve outcomes

**Estimation Fields**:
- `duration_days`: Expected completion time
- `buffer_days`: Risk buffer for delays
- `estimated_units`: Time in 6-minute increments
- `budget`: Expected cost

**Classification**:
- `law_sub_area_id`: Legal specialty area
- `weight`: Relative importance/complexity

### 🔗 **Outcome-Component Relationships**

The `offering_outcome_components` table creates flexible many-to-many relationships:
- Same component can contribute to multiple outcomes
- Components can be reused across different offerings
- Allows for complex service delivery models

---

## Template-to-Reality: Matter Implementation

### 🔄 **Copy-on-Create Pattern**

When a matter is created from an offering:

1. **Offering Outcomes** → **Matter Outcomes** (copied)
2. **Offering Components** → **Matter Components** (copied)  
3. **Time Entries** → Recorded against **Matter Components**

**Critical Business Logic**:
```sql
-- Matter outcomes retain offering reference
matter_outcomes.offering_outcome_id → offering_outcomes.id

-- Matter components retain offering reference  
matter_components.offering_component_id → offering_components.id
matter_components.offering_outcome_component_id → offering_outcome_components.id

-- Time entries link to matter components
time_entries.matter_component_id → matter_components.id
```

### 🎯 **Benefits of Copy Pattern**

1. **Historical Stability**: Changes to offerings don't affect existing matters
2. **Matter Customization**: Components can be modified for specific clients
3. **Template Evolution**: Offerings can be improved based on matter performance
4. **Analytics Integrity**: Historical analysis remains valid

---

## Analytics Patterns

### 📊 **Template Performance Analysis**

```sql
-- Offering efficiency: estimated vs actual
WITH offering_performance AS (
  SELECT 
    o.name as offering_name,
    oc.name as category_name,
    ocomp.name as component_name,
    -- Template estimates
    ocomp.estimated_units as estimated_time,
    ocomp.budget as estimated_cost,
    -- Actual performance from matters
    COUNT(mc.id) as matter_count,
    AVG(mc.total_units) as avg_actual_time,
    AVG(
      (SELECT SUM((te.units / 10.0) * (te.rate / 10.0))
       FROM time_entries te 
       WHERE te.matter_component_id = mc.id 
         AND te.is_deleted = false
         AND te.discriminator = 'MatterComponentTimeEntry'
      )
    ) as avg_actual_cost
  FROM offerings o
  JOIN offering_categories oc ON o.category_id = oc.id
  JOIN offering_components ocomp ON o.id = ocomp.offering_id
  JOIN matter_components mc ON ocomp.id = mc.offering_component_id
  WHERE o.is_deleted = false
    AND oc.is_deleted = false  
    AND ocomp.is_deleted = false
    AND mc.is_deleted = false
  GROUP BY o.id, o.name, oc.name, ocomp.id, ocomp.name, 
           ocomp.estimated_units, ocomp.budget
)
SELECT 
  offering_name,
  category_name,
  component_name,
  matter_count,
  estimated_time / 10.0 as estimated_hours,
  avg_actual_time / 10.0 as avg_actual_hours,
  estimated_cost / 10.0 as estimated_cost,
  avg_actual_cost,
  -- Variance analysis
  CASE 
    WHEN estimated_time > 0 THEN 
      ROUND(((avg_actual_time - estimated_time) * 100.0) / estimated_time, 2)
    ELSE NULL 
  END as time_variance_percent,
  CASE 
    WHEN estimated_cost > 0 THEN 
      ROUND(((avg_actual_cost - estimated_cost/10.0) * 100.0) / (estimated_cost/10.0), 2)
    ELSE NULL 
  END as cost_variance_percent
FROM offering_performance
WHERE matter_count >= 3  -- Only include components with sufficient data
ORDER BY ABS(time_variance_percent) DESC;
```

### 📈 **Service Delivery Success Rates**

```sql
-- Outcome delivery analysis
SELECT 
  oc.name as category_name,
  o.name as offering_name,
  oout.name as outcome_name,
  COUNT(mo.id) as total_deliveries,
  SUM(CASE WHEN mo.complete = true THEN 1 ELSE 0 END) as successful_deliveries,
  ROUND(
    (SUM(CASE WHEN mo.complete = true THEN 1 ELSE 0 END) * 100.0) / 
    COUNT(mo.id), 2
  ) as success_rate_percent,
  AVG(
    EXTRACT(EPOCH FROM (mo.completed_at - mo.inserted_at))/86400
  ) as avg_delivery_days
FROM offering_categories oc
JOIN offerings o ON oc.id = o.category_id
JOIN offering_outcomes oout ON o.id = oout.offering_id  
JOIN matter_outcomes mo ON oout.id = mo.offering_outcome_id
WHERE oc.is_deleted = false
  AND o.is_deleted = false
  AND oout.is_deleted = false  
  AND mo.is_deleted = false
GROUP BY oc.name, o.name, oout.name
HAVING COUNT(mo.id) >= 5  -- Sufficient sample size
ORDER BY success_rate_percent ASC;  -- Show problem areas first
```

### 🎯 **Component Reuse Analysis**

```sql
-- Identify highly reusable components
SELECT 
  ocomp.name as component_name,
  ocomp.description,
  COUNT(DISTINCT o.id) as offering_count,
  COUNT(DISTINCT mc.id) as matter_usage_count,
  AVG(mc.total_units / 10.0) as avg_hours_per_use,
  AVG(ocomp.estimated_units / 10.0) as estimated_hours,
  COUNT(DISTINCT las.id) as law_area_count
FROM offering_components ocomp
JOIN offerings o ON ocomp.offering_id = o.id
LEFT JOIN matter_components mc ON ocomp.id = mc.offering_component_id
LEFT JOIN law_sub_areas las ON ocomp.law_sub_area_id = las.id
WHERE ocomp.is_deleted = false
  AND o.is_deleted = false
GROUP BY ocomp.id, ocomp.name, ocomp.description, ocomp.estimated_units
HAVING COUNT(DISTINCT o.id) > 1  -- Used in multiple offerings
ORDER BY matter_usage_count DESC;
```

---

## Business Intelligence Applications

### 🎯 **Service Development Insights**

1. **Template Optimization**: Identify consistently over/under-estimated components
2. **Service Standardization**: Find successful patterns for replication
3. **Resource Planning**: Forecast capacity needs based on offering mix
4. **Pricing Accuracy**: Validate pricing models against actual delivery costs

### 📊 **Client Value Analysis**

1. **Outcome Success Tracking**: Which services deliver promised results?
2. **Client Satisfaction Correlation**: Link service delivery to satisfaction scores
3. **Service Mix Optimization**: Which offerings drive highest client value?
4. **Cross-Selling Opportunities**: Identify complementary service patterns

### 💰 **Financial Performance**

1. **Service Profitability**: Revenue vs delivery cost by offering type
2. **Capacity Utilization**: How efficiently are service templates being executed?
3. **Pipeline Analysis**: Which offerings drive strongest business development?

---

## Integration Points with Other Modules

### 🔗 **Matter Management Integration**
- **File**: [ALP_Matter_Management.md](./ALP_Matter_Management.md)
- **Relationship**: Matters instantiate offering templates
- **Key Logic**: Copy-on-create pattern for outcomes and components

### 🔗 **Time Tracking Integration**
- **File**: [ALP_Time_Tracking.md](./ALP_Time_Tracking.md)  
- **Relationship**: Time entries recorded against matter components
- **Key Logic**: Component estimates vs actual time analysis

### 🔗 **Invoicing Integration**
- **File**: [ALP_Invoicing_Business_Logic.md](./ALP_Invoicing_Business_Logic.md)
- **Relationship**: Service delivery drives billing events
- **Key Logic**: Fixed-price offerings affect time entry allocation

### 🔗 **Project Management Integration**
- **File**: [ALP_Project_Management.md](./ALP_Project_Management.md)
- **Relationship**: Complex offerings may spawn project management workflows
- **Key Logic**: Service delivery vs project execution coordination

---

## Critical Enum Mappings

```sql
-- Offering Active Status
CASE 
  WHEN o.active = true THEN 'Active'
  WHEN o.active = false THEN 'Inactive'  
END

-- Component Weight (Relative Importance)
-- Higher numbers = more critical/complex components

-- Duration/Buffer Days
-- duration_days: Expected completion time
-- buffer_days: Risk allowance for delays  

-- Estimated Units (6-minute increments)
-- estimated_units / 10.0 = estimated hours
```

---

## Gotchas & Special Considerations

### ⚠️ **Template vs Reality Gaps**

1. **Evolution Lag**: Templates may not reflect current best practices
2. **Client Customization**: Matter components often modified from templates
3. **Scope Creep**: Actual work may exceed original offering scope
4. **Skills Variance**: Different lawyers may execute same component differently

### ⚠️ **Analytics Considerations**

1. **Sample Size**: Ensure sufficient matter count for statistical validity
2. **Time Period Bias**: Service delivery efficiency may vary by period
3. **Client Complexity**: Some clients require more/less work for same outcome
4. **Template Versioning**: Historical analysis complicated by template changes

### ⚠️ **Performance Implications**

1. **Complex Joins**: Offering → Matter → Time Entry joins can be expensive
2. **Aggregation Complexity**: Component-level analysis requires careful grouping
3. **Historical Data**: Large datasets require date filtering and indexing

---

## Example Metabase Queries

### Service Portfolio Overview
```sql
-- High-level service delivery dashboard
SELECT 
  oc.name as service_category,
  COUNT(DISTINCT o.id) as offering_count,
  COUNT(DISTINCT m.id) as active_matters,
  AVG(m.estimated_budget / 10.0) as avg_matter_budget,
  SUM(
    CASE WHEN m.status = 5 THEN 1 ELSE 0 END
  ) as completed_matters
FROM offering_categories oc
LEFT JOIN offerings o ON oc.id = o.category_id 
  AND o.is_deleted = false AND o.active = true
LEFT JOIN matters m ON o.id = ANY(m.offering_ids)
  AND m.is_deleted = false
WHERE oc.is_deleted = false
GROUP BY oc.id, oc.name
ORDER BY active_matters DESC;
```

### Component Efficiency Tracking
```sql
-- Track component delivery efficiency
SELECT 
  ocomp.name as component_name,
  COUNT(mc.id) as usage_count,
  AVG(ocomp.estimated_units / 10.0) as est_hours,
  AVG(mc.total_units / 10.0) as actual_hours,
  ROUND(
    AVG((mc.total_units - ocomp.estimated_units) * 100.0 / ocomp.estimated_units), 1
  ) as variance_percent
FROM offering_components ocomp
JOIN matter_components mc ON ocomp.id = mc.offering_component_id
WHERE ocomp.is_deleted = false
  AND mc.is_deleted = false
  AND ocomp.estimated_units > 0
GROUP BY ocomp.id, ocomp.name
HAVING COUNT(mc.id) >= 3
ORDER BY ABS(variance_percent) DESC;
```

---

## Links to Related Modules

- **[Matter Management](./ALP_Matter_Management.md)** - How offerings become client work
- **[Time Tracking](./ALP_Time_Tracking.md)** - Recording work against service components
- **[Invoicing](./ALP_Invoicing_Business_Logic.md)** - Billing for service delivery
- **[Project Management](./ALP_Project_Management.md)** - Complex service delivery coordination
- **[Document Management](./ALP_Document_Management.md)** - Service delivery templates and resources

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Related Framework**: [Query Development Framework Summary](./Query_Development_Framework_Summary.md) 