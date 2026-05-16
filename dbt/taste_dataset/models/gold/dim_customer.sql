/*
This SQL script creates a dimensional model for the `dim_customer` table in the gold layer of the data warehouse. 
The script processes customer data from the `silver_customers` table and enriches it with country information from the `dim_country` table. 
It also implements Slowly Changing Dimension (SCD) Type 2 logic to track changes in customer data over time.

Steps:
1. `ranked` CTE:
  - Retrieves customer data from the `silver_customers` table.
  - Assigns a row number (`rn`) to each record within each `customer_id` and `batch_number` group, ordered by `_ingested_at_utc` in descending order.
  - Ensures only the most recent record for each group is selected.

2. `base` CTE:
  - Filters the most recent record for each `customer_id` and `batch_number` group (where `rn = 1`).
  - Cleans and standardizes the `location_country` field by trimming whitespace and converting it to uppercase.

3. `joined` CTE:
  - Joins the `base` data with the `dim_country` table to enrich customer data with the corresponding `country_sk` (surrogate key for the country).

4. `scd` CTE:
  - Implements SCD Type 2 logic by generating a surrogate key (`customer_sk`) for each unique combination of `customer_id` and `batch_number`.
  - Adds `valid_from_batch` and `next_batch` columns to define the validity period of each record.
  - Uses the `lead` window function to determine the `next_batch` for each customer, ordered by `batch_number`.

5. Final SELECT:
  - Outputs the final `dim_customer` table with the following columns:
    - `customer_sk`: Surrogate key for the customer.
    - `customer_id`, `batch_number`, `customer_name`, `location_city`, `country_sk`, `generation_date`: Customer attributes.
    - `valid_from_batch`: The batch number when the record became valid.
    - `valid_to_batch`: The batch number when the record became invalid (calculated as `next_batch - 1`).
    - `is_current`: A flag indicating whether the record is the most current version (true if `next_batch` is null).

Purpose:
- This script creates a historical view of customer data, enabling tracking of changes over time while maintaining referential integrity with the `dim_country` table.
*/
with ranked as (
  select
    customer_id,
    batch_number,
    customer_name,
    location_city,
    location_country,
    generation_date,
    _ingested_at_utc,
    row_number() over (
      partition by customer_id, batch_number
      order by _ingested_at_utc desc
    ) as rn
  from {{ ref('silver_customers') }}
),
base as (
  select
    customer_id,
    batch_number,
    customer_name,
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
    {{ surrogate_key(["customer_id", "batch_number"]) }} as customer_sk,
    customer_id,
    batch_number,
    customer_name,
    location_city,
    country_sk,
    generation_date,
    batch_number as valid_from_batch,
    lead(batch_number) over (partition by customer_id order by batch_number) as next_batch
  from joined
)
select
  customer_sk,
  customer_id,
  batch_number,
  customer_name,
  location_city,
  country_sk,
  generation_date,
  valid_from_batch,
  (next_batch - 1) as valid_to_batch,
  (next_batch is null) as is_current
from scd