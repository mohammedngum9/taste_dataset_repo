


/*
This SQL script creates a dimension table `dim_country` that consolidates and standardizes country names 
from multiple source tables. The process involves the following steps:

1. Extract distinct, trimmed, and uppercased country names from three source tables:
  - `silver_customers` (column: location_country)
  - `silver_providers` (column: location_country)
  - `silver_sales_transactions` (column: transaction_country)
  Only non-null and non-empty values are included.

2. Combine the results from the three source tables using a UNION operation to ensure unique country names.

3. Generate a surrogate key (`country_sk`) for each unique country name using the `surrogate_key` macro.

4. Output the final table with two columns:
  - `country_sk`: Surrogate key for the country.
  - `country_name`: Standardized country name in uppercase.

This table serves as a gold-layer dimension table for country data, enabling consistent referencing across the data model.
*/
with countries as (
    select distinct upper(trim(location_country)) as country_name
    from {{ ref('silver_customers') }}
    where location_country is not null and trim(location_country) <> ''

    union

    select distinct upper(trim(location_country)) as country_name
    from {{ ref('silver_providers') }}
    where location_country is not null and trim(location_country) <> ''

    union

    select distinct upper(trim(transaction_country)) as country_name
    from {{ ref('silver_sales_transactions') }}
    where transaction_country is not null and trim(transaction_country) <> ''
)
select
  {{ surrogate_key(["country_name"]) }} as country_sk,
  country_name
from countries