select customer_id, batch_number, count(*) as cnt
from {{ ref('silver_customers') }}
group by 1,2
having count(*) > 1