select provider_id, batch_number, count(*) as cnt
from {{ ref('silver_providers') }}
group by 1,2
having count(*) > 1