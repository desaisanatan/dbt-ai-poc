
  create or replace   view DB_DOMAIN.PUBLIC_staging.stg_customers
  
   as (
    with source as (
    select * from DB_DOMAIN.PUBLIC.raw_customers
),

renamed as (
    select
        id as customer_id,
        first_name,
        last_name
    from source
)

select * from renamed
  );

