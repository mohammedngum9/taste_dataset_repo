with bad_customers as (
  select 'customer' as entity, customer_sk as sk, batch_number
  from {{ ref('dim_customer') }}
  where country_sk is null
),
bad_providers as (
  select 'provider' as entity, provider_sk as sk, batch_number
  from {{ ref('dim_provider') }}
  where country_sk is null
),
bad_sales as (
  select 'sales' as entity, sales_txn_sk as sk, batch_number
  from {{ ref('fact_sales_transactions') }}
  where transaction_country_sk is null
)
select * from bad_customers
union all
select * from bad_providers
union all
select * from bad_sales