/*
This SQL script creates a Slowly Changing Dimension (SCD) table for ingredients, ensuring that the most recent data is used and historical changes are tracked.

1. `ranked` CTE:
  - Retrieves data from the `silver_ingredients` table.
  - Assigns a row number (`rn`) to each record, partitioned by `ingredient_id` and `batch_number`, and ordered by `_ingested_at_utc` in descending order.
  - Ensures the most recent record for each combination of `ingredient_id` and `batch_number` is identified.

2. `base` CTE:
  - Filters the `ranked` CTE to include only the most recent record for each `ingredient_id` and `batch_number` (where `rn = 1`).

3. `scd` CTE:
  - Generates a surrogate key (`ingredient_sk`) for each unique combination of `ingredient_id` and `batch_number`.
  - Includes all relevant columns from the `base` CTE.
  - Adds `valid_from_batch` to indicate the starting batch for the record's validity.
  - Calculates `next_batch` using the `LEAD` window function to determine the next batch for the same `ingredient_id`.

4. Final SELECT:
  - Outputs the SCD table with the following columns:
    - `ingredient_sk`: Surrogate key for the ingredient record.
    - `ingredient_id`, `batch_number`, `ingredient_name`, `chemical_formula`, `provider_id`, `weight_in_grams`, `cost_per_gram`, `generation_date`: Ingredient details.
    - `valid_from_batch`: The batch number from which the record is valid.
    - `valid_to_batch`: The batch number until which the record is valid (calculated as `next_batch - 1`).
    - `is_current`: A flag indicating whether the record is the most current (true if `next_batch` is null).

Purpose:
- This script is designed to maintain historical data for ingredients while ensuring that the most recent data is easily accessible.
- It supports tracking changes over time and enables querying for both current and historical records.
*/
with ranked as (
  select
    ingredient_id,
    batch_number,
    ingredient_name,
    chemical_formula,
    provider_id,
    weight_in_grams,
    cost_per_gram,
    generation_date,
    _ingested_at_utc,
    row_number() over (
      partition by ingredient_id, batch_number
      order by _ingested_at_utc desc
    ) as rn
  from {{ ref('silver_ingredients') }}
),
base as (
  select
    ingredient_id,
    batch_number,
    ingredient_name,
    chemical_formula,
    provider_id,
    weight_in_grams,
    cost_per_gram,
    generation_date
  from ranked
  where rn = 1
),
scd as (
  select
    {{ surrogate_key(["ingredient_id", "batch_number"]) }} as ingredient_sk,
    ingredient_id,
    batch_number,
    ingredient_name,
    chemical_formula,
    provider_id,
    weight_in_grams,
    cost_per_gram,
    generation_date,
    batch_number as valid_from_batch,
    lead(batch_number) over (partition by ingredient_id order by batch_number) as next_batch
  from base
)
select
  ingredient_sk,
  ingredient_id,
  batch_number,
  ingredient_name,
  chemical_formula,
  provider_id,
  weight_in_grams,
  cost_per_gram,
  generation_date,
  valid_from_batch,
  (next_batch - 1) as valid_to_batch,
  (next_batch is null) as is_current
from scd