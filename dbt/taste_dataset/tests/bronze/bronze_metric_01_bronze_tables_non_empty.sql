with checks as (
  select 'customers' as table_name, (select count(*) from {{ source('bronze','customers') }}) as row_count
  union all select 'flavours', (select count(*) from {{ source('bronze','flavours') }})
  union all select 'ingredients', (select count(*) from {{ source('bronze','ingredients') }})
  union all select 'providers', (select count(*) from {{ source('bronze','providers') }})
  union all select 'raw_materials', (select count(*) from {{ source('bronze','raw_materials') }})
  union all select 'recipes', (select count(*) from {{ source('bronze','recipes') }})
  union all select 'sales_transactions', (select count(*) from {{ source('bronze','sales_transactions') }})
)
select *
from checks
where row_count = 0