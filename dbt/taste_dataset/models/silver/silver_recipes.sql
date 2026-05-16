/*
This SQL script transforms and cleanses data from the 'bronze.recipes' source table 
to create a 'silver_recipes' table with standardized and properly typed columns.

Columns:
- recipe_id: Trims and nullifies empty strings for recipe identifiers.
- raw_material_id: Converts raw material identifiers to BIGINT.
- raw_material_ratio: Converts raw material ratios to DOUBLE.
- flavour_id: Converts flavour identifiers to BIGINT.
- flavour_ratio: Converts flavour ratios to DOUBLE.
- ingredient_id: Converts ingredient identifiers to BIGINT.
- ingredient_ratio: Converts ingredient ratios to DOUBLE.
- heat_process: Trims and nullifies empty strings for heat process descriptions.
- yield: Converts yield values to DOUBLE.
- generation_date: Converts generation dates to DATE.
- batch_number: Converts batch numbers to BIGINT.
- _source_file: Captures the source file name.
- _ingested_at_utc: Captures the UTC timestamp of ingestion.
- _load_id: Captures the load identifier.

Source:
- bronze.recipes: The source table containing raw data.

Purpose:
- This transformation ensures data consistency, proper typing, and readiness for downstream processing.
*/
select
  nullif(trim(recipe_id), '') as recipe_id,
  cast(raw_material_id as bigint) as raw_material_id,
  cast(raw_material_ratio as double) as raw_material_ratio,
  cast(flavour_id as bigint) as flavour_id,
  cast(flavour_ratio as double) as flavour_ratio,
  cast(ingredient_id as bigint) as ingredient_id,
  cast(ingredient_ratio as double) as ingredient_ratio,
  nullif(trim(heat_process), '') as heat_process,
  cast(yield as double) as yield,
  cast(generation_date as date) as generation_date,
  cast(batch_number as bigint) as batch_number,
  _source_file,
  _ingested_at_utc,
  _load_id
from {{ source('bronze', 'recipes') }}
