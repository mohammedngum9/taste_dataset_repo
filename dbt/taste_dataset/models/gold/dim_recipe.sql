/*
This SQL script processes recipe data to create a slowly changing dimension (SCD) table. 
The script is divided into several Common Table Expressions (CTEs) for clarity and modularity:

1. `ranked`:
  - Retrieves data from the `silver_recipes` table.
  - Cleans up the `heat_process` column by removing leading/trailing spaces and replacing empty strings with NULL.
  - Converts the `yield` column to a double data type and renames it as `yield_pct`.
  - Assigns a row number (`rn`) to each record within the same `recipe_id` and `batch_number`, ordered by the `_ingested_at_utc` timestamp in descending order.

2. `base`:
  - Filters the `ranked` CTE to include only the most recent record (`rn = 1`) for each combination of `recipe_id` and `batch_number`.

3. `scd`:
  - Generates a surrogate key (`recipe_sk`) for each record using the `recipe_id` and `batch_number` columns.
  - Adds a `valid_from_batch` column to indicate the starting batch for each record's validity.
  - Calculates the `next_batch` column using the `LEAD` window function to determine the subsequent batch for each `recipe_id`.

4. Final SELECT:
  - Computes the `valid_to_batch` column as one less than the `next_batch` value.
  - Adds an `is_current` column to indicate whether the record is the most current version (true if `next_batch` is NULL).
  - Outputs the final SCD table with all relevant columns.

This script is designed to maintain historical changes in recipe data while identifying the current version of each record.
*/
with ranked as (
  select
    recipe_id,
    batch_number,
    nullif(trim(heat_process), '') as heat_process,
    cast(yield as double) as yield_pct,
    generation_date,
    _ingested_at_utc,
    row_number() over (
      partition by recipe_id, batch_number
      order by _ingested_at_utc desc
    ) as rn
  from {{ ref('silver_recipes') }}
),
base as (
  select
    recipe_id,
    batch_number,
    heat_process,
    yield_pct,
    generation_date
  from ranked
  where rn = 1
),
scd as (
  select
    {{ surrogate_key(["recipe_id", "batch_number"]) }} as recipe_sk,
    recipe_id,
    batch_number,
    heat_process,
    yield_pct,
    generation_date,
    batch_number as valid_from_batch,
    lead(batch_number) over (partition by recipe_id order by batch_number) as next_batch
  from base
)
select
  recipe_sk,
  recipe_id,
  batch_number,
  heat_process,
  yield_pct,
  generation_date,
  valid_from_batch,
  (next_batch - 1) as valid_to_batch,
  (next_batch is null) as is_current
from scd