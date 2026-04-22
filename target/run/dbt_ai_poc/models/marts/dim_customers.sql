
  
    

        create or replace transient table DB_DOMAIN.PUBLIC_marts.dim_customers
         as
        (with customers as (
    select * from DB_DOMAIN.PUBLIC_staging.stg_customers
),

orders as (
    select * from DB_DOMAIN.PUBLIC_staging.stg_orders
),

customer_orders as (
    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        count(order_id) as number_of_orders
    from orders
    group by customer_id
),

final as (
    select
        c.customer_id,
        c.first_name,
        c.last_name,
        co.first_order_date,
        co.most_recent_order_date,
        coalesce(co.number_of_orders, 0) as number_of_orders
    from customers c
    left join customer_orders co
        on c.customer_id = co.customer_id
)

select * from final
        );
      
  