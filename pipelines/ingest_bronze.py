
""" This script ingests CSV files into a DuckDB database, organizing them into bronze tables.
It ensures the necessary schemas and ingestion log table exist, and appends data from the
CSV files into the appropriate tables. The ingestion process is logged in the `_ingestion_log` table.

Functions:
- sanitize_identifier(filename: str) -> str:
    Sanitizes a filename to create a valid DuckDB table name.

- ensure_schemas(con: duckdb.DuckDBPyConnection) -> None:
    Ensures the `bronze`, `silver`, and `gold` schemas exist in the database.

- ensure_ingestion_log(con: duckdb.DuckDBPyConnection) -> None:
    Ensures the `_ingestion_log` table exists in the `bronze` schema.

- table_exists(con: duckdb.DuckDBPyConnection, schema: str, table: str) -> bool:
    Checks if a table exists in the specified schema.

- main() -> None:
    The main function that orchestrates the ingestion process:
    - Parses command-line arguments for the database path and input file glob pattern.
    - Ensures the database and required schemas/tables exist.
    - Iterates over matching CSV files, loading their data into corresponding bronze tables.
    - Logs the ingestion details in the `_ingestion_log` table.

Usage:
Run the script with optional arguments:
- `--db`: Path to the DuckDB database file (default: "duckdb/taste_warehouse.duckdb").
- `--input-glob`: Glob pattern to match input CSV files (default: "data/*.csv").

Raises:
- SystemExit: If no files match the provided glob pattern. """


import argparse
import glob
import os
import re
import uuid
from datetime import datetime, timezone

import duckdb


def sanitize_identifier(filename: str) -> str:
    name = filename.strip().lower()
    name = re.sub(r"\.csv$", "", name)
    name = re.sub(r"[^a-z0-9]+", "_", name)
    name = re.sub(r"_+", "_", name).strip("_")
    if not name:
        raise ValueError(f"Bad filename for table name: {filename}")
    if name[0].isdigit():
        name = f"t_{name}"
    return name


def ensure_schemas(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("create schema if not exists bronze;")
    con.execute("create schema if not exists silver;")
    con.execute("create schema if not exists gold;")


def ensure_ingestion_log(con: duckdb.DuckDBPyConnection) -> None:
    con.execute(
        """
        create table if not exists bronze._ingestion_log (
            load_id varchar,
            ingested_at_utc timestamp,
            source_file varchar,
            target_table varchar,
            rows_loaded bigint
        );
        """
    )


def table_exists(con: duckdb.DuckDBPyConnection, schema: str, table: str) -> bool:
    return con.execute(
        """
        select count(*) > 0
        from information_schema.tables
        where table_schema = ? and table_name = ?
        """,
        [schema, table],
    ).fetchone()[0]


def main() -> None:
    p = argparse.ArgumentParser(description="Append CSVs into DuckDB bronze tables")
    p.add_argument("--db", default="duckdb/taste_warehouse.duckdb")
    p.add_argument("--input-glob", default="data/*.csv")
    args = p.parse_args()

    os.makedirs(os.path.dirname(args.db), exist_ok=True)

    con = duckdb.connect(args.db)
    ensure_schemas(con)
    ensure_ingestion_log(con)

    paths = sorted(glob.glob(args.input_glob))
    if not paths:
        raise SystemExit(f"No files matched: {args.input_glob}")

    load_id = str(uuid.uuid4())
    ingested_at_utc = datetime.now(timezone.utc).replace(microsecond=0).isoformat()

    for path in paths:
        base = os.path.basename(path)
        table = sanitize_identifier(base)
        full_table = f"bronze.{table}"

        if not table_exists(con, "bronze", table):
            con.execute(
                f"""
                create table {full_table} as
                select
                    *,
                    '{base}' as _source_file,
                    '{ingested_at_utc}'::timestamp as _ingested_at_utc,
                    '{load_id}' as _load_id
                from read_csv_auto(?, header=true);
                """,
                [path],
            )
        else:
            con.execute(
                f"""
                insert into {full_table}
                select
                    *,
                    '{base}' as _source_file,
                    '{ingested_at_utc}'::timestamp as _ingested_at_utc,
                    '{load_id}' as _load_id
                from read_csv_auto(?, header=true);
                """,
                [path],
            )

        rows_loaded = con.execute(
            f"select count(*) from {full_table} where _load_id = ?",
            [load_id],
        ).fetchone()[0]

        con.execute(
            """
            insert into bronze._ingestion_log(load_id, ingested_at_utc, source_file, target_table, rows_loaded)
            values (?, ?::timestamp, ?, ?, ?);
            """,
            [load_id, ingested_at_utc, base, full_table, rows_loaded],
        )

        print(f"Loaded {rows_loaded} rows -> {full_table} (file={base})")

    con.close()
    print(f"Done. load_id={load_id}")


if __name__ == "__main__":
    main()