select flavour_id, batch_number, count(*) as cnt
from {{ ref('silver_flavours') }}
group by 1,2
having count(*) > 1