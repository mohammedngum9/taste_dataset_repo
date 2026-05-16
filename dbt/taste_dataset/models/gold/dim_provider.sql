/*
This SQL script creates a dimension table for providers with Slowly Changing Dimensions (SCD) Type 2 implementation. 
The script processes data in multiple steps:

1. `ranked` CTE:
  - Retrieves data from the `silver_providers` table.
  - Assigns a row number (`rn`) to each record within a partition of `provider_id` and `batch_number`, ordered by `_ingested_at_utc` in descending order.
  - Ensures only the most recent record for each `provider_id` and `batch_number` is selected.

2. `base` CTE:
  - Filters the `ranked` CTE to include only the most recent record (`rn = 1`).
  - Cleans and standardizes the `location_country` field by trimming and converting it to uppercase.

3. `joined` CTE:
  - Joins the `base` CTE with the `dim_country` table to fetch the `country_sk` (surrogate key) for each record based on the `country_name`.

4. `scd` CTE:
  - Generates a surrogate key (`provider_sk`) for each provider using the `surrogate_key` macro.
  - Adds SCD Type 2 fields such as `valid_from_batch` and `next_batch` to track the validity period of each record.
  - Uses the `lead` window function to determine the `next_batch` for each `provider_id`, ordered by `batch_number`.

5. Final SELECT:
  - Outputs the final dimension table with the following fields:
    - `provider_sk`: Surrogate key for the provider.
    - `provider_id`, `batch_number`, `provider_name`, `location_city`, `country_sk`, `generation_date`: Provider details.
    - `valid_from_batch`: The batch number from which the record is valid.
    - `valid_to_batch`: The batch number until which the record is valid (calculated as `next_batch - 1`).
    - `is_current`: A flag indicating whether the record is the most current version (true if `next_batch` is null).

This script ensures that the provider dimension table is up-to-date and maintains historical changes for analysis.
*/
with ranked as (
  select
    provider_id,
    batch_number,
    provider_name,
    location_city,
    location_country,
    generation_date,
    _ingested_at_utc,
    row_number() over (
      partition by provider_id, batch_number
      order by _ingested_at_utc desc
    ) as rn
  from {{ ref('silver_providers') }}
),
base as (
  select
    provider_id,
    batch_number,
    provider_name,
    location_city,
    upper(trim(location_country)) as country_name,
    generation_date
  from ranked
  where rn = 1
),
joined as (
  select
    b.*,
    c.country_sk
  from base b
  left join {{ ref('dim_country') }} c
    on c.country_name = b.country_name
),
scd as (
  select
    {{ surrogate_key(["provider_id", "batch_number"]) }} as provider_sk,
    provider_id,
    batch_number,
    provider_name,
    location_city,
    country_sk,
    generation_date,
    batch_number as valid_from_batch,
    lead(batch_number) over (partition by provider_id order by batch_number) as next_batch
  from joined
)
select
  provider_sk,
  provider_id,
  batch_number,
  provider_name,
  location_city,
  country_sk,
  generation_date,
  valid_from_batch,
  (next_batch - 1) as valid_to_batch,
  (next_batch is null) as is_current
from scd