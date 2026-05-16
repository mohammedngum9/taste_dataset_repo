/*
This SQL script transforms and cleanses raw material data from the 'bronze.raw_materials' source table 
and prepares it for further processing in the 'silver' layer. The transformations include:

- Casting 'raw_material_id' to a BIGINT data type for consistency.
- Cleaning the 'name' field by trimming whitespace and replacing empty strings with NULL values.
- Casting 'generation_date' to a DATE data type for proper date handling.
- Casting 'batch_number' to a BIGINT data type for uniformity.
- Retaining metadata fields '_source_file', '_ingested_at_utc', and '_load_id' for traceability.

This model is part of the 'silver' layer in the dbt project, which represents a cleaned and structured 
version of the raw data for analytical purposes.
*/
select
  cast(raw_material_id as bigint) as raw_material_id,
  nullif(trim(name), '') as raw_material_name,
  cast(generation_date as date) as generation_date,
  cast(batch_number as bigint) as batch_number,
  _source_file,
  _ingested_at_utc,
  _load_id
from {{ source('bronze', 'raw_materials') }}
