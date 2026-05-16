/*
This SQL script transforms data from the 'bronze.flavours' source table into a 'silver' model.
The transformation includes:
- Casting 'flavour_id' to BIGINT for consistent data type usage.
- Cleaning up the 'name' and 'description' fields by trimming whitespace and replacing empty strings with NULL.
- Casting 'generation_date' to DATE and 'batch_number' to BIGINT for proper data type handling.
- Retaining metadata columns '_source_file', '_ingested_at_utc', and '_load_id' for traceability.

Columns:
- flavour_id: Unique identifier for the flavour, cast to BIGINT.
- flavour_name: Cleaned and trimmed name of the flavour, NULL if empty.
- flavour_description: Cleaned and trimmed description of the flavour, NULL if empty.
- generation_date: Date when the flavour was generated, cast to DATE.
- batch_number: Batch number associated with the flavour, cast to BIGINT.
- _source_file: File path of the source data.
- _ingested_at_utc: Timestamp of when the data was ingested, in UTC.
- _load_id: Unique identifier for the data load process.

Source:
- bronze.flavours: The raw data source table in the 'bronze' layer.
*/
select
  cast(flavour_id as bigint) as flavour_id,
  nullif(trim(name), '') as flavour_name,
  nullif(trim(description), '') as flavour_description,
  cast(generation_date as date) as generation_date,
  cast(batch_number as bigint) as batch_number,
  _source_file,
  _ingested_at_utc,
  _load_id
from {{ source('bronze', 'flavours') }}
