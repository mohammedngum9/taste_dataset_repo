select raw_material_id
from {{ ref('dim_raw_material') }}
group by 1
having sum(case when is_current then 1 else 0 end) <> 1