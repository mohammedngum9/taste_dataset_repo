select transaction_id, batch_number, count(*) as cnt
from {{ ref('fact_sales_transactions') }}
group by 1,2
having count(*) > 1