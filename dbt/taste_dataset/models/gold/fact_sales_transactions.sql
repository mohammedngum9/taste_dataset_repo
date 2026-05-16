/*
This SQL script creates a fact table `fact_sales_transactions` by combining data from multiple source tables. 
The script performs the following steps:

1. **Source Data Preparation (`b` CTE)**:
  - Selects all columns from the `silver_sales_transactions` table.

2. **Country Mapping (`country` CTE)**:
  - Extracts `transaction_id`, `batch_number`, and maps the `transaction_country` to its corresponding `country_sk` from the `dim_country` table.
  - The `transaction_country` is cleaned by applying `upper` and `trim` functions before joining.

3. **Final Fact Table Construction**:
  - Creates a surrogate key `sales_txn_sk` using the `transaction_id` and `batch_number`.
  - Selects and combines relevant columns from the `b` CTE and joins with the following dimension tables:
    - `dim_customer` to get `customer_sk` using `customer_id` and `batch_number`.
    - `dim_flavour` to get `flavour_sk` using `flavour_id` and `batch_number`.
    - `country` CTE to get `transaction_country_sk` using `transaction_id` and `batch_number`.
  - Includes additional transaction details such as `transaction_date`, `transaction_town`, `postal_code`, `quantity_liters`, `amount_dollars`, and `generation_date`.

4. **Output**:
  - The resulting table contains a comprehensive set of attributes for sales transactions, enriched with surrogate keys and dimension data for analysis.

Dependencies:
- `silver_sales_transactions`
- `dim_country`
- `dim_customer`
- `dim_flavour`

Note:
- The `surrogate_key` macro is used to generate a unique key for each sales transaction.
*/
with b as (
  select *
  from {{ ref('silver_sales_transactions') }}
),
country as (
  select
    transaction_id,
    batch_number,
    c.country_sk
  from (
    select
      transaction_id,
      batch_number,
      upper(trim(transaction_country)) as country_name
    from b
  ) x
  left join {{ ref('dim_country') }} c
    on c.country_name = x.country_name
)
select
  {{ surrogate_key(["b.transaction_id", "b.batch_number"]) }} as sales_txn_sk,
  b.transaction_id,
  b.batch_number,

  dc.customer_sk,
  df.flavour_sk,
  co.country_sk as transaction_country_sk,

  b.transaction_date,
  b.transaction_town,
  b.postal_code,

  b.quantity_liters,
  b.amount_dollars,

  b.generation_date
from b
left join {{ ref('dim_customer') }} dc
  on dc.customer_id = b.customer_id
 and dc.batch_number = b.batch_number
left join {{ ref('dim_flavour') }} df
  on df.flavour_id = b.flavour_id
 and df.batch_number = b.batch_number
left join country co
  on co.transaction_id = b.transaction_id
 and co.batch_number = b.batch_number