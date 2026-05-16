select raw_material_id, batch_number, count(*) as cnt
from {{ ref('silver_raw_materials') }}
group by 1,2
having count(*) > 1