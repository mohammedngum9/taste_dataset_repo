/*
This SQL script transforms and cleanses data from the 'bronze.customers' source table 
to create a 'silver_customers' table in the silver layer of the data warehouse. 

Columns:
- customer_id: Converts the customer_id field to a BIGINT data type.
- customer_name: Trims whitespace and replaces empty strings with NULL for the name field.
- location_city: Trims whitespace and replaces empty strings with NULL for the location_city field.
- location_country: Trims whitespace and replaces empty strings with NULL for the location_country field.
- generation_date: Casts the generation_date field to a DATE data type.
- batch_number: Converts the batch_number field to a BIGINT data type.
- _source_file: Captures the source file name from which the data was ingested.
- _ingested_at_utc: Records the UTC timestamp of when the data was ingested.
- _load_id: Represents the unique identifier for the data load.

The script ensures data quality by handling null values and type casting, preparing the data for downstream analysis.
*/
select
  cast(customer_id as bigint) as customer_id,
  nullif(trim(name), '') as customer_name,
  nullif(trim(location_city), '') as location_city,
  nullif(trim(location_country), '') as location_country,
  cast(generation_date as date) as generation_date,
  cast(batch_number as bigint) as batch_number,
  _source_file,
  _ingested_at_utc,
  _load_id
from {{ source('bronze', 'customers') }}
