select recipe_id
from {{ ref('dim_recipe') }}
group by 1
having sum(case when is_current then 1 else 0 end) <> 1