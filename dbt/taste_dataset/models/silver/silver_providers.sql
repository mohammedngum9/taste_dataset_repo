/*
This SQL script transforms and cleanses data from the 'bronze.providers' source table 
to create a 'silver_providers' table with the following transformations:

- `provider_id`: Casts the provider ID to a BIGINT data type.
- `provider_name`: Trims whitespace from the 'name' column and replaces empty strings with NULL.
- `location_city`: Trims whitespace from the 'location_city' column and replaces empty strings with NULL.
- `location_country`: Trims whitespace from the 'location_country' column and replaces empty strings with NULL.
- `generation_date`: Casts the 'generation_date' column to a DATE data type.
- `batch_number`: Casts the 'batch_number' column to a BIGINT data type.
- `_source_file`: Retains the source file information for traceability.
- `_ingested_at_utc`: Retains the ingestion timestamp in UTC for auditing purposes.
- `_load_id`: Retains the load identifier for tracking data loads.

The script ensures data quality by handling null values and standardizing data types.
*/
select
  cast(provider_id as bigint) as provider_id,
  nullif(trim(name), '') as provider_name,
  nullif(trim(location_city), '') as location_city,
  nullif(trim(location_country), '') as location_country,
  cast(generation_date as date) as generation_date,
  cast(batch_number as bigint) as batch_number,
  _source_file,
  _ingested_at_utc,
  _load_id
from {{ source('bronze', 'providers') }}
