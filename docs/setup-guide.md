# dbt Project on Snowflake – Setup Guide

## Prerequisites

- Snowflake account with `ACCOUNTADMIN` role (or equivalent privileges)
- A GitHub repository (e.g., `https://github.com/<your-user>/<your-repo>`)
- A Snowflake warehouse (e.g., `COMPUTE_WH`)

---

## Step 1: Create Infrastructure Databases

```sql
-- Database for Git integration objects
CREATE DATABASE IF NOT EXISTS DBT_PROJECT_DB;
CREATE SCHEMA IF NOT EXISTS DBT_PROJECT_DB.INTEGRATIONS;

-- Target database where dbt will materialize models
CREATE DATABASE IF NOT EXISTS DB_DOMAIN;
```

## Step 2: Create API Integration for GitHub

```sql
CREATE OR REPLACE API INTEGRATION github_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/<your-user>')
  API_USER_AUTHENTICATION = (TYPE = SNOWFLAKE_GITHUB_APP)
  ENABLED = TRUE;
```

> **Note:** The `SNOWFLAKE_GITHUB_APP` type uses Snowflake's built-in GitHub App for OAuth authentication. This avoids the need to manage Personal Access Tokens.

## Step 3: Authorize the Snowflake GitHub App (via Workspace UI)

This is the critical step. The OAuth authorization **must** be done through the Snowsight Workspace UI — it cannot be completed via SQL alone.

1. Go to **Projects → Workspaces** in Snowsight
2. Click **"+ → From Git repository"**
3. Enter your GitHub repository URL
4. Select `GITHUB_API_INTEGRATION` as the API integration
5. Choose **OAuth2** authentication and click **Sign in**
6. You'll be redirected to GitHub — authorize the Snowflake GitHub App
7. Ensure **"Read and write access to code"** is granted
8. Under **Repository access**, confirm your repo is included
9. Click **Create** to create the workspace

> **Important:** If you create the Git repository via SQL (`CREATE GIT REPOSITORY`) instead of through the Workspace UI, you will only get read-only access. Push (write) operations require the UI-based OAuth flow.

## Step 4: Scaffold the dbt Project

Create the following files in the workspace:

### `profiles.yml`

```yaml
default:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your-account>
      user: <your-user>
      role: ACCOUNTADMIN
      database: DB_DOMAIN
      warehouse: COMPUTE_WH
      schema: PUBLIC
      threads: 4
```

> **Do NOT** include `password`, `authenticator`, or `env_var()` calls — authentication is handled by the Snowflake session.

### `dbt_project.yml`

```yaml
name: 'dbt_ai_poc'
version: '1.0.0'

profile: 'default'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]

clean-targets:
  - "target"
  - "dbt_packages"

models:
  dbt_ai_poc:
    staging:
      +materialized: view
      +schema: staging
    marts:
      +materialized: table
      +schema: marts
```

### `packages.yml`

```yaml
packages: []
```

> External packages (e.g., `dbt_utils`) cannot be fetched from `hub.getdbt.com` inside Snowflake Workspaces due to network restrictions. Leave this empty or use only packages available in your environment.

## Step 5: Create Models, Sources, and Seeds

### Project structure

```
├── dbt_project.yml
├── profiles.yml
├── packages.yml
├── models/
│   ├── staging/
│   │   ├── src_raw.yml          # Source definitions
│   │   ├── stg_staging.yml      # Model tests
│   │   ├── stg_customers.sql
│   │   └── stg_orders.sql
│   └── marts/
│       ├── marts.yml            # Model tests
│       └── dim_customers.sql
└── seeds/
    ├── raw_customers.csv
    └── raw_orders.csv
```

### Source definition (`models/staging/src_raw.yml`)

```yaml
version: 2

sources:
  - name: raw
    description: Raw sample data
    database: DB_DOMAIN
    schema: PUBLIC
    tables:
      - name: raw_customers
      - name: raw_orders
```

## Step 6: Build and Test

Run the following dbt commands in the workspace terminal:

```bash
# Build everything: seeds, models, and tests
dbt build
```

Expected output: `PASS=13 WARN=0 ERROR=0 SKIP=0 TOTAL=13`

This runs:
- **2 seeds** → loads CSV data into `DB_DOMAIN.PUBLIC`
- **2 staging views** → created in `DB_DOMAIN.PUBLIC_staging`
- **1 marts table** → created in `DB_DOMAIN.PUBLIC_marts`
- **8 data tests** → uniqueness, not_null, accepted_values

## Step 7: Commit and Push to GitHub

1. Go to the **Changes** tab in the Workspace
2. Stage your files
3. Write a commit message and click **Commit & Push**

Since the workspace was created through the UI with OAuth, push access is enabled.

---

## Key Lessons Learned

| Topic | Detail |
|-------|--------|
| **Integration type matters** | `EXTERNAL_API` integrations (created by Snowflake GitHub App) cannot be described or dropped via standard SQL commands. Use `SHOW API INTEGRATIONS` to inspect them. |
| **OAuth must go through the UI** | Creating a `GIT REPOSITORY` via SQL with `SNOWFLAKE_GITHUB_APP` auth does not complete the OAuth flow. Always create Git-connected workspaces through the Snowsight UI for push access. |
| **No external package downloads** | Snowflake Workspaces cannot reach `hub.getdbt.com`. Avoid external dbt packages or pre-bundle them. |
| **No `env_var()` in profiles** | dbt runs inside Snowflake, not locally. Environment variables are not available. |
| **Schema naming** | dbt appends custom schema names to the target schema (e.g., `PUBLIC` + `staging` = `PUBLIC_staging`). |
