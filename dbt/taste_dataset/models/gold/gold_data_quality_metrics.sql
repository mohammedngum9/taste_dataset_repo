/*
This SQL script calculates data quality metrics for a dataset, focusing on three specific metrics:

1. **Duplicate Sales Transactions**:
  - Metric Name: `gold.sales.duplicate_transaction_id_batch`
  - Measures the percentage of duplicate `transaction_id` and `batch_number` combinations in the `fact_sales_transactions` table.
  - Numerator: Count of duplicate `transaction_id` and `batch_number` combinations.
  - Denominator: Total count of distinct `transaction_id` and `batch_number` combinations.

2. **Invalid Recipe Component Counts**:
  - Metric Name: `gold.recipes.not_exactly_3_components`
  - Measures the percentage of recipes that do not have exactly 3 components and 3 distinct component types in the `fact_recipe_components` table.
  - Numerator: Count of recipes with invalid component counts or types.
  - Denominator: Total count of distinct `recipe_sk` and `batch_number` combinations.

3. **Invalid Recipe Ratios**:
  - Metric Name: `gold.recipes.ratio_sum_not_one`
  - Measures the percentage of recipes where the sum of `component_ratio` values does not equal 1 (within a tolerance of ±0.001) in the `fact_recipe_components` table.
  - Numerator: Count of recipes with invalid ratio sums.
  - Denominator: Total count of distinct `recipe_sk` and `batch_number` combinations.

The script calculates these metrics and outputs the metric name, numerator, denominator, and percentage for each metric.

### Handling Test Failures:
- **Duplicate Sales Transactions**:
  - Investigate the source data for duplicate `transaction_id` and `batch_number` combinations.
  - Ensure proper deduplication logic is applied during data ingestion or transformation.

- **Invalid Recipe Component Counts**:
  - Verify the business rules for recipe components and ensure the source data adheres to these rules.
  - Check for missing or incorrect data in the `fact_recipe_components` table.

- **Invalid Recipe Ratios**:
  - Validate the calculation logic for `component_ratio` values.
  - Ensure that the sum of `component_ratio` values for each recipe is correctly calculated and falls within the acceptable tolerance range.
  - Address any data quality issues in the source data that may cause invalid ratios.
*/

with
-- Metric 1: sales duplicate transaction_id+batch_number
sales_dupes as (
  select
    count(*) as numerator
  from (
    select transaction_id, batch_number
    from {{ ref('fact_sales_transactions') }}
    group by 1,2
    having count(*) > 1
  ) x
),
sales_total as (
  select count(*) as denominator
  from (
    select distinct transaction_id, batch_number
    from {{ ref('fact_sales_transactions') }}
  ) x
),

-- Metric 2: recipes must have exactly 3 components (and 3 types)
recipe_bad_component_counts as (
  select
    count(*) as numerator
  from (
    select
      recipe_sk,
      batch_number
    from {{ ref('fact_recipe_components') }}
    group by 1,2
    having count(*) <> 3
       or count(distinct component_type) <> 3
  ) x
),
recipe_total as (
  select count(*) as denominator
  from (
    select distinct recipe_sk, batch_number
    from {{ ref('fact_recipe_components') }}
  ) x
),

-- Metric 3: recipe ratios sum to 1 (± tolerance)
recipe_bad_ratio_sum as (
  select
    count(*) as numerator
  from (
    select
      recipe_sk,
      batch_number,
      sum(component_ratio) as ratio_sum
    from {{ ref('fact_recipe_components') }}
    group by 1,2
    having ratio_sum < 0.999 or ratio_sum > 1.001
  ) x
)

select
  'gold.sales.duplicate_transaction_id_batch' as metric_name,
  sd.numerator as numerator,
  st.denominator as denominator,
  round(100.0 * sd.numerator / nullif(st.denominator, 0), 6) as pct
from sales_dupes sd cross join sales_total st

union all

select
  'gold.recipes.not_exactly_3_components' as metric_name,
  rbc.numerator as numerator,
  rt.denominator as denominator,
  round(100.0 * rbc.numerator / nullif(rt.denominator, 0), 6) as pct
from recipe_bad_component_counts rbc cross join recipe_total rt

union all

select
  'gold.recipes.ratio_sum_not_one' as metric_name,
  rbr.numerator as numerator,
  rt.denominator as denominator,
  round(100.0 * rbr.numerator / nullif(rt.denominator, 0), 6) as pct
from recipe_bad_ratio_sum rbr cross join recipe_total rt