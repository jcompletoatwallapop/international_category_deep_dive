WITH new_buyers AS (
    SELECT
        user_id,
        first_listing,
        first_transaction_as_buyer_at,
        country_code
    FROM dwh.prod.users
    WHERE
        first_transaction_as_buyer_at BETWEEN '2023-01-01' AND '2023-12-31' -- alterar para ano inteiro de 2023
        AND (country_code = 'ES' OR country_code = 'IT')
        and first_transaction_as_buyer_at < first_listing
),
first_item_purchased AS (
    SELECT
        new_buyers.*,
        items.buyer_user_id,
        items.seller_user_id,
        items.category_id,
        items.category_name,
        items.item_id,
        items.sold_at,
        items.is_sold,
        ROW_NUMBER() OVER (PARTITION BY items.buyer_user_id ORDER BY items.sold_at) AS purchase_num
    FROM new_buyers
    LEFT JOIN dwh.prod.items AS items ON new_buyers.user_id = items.buyer_user_id
    WHERE is_sold IS True
    AND sold_at BETWEEN '2023-01-01' AND '2023-12-31'
), -- this CTE retrieves a table only with user_ids and the timestamp of their first_transaction_as_buyer
users_distinct AS (
    SELECT
        first_item_purchased.user_id,
        first_item_purchased.country_code AS country_code,
        CASE WHEN first_item_purchased.purchase_num = 1 THEN first_item_purchased.category_name END AS entry_category,
        CAST(COUNT(DISTINCT added_purchases.category_name) - 1 AS Decimal(18, 2)) AS distinct_added_categories_cnt, -- the '-1' removes the entry_category from the count distinct of other categories
        CAST(COUNT(DISTINCT added_purchases.item_id) - 1 AS Decimal(18, 2)) AS distinct_added_purchases_cnt
    FROM first_item_purchased
    LEFT JOIN dwh.prod.items AS added_purchases ON first_item_purchased.user_id = added_purchases.buyer_user_id
    WHERE added_purchases.sold_at BETWEEN '2023-01-01' AND '2023-12-31'
    AND added_purchases.is_sold IS True
    GROUP BY 1, 2, 3
    ORDER BY 1, 2
)

SELECT
    entry_category,
    country_code,
    AVG(distinct_added_categories_cnt) AS avg_count_add_cat,
    AVG(distinct_added_purchases_cnt) AS avg_count_add_purchases
FROM users_distinct
WHERE entry_category IS NOT NULL
GROUP BY 1, 2
ORDER BY 1




