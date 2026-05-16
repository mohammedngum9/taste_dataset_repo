# Taste Dataset – Medallion + Dimensional Model (DuckDB + dbt)

This repository implements a medallion architecture (Bronze/Silver/Gold) in DuckDB with dbt models, tests, dashboard queries and data quality (DQ) measures.

Conventions:
- **SCD2 is based on `batch_number`**
- **`generation_date` is metadata** (date the dataset was generated)

---

## Pipeline
CSV files
    ↓
Python ingestion (append)
    ↓
DuckDB Bronze layer (schema: bronze)
    ↓
dbt Silver transformations (schema: main_silver)
    ↓
dbt Gold marts (schema: main_gold)
    ↓
dbt tests + DQ metric tables + drill-down queries


---

## Architecture

### Bronze layer
Raw append-only ingestion tables stored in DuckDB schema:
bronze


Characteristics:
- append-only
- source fidelity preserved
- ingestion metadata columns exist (e.g., `_load_id`, `_ingested_at_utc`, `_source_file`)

### Silver layer
Conformed and typed business entities stored in:
main_silver

Characteristics:
- consistent column naming and types
- multi-format date parsing handled
- checks for conformance and basic constraints

### Gold layer
Dimensional marts stored in:
main_gold

Characteristics:
- star-schema style dims + facts
- **surrogate keys**
- **SCD2 history** using `batch_number`
- stakeholder-ready facts and dimensions

---

## Prerequisites
- Python 3.9+
- CSVs exist under:
  - macOS/Linux: `data/*.csv`
  - Windows: `data\*.csv`
- dbt uses a repo-local profile:
  - `dbt/taste_dataset/.profiles/profiles.yml`

Optional:
- `make` (macOS/Linux/WSL convenience only)

---

## Setup

### macOS / Linux / WSL
From repository root:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
pip install -r 

requirements.txt


```

### Windows (PowerShell)
From repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -U pip
pip install -r 

requirements.txt


```

---

## Build the warehouse (clean DB -> ingest -> silver -> gold)

### 1) Clean DuckDB file (optional)
macOS/Linux/WSL:
```bash
rm -f 

taste_warehouse.duckdb


```

Windows PowerShell:
```powershell
Remove-Item -Force duckdb\taste_warehouse.duckdb -ErrorAction SilentlyContinue
```

### 2) Ingest CSVs to Bronze
macOS/Linux/WSL:
```bash
source .venv/bin/activate
python 

ingest_bronze.py

 --db 

taste_warehouse.duckdb

 --input-glob "data/*.csv"
```

Windows PowerShell:
```powershell
.\.venv\Scripts\Activate.ps1
python pipelines\ingest_bronze.py --db duckdb\taste_warehouse.duckdb --input-glob "data\*.csv"
```

### 3) Build Silver + Gold with dbt
From `dbt/taste_dataset`:

```bash
source .venv/bin/activate
cd dbt/taste_dataset
dbt debug --profiles-dir .profiles
dbt run   --profiles-dir .profiles --select path:models/silver
dbt run   --profiles-dir .profiles --select path:models/gold
```

---

## Run Data Quality Tests (dbt)

From `dbt/taste_dataset`:

### Bronze tests
```bash
dbt test --profiles-dir .profiles --select source:bronze
dbt test --profiles-dir .profiles --select path:tests/bronze
```

### Silver tests
```bash
dbt test --profiles-dir .profiles --select path:models/silver
dbt test --profiles-dir .profiles --select path:tests/silver
```

### Gold tests
```bash
dbt test --profiles-dir .profiles --select path:models/gold
dbt test --profiles-dir .profiles --select path:tests/gold
```

### All tests
```bash
dbt test --profiles-dir .profiles
```

---

## Makefile (macOS/Linux/WSL convenience)

From repository root:

```bash
make venv
make install

make all
make all -k ##to continue on test failure
```

Other useful targets:
```bash
make clean-db
make ingest
make silver
make gold
make test
make quality_metrics
make dashboards
```

---

## Query DuckDB from the command line (manual)

Quick connectivity check:
```bash
source .venv/bin/activate
python - <<'PY'
import duckdb
con = duckdb.connect("duckdb/taste_warehouse.duckdb")
print(con.execute("select 1 as ok;").df())
con.close()
PY
```

List schemas/tables:
```bash
source .venv/bin/activate
python - <<'PY'
import duckdb
con = duckdb.connect("duckdb/taste_warehouse.duckdb")
print(con.execute("show schemas").df())
print(con.execute("show tables from bronze").df())
print(con.execute("show tables from main_silver").df())
print(con.execute("show tables from main_gold").df())
con.close()
PY
```

---

## Data Quality Measures (current measures + drill-downs)

### Summary measures (Silver + Gold) + drill-downs (failures diagnostics)
Using Makefile:
```bash
make quality_metrics
```

Manual:
```bash
source .venv/bin/activate
python demosql/quality_metrics.py --db 

taste_warehouse.duckdb


```

---

## Dashboard / stakeholder queries

Using Makefile:
```bash
make dashboards
```

Manual:
```bash
source .venv/bin/activate
python demosql/dashboards.py --db 

taste_warehouse.duckdb


```

---

## Stakeholder questions (example queries)

If you want to run individual queries without the dashboards script, use the pattern below:

```bash
source .venv/bin/activate
python - <<'PY'
import duckdb
con = duckdb.connect("duckdb/taste_warehouse.duckdb")

print(con.execute("""
select
  dp.provider_name,
  fis.batch_number,
  sum(fis.stock_value_dollars) as total_stock_value_dollars
from main_gold.fact_provider_ingredient_stock fis
join main_gold.dim_provider dp
  on dp.provider_sk = fis.provider_sk
group by 1,2
order by total_stock_value_dollars desc
""").df())

con.close()
PY
```

---

## Technology stack
- Python
- DuckDB
- dbt
- SQL
- VSCode GitHub Co-pilot
---

## Analytics design patterns
Implemented patterns include:
- Bronze / Silver / Gold layering
- Append-only ingestion
- SCD2 dimensions
- Fact tables
- Data quality testing + measurable DQ metrics
```