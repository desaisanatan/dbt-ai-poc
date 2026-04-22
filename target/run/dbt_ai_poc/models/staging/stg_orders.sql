
  create or replace   view DB_DOMAIN.PUBLIC_staging.stg_orders
  
   as (
    with source as (
    select * from DB_DOMAIN.PUBLIC.raw_orders
),

renamed as (
    select
        id as order_id,
        user_id as customer_id,
        order_date,
        status
    from source
)

select * from renamed
  );

