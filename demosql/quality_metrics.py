"""
This script connects to a DuckDB database and retrieves various data quality metrics 
and drill-down queries for analysis. It provides insights into the data quality of 
silver and gold tables, as well as specific measures of some key metrics.

Functions:
  main(): The entry point of the script. It parses command-line arguments, connects 
      to the DuckDB database, and executes a series of queries to print data 
      quality metrics and drill-down results.

Command-line Arguments:
  --db: Path to the DuckDB database file. Defaults to "duckdb/taste_warehouse.duckdb".

Queries:
  1. Silver metrics: Retrieves data quality metrics from the `main_silver.silver_data_quality_metrics` table.
  2. Gold metrics: Retrieves data quality metrics from the `main_gold.gold_data_quality_metrics` table.
  3. Drill-down: Recipes not exactly 3 components:
     - Identifies recipes with component rows or types not equal to 3.
  4. Drill-down: Recipe component ratio sum != 1:
     - Identifies recipes where the sum of component ratios deviates from 1.
  5. Drill-down: Country FK gaps (customers/providers):
     - Finds records in `dim_customer` and `dim_provider` tables with missing foreign keys for countries.
  6. Drill-down: Country FK gaps (sales sample):
     - Finds sales transactions with missing foreign keys for transaction countries.

Dependencies:
  - argparse: For parsing command-line arguments.
  - duckdb: For connecting to and querying the DuckDB database.

Usage:
  Run the script from the command line, optionally specifying the database file path:
    python metrics.py --db <path_to_duckdb_file>
"""

import argparse
import duckdb


def main() -> None:
    p = argparse.ArgumentParser(description="Print DQ metric tables + drill-down queries")
    p.add_argument("--db", default="duckdb/taste_warehouse.duckdb")
    args = p.parse_args()

    con = duckdb.connect(args.db)

    print("=== Silver metrics ===")
    print(
        con.execute(
            """
            select metric_name, numerator, denominator, pct
            from main_silver.silver_data_quality_metrics
            order by metric_name
            """
        ).df()
    )

    print("\n=== Gold metrics ===")
    print(
        con.execute(
            """
            select metric_name, numerator, denominator, pct
            from main_gold.gold_data_quality_metrics
            order by metric_name
            """
        ).df()
    )

    print("\n=== Drill-down: recipes not exactly 3 components (top 50) ===")
    print(
        con.execute(
            """
            with counts as (
              select
                dr.recipe_id,
                frc.batch_number,
                count(*) as component_rows,
                count(distinct frc.component_type) as component_types
              from main_gold.fact_recipe_components frc
              join main_gold.dim_recipe dr
                on dr.recipe_sk = frc.recipe_sk
              group by 1,2
            )
            select *
            from counts
            where component_rows <> 3 or component_types <> 3
            order by component_rows desc
            limit 50
            """
        ).df()
    )

    print("\n=== Drill-down: recipe component ratio sum != 1 (top 50) ===")
    print(
        con.execute(
            """
            with sums as (
              select
                dr.recipe_id,
                frc.batch_number,
                sum(frc.component_ratio) as ratio_sum
              from main_gold.fact_recipe_components frc
              join main_gold.dim_recipe dr
                on dr.recipe_sk = frc.recipe_sk
              group by 1,2
            )
            select *
            from sums
            where ratio_sum < 0.999 or ratio_sum > 1.001
            order by abs(ratio_sum - 1.0) desc
            limit 50
            """
        ).df()
    )

    print("\n=== Drill-down: country FK gaps (customers/providers) ===")
    print(
        con.execute(
            """
            select 'customer' as entity, customer_id as natural_id, batch_number
            from main_gold.dim_customer
            where country_sk is null
            union all
            select 'provider' as entity, provider_id as natural_id, batch_number
            from main_gold.dim_provider
            where country_sk is null
            order by entity, batch_number
            """
        ).df()
    )

    print("\n=== Drill-down: country FK gaps (sales sample) ===")
    print(
        con.execute(
            """
            select
              transaction_id,
              batch_number,
              transaction_date,
              transaction_town,
              postal_code
            from main_gold.fact_sales_transactions
            where transaction_country_sk is null
            limit 50
            """
        ).df()
    )

    con.close()


if __name__ == "__main__":
    main()