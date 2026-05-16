/*
This SQL script creates a fact table `fact_recipe_components` that combines recipe components 
from different dimensions (raw materials, flavours, and ingredients) with their respective 
ratios and metadata. The script performs the following steps:

1. `r` CTE:
  - Extracts and casts relevant fields from the `silver_recipes` table, including recipe IDs, 
    batch numbers, generation dates, and component IDs/ratios for raw materials, flavours, 
    and ingredients.

2. `rd` CTE:
  - Maps recipe IDs and batch numbers to their corresponding surrogate keys (`recipe_sk`) 
    from the `dim_recipe` table.

3. `rows` CTE:
  - Combines data for raw materials, flavours, and ingredients into a unified structure:
    - Joins `r` and `rd` to map recipe IDs and batch numbers to `recipe_sk`.
    - Joins with the respective dimension tables (`dim_raw_material`, `dim_flavour`, 
     `dim_ingredient`) to retrieve surrogate keys (`component_sk`) for each component type.
    - Ensures that the most recent batch number (less than or equal to the recipe's batch number) 
     is used for each component.
    - Filters out null component IDs for each component type.
    - Adds a `component_type` column to distinguish between raw materials, flavours, and ingredients.

4. Final SELECT:
  - Generates a surrogate key (`recipe_component_sk`) for each row using the `surrogate_key` macro 
    based on `recipe_sk`, `component_type`, `component_sk`, and `batch_number`.
  - Selects relevant fields for the fact table, including `recipe_sk`, `batch_number`, 
    `component_type`, `component_id`, `component_sk`, `component_ratio`, and `generation_date`.

This fact table provides a unified view of recipe components and their associated metadata, 
enabling analysis of recipe compositions across raw materials, flavours, and ingredients.
*/
with r as (
  select
    recipe_id,
    batch_number,
    generation_date,

    cast(raw_material_id as bigint) as raw_material_id,
    cast(raw_material_ratio as double) as raw_material_ratio,

    cast(flavour_id as bigint) as flavour_id,
    cast(flavour_ratio as double) as flavour_ratio,

    cast(ingredient_id as bigint) as ingredient_id,
    cast(ingredient_ratio as double) as ingredient_ratio
  from {{ ref('silver_recipes') }}
),

rd as (
  select recipe_id, batch_number, recipe_sk
  from {{ ref('dim_recipe') }}
),

rows as (
  select
    rd.recipe_sk,
    r.batch_number,
    'raw_material' as component_type,
    r.raw_material_id as component_id,
    drm.raw_material_sk as component_sk,
    r.raw_material_ratio as component_ratio,
    r.generation_date
  from r
  join rd
    on rd.recipe_id = r.recipe_id
   and rd.batch_number = r.batch_number
  join {{ ref('dim_raw_material') }} drm
    on drm.raw_material_id = r.raw_material_id
   and drm.batch_number = (
     select max(batch_number)
     from {{ ref('dim_raw_material') }} drm2
     where drm2.raw_material_id = r.raw_material_id
       and drm2.batch_number <= r.batch_number
   )
  where r.raw_material_id is not null

  union all

  select
    rd.recipe_sk,
    r.batch_number,
    'flavour' as component_type,
    r.flavour_id as component_id,
    dfl.flavour_sk as component_sk,
    r.flavour_ratio as component_ratio,
    r.generation_date
  from r
  join rd
    on rd.recipe_id = r.recipe_id
   and rd.batch_number = r.batch_number
  join {{ ref('dim_flavour') }} dfl
    on dfl.flavour_id = r.flavour_id
   and dfl.batch_number = (
     select max(batch_number)
     from {{ ref('dim_flavour') }} dfl2
     where dfl2.flavour_id = r.flavour_id
       and dfl2.batch_number <= r.batch_number
   )
  where r.flavour_id is not null

  union all

  select
    rd.recipe_sk,
    r.batch_number,
    'ingredient' as component_type,
    r.ingredient_id as component_id,
    ding.ingredient_sk as component_sk,
    r.ingredient_ratio as component_ratio,
    r.generation_date
  from r
  join rd
    on rd.recipe_id = r.recipe_id
   and rd.batch_number = r.batch_number
  join {{ ref('dim_ingredient') }} ding
    on ding.ingredient_id = r.ingredient_id
   and ding.batch_number = (
     select max(batch_number)
     from {{ ref('dim_ingredient') }} ding2
     where ding2.ingredient_id = r.ingredient_id
       and ding2.batch_number <= r.batch_number
   )
  where r.ingredient_id is not null
)

select
  {{ surrogate_key(["recipe_sk", "component_type", "component_sk", "batch_number"]) }} as recipe_component_sk,
  recipe_sk,
  batch_number,
  component_type,
  component_id,
  component_sk,
  component_ratio,
  generation_date
from rows