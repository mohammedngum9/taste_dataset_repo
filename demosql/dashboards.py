

"""
This script provides a set of queries to analyze data from a DuckDB database. It includes functionalities
to retrieve and display information about providers, recipes, components, sales, and countries.

The script connects to a DuckDB database and executes various SQL queries based on the provided arguments.

Functions:
  - main: The entry point of the script. Parses command-line arguments, connects to the database, and
    executes a series of predefined queries.

Command-line Arguments:
  --db: Path to the DuckDB database file. Default is "duckdb/taste_warehouse.duckdb".
  --recipe-id: The ID of the recipe to analyze. Default is "PHMV".
  --batch-number: The batch number to analyze. Default is 1.
  --impact-component-type: The type of component to analyze for impact. Default is "raw_material".
  --impact-component-id: The ID of the component to analyze for impact. Default is 78.
  --flavour-id: The ID of the flavour to analyze. Default is 21.

Queries Executed:
  1. Providers: Ingredients per provider.
  2. Providers: Total stock value per provider.
  3. Recipe constituents for a specific recipe and batch.
  4. Component importance across the recipe list (top 50).
  5. Impact analysis if a specific component is lost.
  6. Sales: Top customers by USD (top 20).
  7. Sales: Top flavours by USD and transactions (top 20).
  8. Creative: Flavour description history for a specific flavour.
  9. Creative: Flavours with changed descriptions.
  10. Country: Top countries by sales USD.
  11. Country: Customers vs providers coverage.

Dependencies:
  - argparse: For parsing command-line arguments.
  - duckdb: For connecting to and querying the DuckDB database.

Usage:
  Run the script from the command line with optional arguments to customize the queries.
  Example:
    python dashboards.py --db path/to/database.duckdb --recipe-id RECIPE_ID --batch-number BATCH_NUMBER
"""

import argparse
import duckdb


def main() -> None:
    p = argparse.ArgumentParser(description="Run stakeholder/dashboard queries")
    p.add_argument("--db", default="duckdb/taste_warehouse.duckdb")
    p.add_argument("--recipe-id", default="PHMV")
    p.add_argument("--batch-number", type=int, default=1)
    p.add_argument("--impact-component-type", default="raw_material")
    p.add_argument("--impact-component-id", type=int, default=78)
    p.add_argument("--flavour-id", type=int, default=21)
    args = p.parse_args()

    con = duckdb.connect(args.db)

    print("=== Providers: ingredients per provider ===")
    print(
        con.execute(
            """
            select
              dp.provider_name,
              di.ingredient_name,
              fis.batch_number,
              fis.weight_in_grams,
              fis.cost_per_gram,
              fis.stock_value_dollars
            from main_gold.fact_provider_ingredient_stock fis
            join main_gold.dim_provider dp
              on dp.provider_sk = fis.provider_sk
            join main_gold.dim_ingredient di
              on di.ingredient_sk = fis.ingredient_sk
            order by dp.provider_name, di.ingredient_name, fis.batch_number
            """
        ).df()
    )

    print("\n=== Providers: total stock value per provider ===")
    print(
        con.execute(
            """
            select
              dp.provider_name,
              fis.batch_number,
              sum(fis.stock_value_dollars) as total_stock_value_dollars
            from main_gold.fact_provider_ingredient_stock fis
            join main_gold.dim_provider dp
              on dp.provider_sk = fis.provider_sk
            group by 1,2
            order by total_stock_value_dollars desc
            """
        ).df()
    )

    print(f"\n=== Recipe constituents: {args.recipe_id} batch {args.batch_number} ===")
    print(
        con.execute(
            """
            select
              dr.recipe_id,
              frc.batch_number,
              frc.component_type,
              frc.component_id,
              case
                when frc.component_type = 'raw_material' then drm.raw_material_name
                when frc.component_type = 'flavour' then dfl.flavour_name
                when frc.component_type = 'ingredient' then ding.ingredient_name
              end as component_name,
              frc.component_ratio
            from main_gold.fact_recipe_components frc
            join main_gold.dim_recipe dr
              on dr.recipe_sk = frc.recipe_sk
            left join main_gold.dim_raw_material drm
              on frc.component_type = 'raw_material'
             and drm.raw_material_sk = frc.component_sk
            left join main_gold.dim_flavour dfl
              on frc.component_type = 'flavour'
             and dfl.flavour_sk = frc.component_sk
            left join main_gold.dim_ingredient ding
              on frc.component_type = 'ingredient'
             and ding.ingredient_sk = frc.component_sk
            where dr.recipe_id = ?
              and frc.batch_number = ?
            order by frc.component_type
            """,
            [args.recipe_id, args.batch_number],
        ).df()
    )

    print("\n=== Component importance across recipe list (top 50) ===")
    print(
        con.execute(
            """
            select
              frc.component_type,
              frc.component_id,
              case
                when frc.component_type = 'raw_material' then drm.raw_material_name
                when frc.component_type = 'flavour' then dfl.flavour_name
                when frc.component_type = 'ingredient' then ding.ingredient_name
              end as component_name,
              count(distinct frc.recipe_sk) as recipes_using_component,
              sum(frc.component_ratio) as total_ratio_contribution
            from main_gold.fact_recipe_components frc
            left join main_gold.dim_raw_material drm
              on frc.component_type = 'raw_material'
             and drm.raw_material_sk = frc.component_sk
            left join main_gold.dim_flavour dfl
              on frc.component_type = 'flavour'
             and dfl.flavour_sk = frc.component_sk
            left join main_gold.dim_ingredient ding
              on frc.component_type = 'ingredient'
             and ding.ingredient_sk = frc.component_sk
            group by 1,2,3
            order by total_ratio_contribution desc, recipes_using_component desc
            limit 50
            """
        ).df()
    )

    print(
        f"\n=== Impact if {args.impact_component_type} {args.impact_component_id} is lost (batch {args.batch_number}) ==="
    )
    print(
        con.execute(
            """
            select distinct
              dr.recipe_id
            from main_gold.fact_recipe_components frc
            join main_gold.dim_recipe dr
              on dr.recipe_sk = frc.recipe_sk
            where frc.batch_number = ?
              and frc.component_type = ?
              and frc.component_id = ?
            order by dr.recipe_id
            """,
            [args.batch_number, args.impact_component_type, args.impact_component_id],
        ).df()
    )

    print("\n=== Sales: top customers by USD (top 20) ===")
    print(
        con.execute(
            """
            select
              dc.customer_name,
              sum(fs.amount_dollars) as total_sales_usd
            from main_gold.fact_sales_transactions fs
            join main_gold.dim_customer dc
              on dc.customer_sk = fs.customer_sk
            group by 1
            order by total_sales_usd desc
            limit 20
            """
        ).df()
    )

    print("\n=== Sales: top flavours by USD and txns (top 20) ===")
    print(
        con.execute(
            """
            select
              df.flavour_name,
              sum(fs.amount_dollars) as total_sales_usd,
              count(*) as transaction_count
            from main_gold.fact_sales_transactions fs
            join main_gold.dim_flavour df
              on df.flavour_sk = fs.flavour_sk
            group by 1
            order by total_sales_usd desc, transaction_count desc
            limit 20
            """
        ).df()
    )

    print(f"\n=== Creative: flavour {args.flavour_id} description history ===")
    print(
        con.execute(
            """
            select
              flavour_id,
              batch_number,
              flavour_name,
              flavour_description,
              valid_from_batch,
              valid_to_batch,
              is_current
            from main_gold.dim_flavour
            where flavour_id = ?
            order by batch_number
            """,
            [args.flavour_id],
        ).df()
    )

    print("\n=== Creative: flavours with changed descriptions ===")
    print(
        con.execute(
            """
            with per_flavour as (
              select
                flavour_id,
                count(distinct flavour_description) as distinct_descriptions
              from main_gold.dim_flavour
              group by 1
            )
            select
              f.flavour_id,
              f.batch_number,
              f.flavour_name,
              f.flavour_description
            from per_flavour p
            join main_gold.dim_flavour f
              on f.flavour_id = p.flavour_id
            where p.distinct_descriptions > 1
            order by f.flavour_id, f.batch_number
            """
        ).df()
    )

    print("\n=== Country: top countries by sales USD ===")
    print(
        con.execute(
            """
            select
              c.country_name,
              sum(fs.amount_dollars) as total_sales_usd
            from main_gold.fact_sales_transactions fs
            join main_gold.dim_country c
              on c.country_sk = fs.transaction_country_sk
            group by 1
            order by total_sales_usd desc
            limit 20
            """
        ).df()
    )

    print("\n=== Country: customers vs providers coverage ===")
    print(
        con.execute(
            """
            select 'customers' as entity, c.country_name, count(*) as entity_rows
            from main_gold.dim_customer dc
            join main_gold.dim_country c on c.country_sk = dc.country_sk
            group by 1,2
            union all
            select 'providers' as entity, c.country_name, count(*) as entity_rows
            from main_gold.dim_provider dp
            join main_gold.dim_country c on c.country_sk = dp.country_sk
            group by 1,2
            order by entity, country_name
            """
        ).df()
    )

    con.close()


if __name__ == "__main__":
    main()