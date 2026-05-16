select *
from {{ ref('silver_recipes') }}
where yield < 0 or yield > 100