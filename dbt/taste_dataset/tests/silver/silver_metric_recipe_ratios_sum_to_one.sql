select
  recipe_id,
  batch_number,
  (raw_material_ratio + flavour_ratio + ingredient_ratio) as ratio_sum
from {{ ref('silver_recipes') }}
where (raw_material_ratio + flavour_ratio + ingredient_ratio) < 0.999
   or (raw_material_ratio + flavour_ratio + ingredient_ratio) > 1.001