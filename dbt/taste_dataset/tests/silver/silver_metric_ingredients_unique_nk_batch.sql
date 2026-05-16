select ingredient_id, batch_number, count(*) as cnt
from {{ ref('silver_ingredients') }}
group by 1,2
having count(*) > 1