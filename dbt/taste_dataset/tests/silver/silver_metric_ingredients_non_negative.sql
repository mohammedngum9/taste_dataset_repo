select *
from {{ ref('silver_ingredients') }}
where weight_in_grams < 0 or cost_per_gram < 0