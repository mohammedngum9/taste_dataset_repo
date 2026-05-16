select ingredient_id
from {{ ref('dim_ingredient') }}
group by 1
having sum(case when is_current then 1 else 0 end) <> 1