# ALP Project Management System
## Comprehensive Guide to Internal Project Coordination & Analytics

### Overview & Purpose

The ALP project management system handles **internal firm projects** separate from client matter work. This includes business development initiatives, system implementations, training programs, administrative projects, and other non-client activities essential for firm operations and growth.

**Key Distinction: Projects vs Matters**
- **Projects**: Internal firm activities (training, systems, business development)
- **Matters**: Client legal work (using offering templates and matter components)
- **Different Time Tracking**: `ProjectTaskTimeEntry` vs `MatterComponentTimeEntry`
- **Different Analytics**: Internal efficiency vs client profitability

---

## Database Schema

### 📊 **Core Tables**

```sql
-- Main project entity
projects (
    id, name, description, due_date, complete,
    owner_id, template_id, business_area_id, capability_id, sub_capability_id,
    sharepoint_folder, is_created_by_scheduler, is_bau,
    inserted_at, updated_at, inserted_by_id, last_updated_by_id, is_deleted
)

-- Individual project tasks
project_tasks (
    id, project_id, name, description, assigned_user_id,
    due_date, complete, order_index,
    estimated_hours, actual_hours, 
    inserted_at, updated_at, inserted_by_id, last_updated_by_id, is_deleted
)

-- Project templates for repeatable processes
project_templates (
    id, name, description, business_area_id, capability_id,
    is_active, template_data,
    inserted_at, updated_at, inserted_by_id, last_updated_by_id, is_deleted
)

-- Project team assignments
project_team_members (
    project_id, user_id, role,
    inserted_at, updated_at, is_deleted
)

-- Project milestones and deliverables
project_milestones (
    id, project_id, name, description, due_date, 
    complete, completion_date,
    inserted_at, updated_at, is_deleted
)
```

### 🔗 **Key Relationships**

```sql
-- User relationships
projects.owner_id → users.id
project_tasks.assigned_user_id → users.id

-- Template relationships
projects.template_id → project_templates.id

-- Time tracking relationships
time_entries.project_task_id → project_tasks.id
-- (where time_entries.discriminator = 'ProjectTaskTimeEntry')

-- Business classification
projects.business_area_id → business_areas.id
projects.capability_id → capabilities.id
```

---

## Project Types & Classification

### 📊 **Project Categories**

#### **1. Business as Usual (BAU) Projects**
- **Flag**: `is_bau = true`
- **Purpose**: Routine operational activities
- **Examples**: Monthly reporting, system maintenance, compliance reviews
- **Time Tracking**: Usually non-billable operational overhead

#### **2. Strategic Projects**  
- **Flag**: `is_bau = false`
- **Purpose**: Firm development and improvement initiatives
- **Examples**: New system implementations, practice development, training programs
- **Time Tracking**: Investment in firm capabilities

#### **3. Scheduled Projects**
- **Flag**: `is_created_by_scheduler = true`
- **Purpose**: Automatically generated recurring projects
- **Examples**: Regular compliance tasks, maintenance schedules
- **Management**: System-driven creation and tracking

### 🎯 **Business Area Classification**

Projects are classified by business areas and capabilities:

```sql
-- Project classification breakdown
SELECT 
  ba.name as business_area,
  c.name as capability,
  COUNT(p.id) as project_count,
  COUNT(CASE WHEN p.complete = true THEN 1 END) as completed_projects,
  COUNT(CASE WHEN p.is_bau = true THEN 1 END) as bau_projects,
  COUNT(CASE WHEN p.is_bau = false THEN 1 END) as strategic_projects,
  AVG(EXTRACT(EPOCH FROM (p.due_date - p.inserted_at))/86400) as avg_project_duration_days
FROM projects p
LEFT JOIN business_areas ba ON p.business_area_id = ba.id
LEFT JOIN capabilities c ON p.capability_id = c.id
WHERE p.is_deleted = false
GROUP BY ba.id, ba.name, c.id, c.name
ORDER BY project_count DESC;
```

---

## Project Lifecycle & Management

### 📈 **Project Status Tracking**

```sql
-- Project completion and progress analysis
WITH project_status AS (
  SELECT 
    p.id as project_id,
    p.name as project_name,
    p.complete as project_complete,
    p.due_date,
    p.is_bau,
    owner.first_name || ' ' || owner.last_name as project_owner,
    COUNT(pt.id) as total_tasks,
    COUNT(CASE WHEN pt.complete = true THEN 1 END) as completed_tasks,
    CASE 
      WHEN COUNT(pt.id) = 0 THEN 0
      ELSE ROUND((COUNT(CASE WHEN pt.complete = true THEN 1 END) * 100.0) / COUNT(pt.id), 1)
    END as completion_percentage,
    CASE 
      WHEN p.due_date < CURRENT_DATE AND p.complete = false THEN 'Overdue'
      WHEN p.due_date <= CURRENT_DATE + INTERVAL '7 days' AND p.complete = false THEN 'Due Soon'
      WHEN p.complete = true THEN 'Complete'
      ELSE 'On Track'
    END as status
  FROM projects p
  LEFT JOIN users owner ON p.owner_id = owner.id
  LEFT JOIN project_tasks pt ON p.id = pt.project_id AND pt.is_deleted = false
  WHERE p.is_deleted = false
  GROUP BY p.id, p.name, p.complete, p.due_date, p.is_bau, 
           owner.first_name, owner.last_name
)
SELECT 
  status,
  COUNT(*) as project_count,
  AVG(completion_percentage) as avg_completion,
  COUNT(CASE WHEN is_bau = true THEN 1 END) as bau_count,
  COUNT(CASE WHEN is_bau = false THEN 1 END) as strategic_count
FROM project_status
GROUP BY status
ORDER BY 
  CASE status
    WHEN 'Overdue' THEN 1
    WHEN 'Due Soon' THEN 2
    WHEN 'On Track' THEN 3
    WHEN 'Complete' THEN 4
  END;
```

### 👥 **Team Workload Distribution**

```sql
-- Project task assignment and workload analysis
SELECT 
  u.first_name || ' ' || u.last_name as team_member,
  COUNT(DISTINCT pt.project_id) as projects_involved,
  COUNT(pt.id) as total_tasks,
  COUNT(CASE WHEN pt.complete = true THEN 1 END) as completed_tasks,
  COUNT(CASE WHEN pt.due_date < CURRENT_DATE AND pt.complete = false THEN 1 END) as overdue_tasks,
  SUM(pt.estimated_hours) as estimated_hours,
  SUM(
    (SELECT SUM(te.units / 10.0)
     FROM time_entries te 
     WHERE te.project_task_id = pt.id 
       AND te.discriminator = 'ProjectTaskTimeEntry'
       AND te.is_deleted = false
    )
  ) as actual_hours,
  ROUND(
    (COUNT(CASE WHEN pt.complete = true THEN 1 END) * 100.0) / 
    NULLIF(COUNT(pt.id), 0), 1
  ) as completion_rate
FROM users u
JOIN project_tasks pt ON u.id = pt.assigned_user_id
JOIN projects p ON pt.project_id = p.id
WHERE u.is_deleted = false
  AND pt.is_deleted = false
  AND p.is_deleted = false
  AND p.complete = false  -- Only active projects
GROUP BY u.id, u.first_name, u.last_name
ORDER BY overdue_tasks DESC, total_tasks DESC;
```

---

## Time Tracking Integration

### ⏰ **ProjectTaskTimeEntry Analysis**

Projects use the time tracking inheritance pattern with `ProjectTaskTimeEntry`:

```sql
-- Project time tracking analysis
WITH project_time_summary AS (
  SELECT 
    p.id as project_id,
    p.name as project_name,
    p.is_bau,
    pt.id as task_id,
    pt.name as task_name,
    pt.estimated_hours,
    SUM(te.units / 10.0) as actual_hours,
    COUNT(te.id) as time_entries,
    SUM((te.units / 10.0) * (te.rate / 10.0)) as total_cost,
    pt.complete as task_complete
  FROM projects p
  JOIN project_tasks pt ON p.id = pt.project_id
  LEFT JOIN time_entries te ON pt.id = te.project_task_id 
    AND te.discriminator = 'ProjectTaskTimeEntry'
    AND te.is_deleted = false
  WHERE p.is_deleted = false
    AND pt.is_deleted = false
  GROUP BY p.id, p.name, p.is_bau, pt.id, pt.name, pt.estimated_hours, pt.complete
)
SELECT 
  project_name,
  CASE WHEN is_bau = true THEN 'BAU' ELSE 'Strategic' END as project_type,
  COUNT(task_id) as task_count,
  SUM(estimated_hours) as total_estimated_hours,
  SUM(actual_hours) as total_actual_hours,
  SUM(total_cost) as total_project_cost,
  CASE 
    WHEN SUM(estimated_hours) > 0 THEN
      ROUND(((SUM(actual_hours) - SUM(estimated_hours)) * 100.0) / SUM(estimated_hours), 1)
    ELSE NULL
  END as time_variance_percent,
  COUNT(CASE WHEN task_complete = true THEN 1 END) as completed_tasks,
  ROUND(
    (COUNT(CASE WHEN task_complete = true THEN 1 END) * 100.0) / COUNT(task_id), 1
  ) as completion_percentage
FROM project_time_summary
GROUP BY project_id, project_name, is_bau
HAVING SUM(time_entries) > 0  -- Only projects with recorded time
ORDER BY total_project_cost DESC;
```

### 📊 **Resource Allocation Analysis**

```sql
-- Internal resource allocation: projects vs matters
WITH resource_allocation AS (
  SELECT 
    u.first_name || ' ' || u.last_name as user_name,
    -- Project time
    SUM(CASE WHEN te.discriminator = 'ProjectTaskTimeEntry' THEN te.units ELSE 0 END) / 10.0 as project_hours,
    -- Matter time
    SUM(CASE WHEN te.discriminator = 'MatterComponentTimeEntry' THEN te.units ELSE 0 END) / 10.0 as matter_hours,
    -- Sales time
    SUM(CASE WHEN te.discriminator = 'SalesTimeEntry' THEN te.units ELSE 0 END) / 10.0 as sales_hours,
    -- Total time
    SUM(te.units) / 10.0 as total_hours,
    -- Cost analysis
    SUM(CASE WHEN te.discriminator = 'ProjectTaskTimeEntry' THEN 
      (te.units / 10.0) * (te.rate / 10.0) ELSE 0 END) as project_cost,
    SUM(CASE WHEN te.discriminator = 'MatterComponentTimeEntry' AND te.billable_type = 1 THEN 
      (te.units / 10.0) * (te.rate / 10.0) ELSE 0 END) as billable_revenue
  FROM users u
  LEFT JOIN time_entries te ON u.id = te.user_id 
    AND te.is_deleted = false
    AND te.date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months')
  WHERE u.is_deleted = false
    AND u.billing_rate > 0
  GROUP BY u.id, u.first_name, u.last_name
)
SELECT 
  user_name,
  project_hours,
  matter_hours,
  sales_hours,
  total_hours,
  project_cost,
  billable_revenue,
  CASE WHEN total_hours > 0 THEN
    ROUND((project_hours / total_hours) * 100, 1)
  ELSE 0 END as project_time_percentage,
  CASE WHEN total_hours > 0 THEN
    ROUND((matter_hours / total_hours) * 100, 1)
  ELSE 0 END as matter_time_percentage,
  CASE WHEN total_hours > 0 THEN
    ROUND((sales_hours / total_hours) * 100, 1)
  ELSE 0 END as sales_time_percentage
FROM resource_allocation
WHERE total_hours > 0
ORDER BY total_hours DESC;
```

---

## Analytics Patterns

### 📈 **Project Portfolio Health**

```sql
-- Overall project portfolio status
SELECT 
  CASE 
    WHEN p.complete = true THEN 'Completed'
    WHEN p.due_date < CURRENT_DATE THEN 'Overdue'
    WHEN p.due_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'Due Within 30 Days'
    ELSE 'Future'
  END as project_status,
  COUNT(*) as project_count,
  COUNT(CASE WHEN p.is_bau = true THEN 1 END) as bau_count,
  COUNT(CASE WHEN p.is_bau = false THEN 1 END) as strategic_count,
  AVG(
    CASE 
      WHEN pt_stats.total_tasks > 0 THEN 
        (pt_stats.completed_tasks * 100.0) / pt_stats.total_tasks
      ELSE 0
    END
  ) as avg_completion_percentage
FROM projects p
LEFT JOIN (
  SELECT 
    project_id,
    COUNT(*) as total_tasks,
    COUNT(CASE WHEN complete = true THEN 1 END) as completed_tasks
  FROM project_tasks
  WHERE is_deleted = false
  GROUP BY project_id
) pt_stats ON p.id = pt_stats.project_id
WHERE p.is_deleted = false
GROUP BY 
  CASE 
    WHEN p.complete = true THEN 'Completed'
    WHEN p.due_date < CURRENT_DATE THEN 'Overdue'
    WHEN p.due_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'Due Within 30 Days'
    ELSE 'Future'
  END
ORDER BY 
  CASE 
    WHEN project_status = 'Overdue' THEN 1
    WHEN project_status = 'Due Within 30 Days' THEN 2
    WHEN project_status = 'Future' THEN 3
    WHEN project_status = 'Completed' THEN 4
  END;
```

### 🎯 **Template Effectiveness**

```sql
-- Project template usage and success rates
SELECT 
  pt.name as template_name,
  COUNT(p.id) as projects_created,
  COUNT(CASE WHEN p.complete = true THEN 1 END) as completed_projects,
  ROUND(
    (COUNT(CASE WHEN p.complete = true THEN 1 END) * 100.0) / COUNT(p.id), 1
  ) as completion_rate,
  AVG(EXTRACT(EPOCH FROM (p.due_date - p.inserted_at))/86400) as avg_planned_duration,
  AVG(
    CASE WHEN p.complete = true THEN
      EXTRACT(EPOCH FROM (p.updated_at - p.inserted_at))/86400
    END
  ) as avg_actual_duration,
  AVG(task_stats.avg_task_count) as avg_tasks_per_project,
  AVG(time_stats.total_hours) as avg_hours_per_project
FROM project_templates pt
LEFT JOIN projects p ON pt.id = p.template_id AND p.is_deleted = false
LEFT JOIN (
  SELECT 
    project_id,
    COUNT(*) as avg_task_count
  FROM project_tasks
  WHERE is_deleted = false
  GROUP BY project_id
) task_stats ON p.id = task_stats.project_id
LEFT JOIN (
  SELECT 
    pt.project_id,
    SUM(te.units / 10.0) as total_hours
  FROM project_tasks pt
  LEFT JOIN time_entries te ON pt.id = te.project_task_id 
    AND te.discriminator = 'ProjectTaskTimeEntry'
    AND te.is_deleted = false
  WHERE pt.is_deleted = false
  GROUP BY pt.project_id
) time_stats ON p.id = time_stats.project_id
WHERE pt.is_deleted = false
  AND pt.is_active = true
GROUP BY pt.id, pt.name
HAVING COUNT(p.id) > 0
ORDER BY completion_rate DESC, projects_created DESC;
```

---

## Integration Points with Other Modules

### 🔗 **Time Tracking Integration**
- **File**: [ALP_Time_Tracking.md](./ALP_Time_Tracking.md)
- **Relationship**: `ProjectTaskTimeEntry` for internal project work
- **Key Logic**: Non-billable time tracking separate from client work

### 🔗 **Matter Management Integration**
- **File**: [ALP_Matter_Management.md](./ALP_Matter_Management.md)
- **Relationship**: Projects are internal work, matters are client work
- **Key Logic**: Resource allocation between internal projects and client matters

### 🔗 **User Management Integration**
- **File**: [ALP_User_Management.md](./ALP_User_Management.md)
- **Relationship**: Project ownership and task assignment
- **Key Logic**: Workload distribution and capacity planning

---

## Critical Business Logic

### ⚠️ **Projects vs Matters Distinction**

```sql
-- Clear separation of internal vs client work
-- PROJECTS (Internal)
SELECT 'Project' as work_type, p.name, pt.name as task_name
FROM projects p
JOIN project_tasks pt ON p.id = pt.project_id
WHERE p.is_deleted = false AND pt.is_deleted = false

-- MATTERS (Client Work)  
SELECT 'Matter' as work_type, m.name, mc.title as component_name
FROM matters m
JOIN matter_outcomes mo ON m.id = mo.matter_id
JOIN matter_components mc ON mo.id = mc.matter_outcome_id
WHERE m.is_deleted = false AND mo.is_deleted = false AND mc.is_deleted = false
```

### 📊 **Time Entry Classification**

```sql
-- Time tracking by work type
SELECT 
  te.discriminator,
  CASE 
    WHEN te.discriminator = 'ProjectTaskTimeEntry' THEN 'Internal Project Work'
    WHEN te.discriminator = 'MatterComponentTimeEntry' THEN 'Client Matter Work'
    WHEN te.discriminator = 'SalesTimeEntry' THEN 'Business Development'
  END as work_classification,
  COUNT(*) as entry_count,
  SUM(te.units / 10.0) as total_hours,
  SUM((te.units / 10.0) * (te.rate / 10.0)) as total_cost
FROM time_entries te
WHERE te.is_deleted = false
  AND te.date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months')
GROUP BY te.discriminator
ORDER BY total_hours DESC;
```

---

## Example Metabase Queries

### Project Dashboard
```sql
-- Executive project overview
SELECT 
  ba.name as business_area,
  COUNT(p.id) as total_projects,
  COUNT(CASE WHEN p.complete = true THEN 1 END) as completed,
  COUNT(CASE WHEN p.due_date < CURRENT_DATE AND p.complete = false THEN 1 END) as overdue,
  COUNT(CASE WHEN p.is_bau = true THEN 1 END) as bau_projects,
  COUNT(CASE WHEN p.is_bau = false THEN 1 END) as strategic_projects,
  SUM(
    (SELECT SUM(te.units / 10.0)
     FROM project_tasks pt 
     JOIN time_entries te ON pt.id = te.project_task_id
     WHERE pt.project_id = p.id 
       AND te.discriminator = 'ProjectTaskTimeEntry'
       AND pt.is_deleted = false 
       AND te.is_deleted = false
    )
  ) as total_hours_invested
FROM business_areas ba
LEFT JOIN projects p ON ba.id = p.business_area_id AND p.is_deleted = false
WHERE ba.is_deleted = false
GROUP BY ba.id, ba.name
ORDER BY total_projects DESC;
```

### Team Workload Report
```sql
-- Individual project workload tracking
SELECT 
  u.first_name || ' ' || u.last_name as team_member,
  COUNT(DISTINCT p.id) as active_projects,
  COUNT(pt.id) as assigned_tasks,
  COUNT(CASE WHEN pt.complete = true THEN 1 END) as completed_tasks,
  SUM(pt.estimated_hours) as estimated_hours,
  SUM(
    (SELECT SUM(te.units / 10.0)
     FROM time_entries te 
     WHERE te.project_task_id = pt.id 
       AND te.discriminator = 'ProjectTaskTimeEntry'
       AND te.is_deleted = false
    )
  ) as actual_hours
FROM users u
LEFT JOIN project_tasks pt ON u.id = pt.assigned_user_id 
  AND pt.is_deleted = false
LEFT JOIN projects p ON pt.project_id = p.id 
  AND p.is_deleted = false 
  AND p.complete = false
WHERE u.is_deleted = false
GROUP BY u.id, u.first_name, u.last_name
HAVING COUNT(pt.id) > 0
ORDER BY active_projects DESC, assigned_tasks DESC;
```

---

## Links to Related Modules

- **[Time Tracking](./ALP_Time_Tracking.md)** - ProjectTaskTimeEntry time tracking
- **[Matter Management](./ALP_Matter_Management.md)** - Internal vs client work distinction
- **[User Management](./ALP_User_Management.md)** - Project team management and workload
- **[Service Delivery](./ALP_Offerings_Service_Delivery.md)** - Template-based project management

---

**Last Updated**: December 2024  
**Version**: 1.0  
**Related Framework**: [Query Development Framework Summary](./Query_Development_Framework_Summary.md) 