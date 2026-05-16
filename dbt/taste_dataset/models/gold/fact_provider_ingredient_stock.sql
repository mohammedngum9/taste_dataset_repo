/*
This SQL script creates a fact table `fact_provider_ingredient_stock` that combines data from the `silver_ingredients` table 
and the `dim_ingredient` and `dim_provider` dimension tables to provide detailed information about ingredient stock for providers.

CTEs:
- `b`: Selects all columns from the `silver_ingredients` table.

Columns:
- `provider_ingredient_stock_sk`: A surrogate key generated using a combination of `ingredient_id`, `provider_id`, and `batch_number`.
- `batch_number`: The batch number of the ingredient stock.
- `ingredient_sk`: The surrogate key for the ingredient, retrieved from the `dim_ingredient` table.
- `provider_sk`: The surrogate key for the provider, retrieved from the `dim_provider` table.
- `provider_country_sk`: The surrogate key for the provider's country, retrieved from the `dim_provider` table.
- `weight_in_grams`: The weight of the ingredient stock in grams.
- `cost_per_gram`: The cost per gram of the ingredient stock.
- `stock_value_dollars`: The total value of the stock in dollars, calculated as `weight_in_grams * cost_per_gram`.
- `generation_date`: The date when the stock data was generated.

Joins:
- Left join with `dim_ingredient` on `ingredient_id` and `batch_number` to retrieve ingredient details.
- Left join with `dim_provider` on `provider_id` and `batch_number` to retrieve provider details.
*/
with b as (
  select *
  from {{ ref('silver_ingredients') }}
)
select
  {{ surrogate_key(["b.ingredient_id", "b.provider_id", "b.batch_number"]) }} as provider_ingredient_stock_sk,

  b.batch_number,
  di.ingredient_sk,
  dp.provider_sk,

  dp.country_sk as provider_country_sk,

  b.weight_in_grams,
  b.cost_per_gram,
  (b.weight_in_grams * b.cost_per_gram) as stock_value_dollars,

  b.generation_date
from b
left join {{ ref('dim_ingredient') }} di
  on di.ingredient_id = b.ingredient_id
 and di.batch_number = b.batch_number
left join {{ ref('dim_provider') }} dp
  on dp.provider_id = b.provider_id
 and dp.batch_number = b.batch_number