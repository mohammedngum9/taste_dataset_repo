select *
from {{ ref('silver_recipes') }}
where raw_material_ratio < 0 or raw_material_ratio > 1
   or flavour_ratio < 0 or flavour_ratio > 1
   or ingredient_ratio < 0 or ingredient_ratio > 1