select *
from {{ ref('silver_sales_transactions') }}
where amount_dollars < 0 or quantity_liters < 0