with ranked as (
  select
    raw_material_id,
    batch_number,
    raw_material_name,
    generation_date,
    _ingested_at_utc,
    row_number() over (
      partition by raw_material_id, batch_number
      order by _ingested_at_utc desc
    ) as rn
  from {{ ref('silver_raw_materials') }}
),
base as (
  select
    raw_material_id,
    batch_number,
    raw_material_name,
    generation_date
  from ranked
  where rn = 1
),
scd as (
  select
    {{ surrogate_key(["raw_material_id", "batch_number"]) }} as raw_material_sk,
    raw_material_id,
    batch_number,
    raw_material_name,
    generation_date,
    batch_number as valid_from_batch,
    lead(batch_number) over (partition by raw_material_id order by batch_number) as next_batch
  from base
)
select
  raw_material_sk,
  raw_material_id,
  batch_number,
  raw_material_name,
  generation_date,
  valid_from_batch,
  (next_batch - 1) as valid_to_batch,
  (next_batch is null) as is_current
from scd