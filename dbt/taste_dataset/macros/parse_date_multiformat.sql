{% macro parse_date_multiformat(date_expr) -%}
coalesce(
  try_strptime(cast({{ date_expr }} as varchar), '%Y-%m-%d')::date,
  try_strptime(cast({{ date_expr }} as varchar), '%d-%b-%y')::date,  -- 7-May-24
  try_strptime(cast({{ date_expr }} as varchar), '%m/%d/%y')::date,  -- 5/5/24
  try_strptime(cast({{ date_expr }} as varchar), '%d/%m/%Y')::date,  -- 08/05/2024
  try_strptime(cast({{ date_expr }} as varchar), '%m/%d/%Y')::date   -- 5/5/2024
)
{%- endmacro %}