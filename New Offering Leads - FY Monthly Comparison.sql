-- New Offering Leads - FY Monthly Comparison

with main as 
(
    select
    date_trunc('month', matter_date) as fymonth,
    to_char(matter_date, 'YYYY-MM') as month_text,
    extract(month from matter_date) as calendar_month,
    case 
        when extract(month from matter_date) > 6 and extract(month from matter_date) < 10 then 1 --Q1 July, August, September
        when extract(month from matter_date) > 9 then 2 --Q2 October, November, December
        when extract(month from matter_date) < 4 then 3 --Q3 January, February, March
        when extract(month from matter_date) > 3 and extract (month from matter_date) < 7 then 4 --Q4 April, May, June 
        END as fyquarter,
    case 
        when extract(month from matter_date) > 6 then concat((extract(year from matter_date)),'-',(extract(year from matter_date) + 1)) 
        when extract(month from matter_date) < 7 then concat((extract(year from matter_date) - 1),'-',(extract(year from matter_date))) 
        END as fyyear,
    -- Create financial year month order (July=1, August=2, ... June=12)
    case 
        when extract(month from matter_date) = 7 then 1
        when extract(month from matter_date) = 8 then 2
        when extract(month from matter_date) = 9 then 3
        when extract(month from matter_date) = 10 then 4
        when extract(month from matter_date) = 11 then 5
        when extract(month from matter_date) = 12 then 6
        when extract(month from matter_date) = 1 then 7
        when extract(month from matter_date) = 2 then 8
        when extract(month from matter_date) = 3 then 9
        when extract(month from matter_date) = 4 then 10
        when extract(month from matter_date) = 5 then 11
        when extract(month from matter_date) = 6 then 12
        END as fy_month_order,
    count(*) as new_leads  -- Count all offerings associated with leads (all statuses)
    from {{#635-firm-files-id-offering-id}} as new_leads
    -- Removed status filter to include all leads (all statuses: 1-6, excluding only deleted=7)
    where status_id != 7  -- Exclude deleted matters only
    group by 1, 2, 3, 4, 5, 6
    having date_trunc('month', matter_date) > timestamp '2019-06-30 00:00:00.000'
)

select
case calendar_month
    when 7 then 'Jul'
    when 8 then 'Aug' 
    when 9 then 'Sep'
    when 10 then 'Oct'
    when 11 then 'Nov'
    when 12 then 'Dec'
    when 1 then 'Jan'
    when 2 then 'Feb'
    when 3 then 'Mar'
    when 4 then 'Apr'
    when 5 then 'May'
    when 6 then 'Jun'
END as fy_month,
fyyear,
sum(new_leads) as total_new_leads  -- Changed to total_new_leads
from main
where 1=1
[[and month_text = {{month}}]]
[[and fyquarter = {{fyquarter}}::int]]
[[and fyyear = {{fyyear}}]]
group by calendar_month, fyyear, fy_month_order
order by fy_month_order, fyyear