with sums as (
  select
    recipe_sk,
    batch_number,
    sum(component_ratio) as ratio_sum
  from {{ ref('fact_recipe_components') }}
  group by 1,2
)
select *
from sums
where ratio_sum < 0.999 or ratio_sum > 1.001