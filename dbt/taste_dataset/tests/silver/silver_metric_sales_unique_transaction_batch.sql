select transaction_id, batch_number, count(*) as cnt
from {{ ref('silver_sales_transactions') }}
group by 1,2
having count(*) > 1