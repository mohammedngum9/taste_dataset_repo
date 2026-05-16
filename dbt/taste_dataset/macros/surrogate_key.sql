{% macro surrogate_key(cols) -%}
md5(
  {% for c in cols -%}
    coalesce(cast({{ c }} as varchar), '__dbt_null__')
    {%- if not loop.last %} || '|' || {% endif -%}
  {%- endfor -%}
)
{%- endmacro %}
