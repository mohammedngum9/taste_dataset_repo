/*
This SQL script calculates various data quality metrics for the "silver" layer of a data warehouse. 
The metrics are designed to identify issues such as duplicate records, invalid ratios, and negative values 
across different datasets. The script is structured as follows:

1) **Customers duplicate NK+batch**:
  - Identifies duplicate `customer_id` and `batch_number` combinations in the `silver_customers` table.

2) **Flavours duplicate NK+batch**:
  - Identifies duplicate `flavour_id` and `batch_number` combinations in the `silver_flavours` table.

3) **Ingredients duplicate NK+batch**:
  - Identifies duplicate `ingredient_id` and `batch_number` combinations in the `silver_ingredients` table.

4) **Sales duplicates at silver (transaction_id+batch)**:
  - Identifies duplicate `transaction_id` and `batch_number` combinations in the `silver_sales_transactions` table.

5) **Recipe ratio bounds at silver**:
  - Checks if the `raw_material_ratio`, `flavour_ratio`, or `ingredient_ratio` in the `silver_recipes` table 
    are outside the valid range of 0 to 1.

6) **Recipe ratios sum to ~1 at silver (row-level expectation)**:
  - Validates that the sum of `raw_material_ratio`, `flavour_ratio`, and `ingredient_ratio` in the `silver_recipes` 
    table is approximately equal to 1 (within a tolerance of 0.001).

7) **Negative sales measures**:
  - Identifies rows in the `silver_sales_transactions` table where `amount_dollars` or `quantity_liters` 
    have negative values.

8) **Negative ingredient economics**:
  - Identifies rows in the `silver_ingredients` table where `weight_in_grams` or `cost_per_gram` 
    have negative values.

The script calculates the numerator (count of bad rows) and denominator (total rows) for each metric, 
and computes the percentage of bad rows relative to the total. The results are combined into a single 
output table with the following columns:
  - `metric_name`: Name of the data quality metric.
  - `numerator`: Count of rows that fail the metric.
  - `denominator`: Total count of rows considered for the metric.
  - `pct`: Percentage of rows that fail the metric.

### Actions to Take for Test Failures:
- **Duplicate Records**:
  - Investigate the source data for duplicate records and identify the root cause.
  - Apply deduplication logic or enforce unique constraints in the source or transformation layer.

- **Invalid Ratios**:
  - Review the calculation logic for ratios in the source or transformation layer.
  - Ensure that input data is correctly validated and cleaned before ratio calculations.

- **Negative Values**:
  - Check for data entry errors or incorrect transformations leading to negative values.
  - Implement validation rules to prevent negative values in the source system.

- **Recipe Ratios Not Summing to ~1**:
  - Verify the business logic for recipe ratios and ensure the input data adheres to the expected rules.
  - Adjust the transformation logic to handle rounding errors or missing values.

- **General Approach**:
  - Communicate with data owners or upstream teams to address data quality issues at the source.
  - Implement automated alerts to monitor and flag recurring issues.
  - Document the root cause and resolution steps for future reference.
*/
with
-- 1) Customers duplicate NK+batch
customers_dupes as (
  select count(*) as numerator
  from (
    select customer_id, batch_number
    from {{ ref('silver_customers') }}
    group by 1,2
    having count(*) > 1
  ) x
),
customers_total as (
  select count(*) as denominator
  from (
    select distinct customer_id, batch_number
    from {{ ref('silver_customers') }}
  ) x
),

-- 2) Flavours duplicate NK+batch
flavours_dupes as (
  select count(*) as numerator
  from (
    select flavour_id, batch_number
    from {{ ref('silver_flavours') }}
    group by 1,2
    having count(*) > 1
  ) x
),
flavours_total as (
  select count(*) as denominator
  from (
    select distinct flavour_id, batch_number
    from {{ ref('silver_flavours') }}
  ) x
),

-- 3) Ingredients duplicate NK+batch
ingredients_dupes as (
  select count(*) as numerator
  from (
    select ingredient_id, batch_number
    from {{ ref('silver_ingredients') }}
    group by 1,2
    having count(*) > 1
  ) x
),
ingredients_total as (
  select count(*) as denominator
  from (
    select distinct ingredient_id, batch_number
    from {{ ref('silver_ingredients') }}
  ) x
),

-- 4) Sales duplicates at silver (transaction_id+batch)
sales_dupes as (
  select count(*) as numerator
  from (
    select transaction_id, batch_number
    from {{ ref('silver_sales_transactions') }}
    group by 1,2
    having count(*) > 1
  ) x
),
sales_total as (
  select count(*) as denominator
  from (
    select distinct transaction_id, batch_number
    from {{ ref('silver_sales_transactions') }}
  ) x
),

-- 5) Recipe ratio bounds at silver
recipe_ratio_bounds_bad as (
  select count(*) as numerator
  from {{ ref('silver_recipes') }}
  where raw_material_ratio < 0 or raw_material_ratio > 1
     or flavour_ratio < 0 or flavour_ratio > 1
     or ingredient_ratio < 0 or ingredient_ratio > 1
),
recipes_total_rows as (
  select count(*) as denominator
  from {{ ref('silver_recipes') }}
),

-- 6) Recipe ratios sum to ~1 at silver (row-level expectation)
recipe_ratio_sum_bad as (
  select count(*) as numerator
  from {{ ref('silver_recipes') }}
  where (raw_material_ratio + flavour_ratio + ingredient_ratio) < 0.999
     or (raw_material_ratio + flavour_ratio + ingredient_ratio) > 1.001
),

-- 7) Negative sales measures
sales_negative as (
  select count(*) as numerator
  from {{ ref('silver_sales_transactions') }}
  where amount_dollars < 0 or quantity_liters < 0
),

-- 8) Negative ingredient economics
ingredients_negative as (
  select count(*) as numerator
  from {{ ref('silver_ingredients') }}
  where weight_in_grams < 0 or cost_per_gram < 0
)

select
  'silver.customers.duplicate_customer_id_batch' as metric_name,
  cd.numerator, ct.denominator,
  round(100.0 * cd.numerator / nullif(ct.denominator, 0), 6) as pct
from customers_dupes cd cross join customers_total ct

union all
select
  'silver.flavours.duplicate_flavour_id_batch' as metric_name,
  fd.numerator, ft.denominator,
  round(100.0 * fd.numerator / nullif(ft.denominator, 0), 6) as pct
from flavours_dupes fd cross join flavours_total ft

union all
select
  'silver.ingredients.duplicate_ingredient_id_batch' as metric_name,
  idu.numerator, it.denominator,
  round(100.0 * idu.numerator / nullif(it.denominator, 0), 6) as pct
from ingredients_dupes idu cross join ingredients_total it

union all
select
  'silver.sales.duplicate_transaction_id_batch' as metric_name,
  sd.numerator, st.denominator,
  round(100.0 * sd.numerator / nullif(st.denominator, 0), 6) as pct
from sales_dupes sd cross join sales_total st

union all
select
  'silver.recipes.ratio_out_of_bounds_rows' as metric_name,
  rrb.numerator, rtr.denominator,
  round(100.0 * rrb.numerator / nullif(rtr.denominator, 0), 6) as pct
from recipe_ratio_bounds_bad rrb cross join recipes_total_rows rtr

union all
select
  'silver.recipes.ratio_sum_not_one_rows' as metric_name,
  rrs.numerator, rtr.denominator,
  round(100.0 * rrs.numerator / nullif(rtr.denominator, 0), 6) as pct
from recipe_ratio_sum_bad rrs cross join recipes_total_rows rtr

union all
select
  'silver.sales.negative_amount_or_quantity_rows' as metric_name,
  sn.numerator, st.denominator,
  round(100.0 * sn.numerator / nullif(st.denominator, 0), 6) as pct
from sales_negative sn cross join (select count(*) as denominator from {{ ref('silver_sales_transactions') }}) st

union all
select
  'silver.ingredients.negative_weight_or_cost_rows' as metric_name,
  ine.numerator, it2.denominator,
  round(100.0 * ine.numerator / nullif(it2.denominator, 0), 6) as pct
from ingredients_negative ine cross join (select count(*) as denominator from {{ ref('silver_ingredients') }}) it2