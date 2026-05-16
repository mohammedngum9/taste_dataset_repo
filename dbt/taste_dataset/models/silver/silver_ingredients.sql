/*
This SQL script processes and transforms data from the 'bronze.ingredients' source table into a silver-tier table. 
The transformations and fields included are as follows:

- ingredient_id: Casts the ingredient ID to a BIGINT for consistency.
- ingredient_name: Trims whitespace and replaces empty strings with NULL for the ingredient name.
- chemical_formula: Trims whitespace and replaces empty strings with NULL for the chemical formula.
- weight_in_grams: Casts the weight of the ingredient to a DOUBLE for precision.
- cost_per_gram: Casts the cost per gram to a DOUBLE for precision.
- provider_id: Casts the provider ID to a BIGINT for consistency.
- generation_date: Parses the 'generation_date' field using a multi-format date parser.
- batch_number: Casts the batch number to a BIGINT for consistency.
- _source_file: Captures the source file from which the data was ingested.
- _ingested_at_utc: Captures the UTC timestamp of when the data was ingested.
- _load_id: Captures the unique identifier for the data load.

The script ensures data quality by handling null values and standardizing data types for downstream processing.
*/
select
  cast(ingredient_id as bigint) as ingredient_id,
  nullif(trim(name), '') as ingredient_name,
  nullif(trim(chemical_formula), '') as chemical_formula,
  cast(weight_in_grams as double) as weight_in_grams,
  cast(cost_per_gram as double) as cost_per_gram,
  cast(provider_id as bigint) as provider_id,

  {{ parse_date_multiformat('generation_date') }} as generation_date,

  cast(batch_number as bigint) as batch_number,
  _source_file,
  _ingested_at_utc,
  _load_id
from {{ source('bronze', 'ingredients') }}