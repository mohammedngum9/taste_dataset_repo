/*
This SQL script transforms and cleanses data from the 'bronze.sales_transactions' source table 
to create a 'silver' layer table for sales transactions. The transformations include:

- Casting columns to appropriate data types:
  - `transaction_id`, `customer_id`, `flavour_id`, and `batch_number` are cast to BIGINT.
  - `quantity_liters` and `amount_dollar` are cast to DOUBLE.
  - `transaction_date` and `generation_date` are cast to DATE.

- Cleaning string fields:
  - `transaction_country`, `transaction_town`, and `postal_code` are trimmed of whitespace 
    and nullified if empty.

- Retaining metadata columns:
  - `_source_file`, `_ingested_at_utc`, and `_load_id` are included for traceability.

This script is part of the dbt project and is located in the 'silver/silver_sales_transactions.sql' file.
It prepares the data for further analysis by ensuring data quality and consistency.
*/
select
  cast(transaction_id as bigint) as transaction_id,
  cast(customer_id as bigint) as customer_id,
  cast(flavour_id as bigint) as flavour_id,
  cast(quantity_liters as double) as quantity_liters,
  cast(amount_dollar as double) as amount_dollars,
  cast(transaction_date as date) as transaction_date,
  nullif(trim(transaction_country), '') as transaction_country,
  nullif(trim(transaction_town), '') as transaction_town,
  nullif(trim(postal_code), '') as postal_code,
  cast(generation_date as date) as generation_date,
  cast(batch_number as bigint) as batch_number,
  _source_file,
  _ingested_at_utc,
  _load_id
from {{ source('bronze', 'sales_transactions') }}
