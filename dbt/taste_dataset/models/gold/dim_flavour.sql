/*
This SQL script creates a Slowly Changing Dimension (SCD) table for flavours, ensuring that only the most recent records 
are retained and historical changes are tracked. The script is divided into the following steps:

1. ranked:
  - Selects data from the 'silver_flavours' table and assigns a row number (rn) to each record within each 
    flavour_id and batch_number group, ordered by the ingestion timestamp (_ingested_at_utc) in descending order.
  - This ensures that the most recent record for each flavour_id and batch_number is identified.

2. base:
  - Filters the ranked dataset to include only the most recent record (where rn = 1) for each flavour_id and batch_number.

3. scd:
  - Generates a surrogate key (flavour_sk) for each unique combination of flavour_id and batch_number.
  - Adds columns for tracking the validity of each record:
    - valid_from_batch: The batch number from which the record is valid.
    - next_batch: The batch number of the next record for the same flavour_id, ordered by batch_number.

4. Final Select:
  - Outputs the SCD table with the following columns:
    - flavour_sk: Surrogate key for the record.
    - flavour_id: Original flavour identifier.
    - batch_number: Batch number of the record.
    - flavour_name: Name of the flavour.
    - flavour_description: Description of the flavour.
    - generation_date: Date the flavour was generated.
    - valid_from_batch: Batch number from which the record is valid.
    - valid_to_batch: Batch number until which the record is valid (calculated as next_batch - 1).
    - is_current: Boolean flag indicating whether the record is the most current (true if next_batch is null).

This script ensures that the SCD table maintains historical data while marking the most recent record as current.
*/
with ranked as (
  select
    flavour_id,
    batch_number,
    flavour_name,
    flavour_description,
    generation_date,
    _ingested_at_utc,
    row_number() over (
      partition by flavour_id, batch_number
      order by _ingested_at_utc desc
    ) as rn
  from {{ ref('silver_flavours') }}
),
base as (
  select
    flavour_id,
    batch_number,
    flavour_name,
    flavour_description,
    generation_date
  from ranked
  where rn = 1
),
scd as (
  select
    {{ surrogate_key(["flavour_id", "batch_number"]) }} as flavour_sk,
    flavour_id,
    batch_number,
    flavour_name,
    flavour_description,
    generation_date,
    batch_number as valid_from_batch,
    lead(batch_number) over (partition by flavour_id order by batch_number) as next_batch
  from base
)
select
  flavour_sk,
  flavour_id,
  batch_number,
  flavour_name,
  flavour_description,
  generation_date,
  valid_from_batch,
  (next_batch - 1) as valid_to_batch,
  (next_batch is null) as is_current
from scd