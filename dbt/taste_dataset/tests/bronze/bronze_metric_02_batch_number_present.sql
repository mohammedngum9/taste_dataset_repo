with bad as (
  select 'customers' as table_name, count(*) as bad_rows
  from {{ source('bronze','customers') }} where batch_number is null
  union all select 'flavours', count(*) from {{ source('bronze','flavours') }} where batch_number is null
  union all select 'ingredients', count(*) from {{ source('bronze','ingredients') }} where batch_number is null
  union all select 'providers', count(*) from {{ source('bronze','providers') }} where batch_number is null
  union all select 'raw_materials', count(*) from {{ source('bronze','raw_materials') }} where batch_number is null
  union all select 'recipes', count(*) from {{ source('bronze','recipes') }} where batch_number is null
  union all select 'sales_transactions', count(*) from {{ source('bronze','sales_transactions') }} where batch_number is null
)
select *
from bad
where bad_rows > 0