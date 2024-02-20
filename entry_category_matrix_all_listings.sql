WITH new_listers AS (
    SELECT
        user_id,
        first_listing,
        first_transaction_as_buyer_at,
        country_code
    FROM dwh.prod.users
    WHERE
        first_listing BETWEEN '2023-01-01' AND '2023-12-31' -- alterar para ano inteiro de 2023
        AND (country_code = 'ES' OR country_code = 'IT')
), -- this CTE retrieves a table only with user_ids and the timestamp of their first_listing

first_listings AS (
    SELECT
        new_listers.*,
        items.category_id,
        items.category_name,
        items.item_id
    FROM new_listers AS new_listers
    LEFT JOIN dwh.prod.items AS items ON new_listers.user_id = items.seller_user_id AND new_listers.first_listing = items.created_at
),
-- this CTE retrieves the category_name, item_id of each user first listing

users_distinct AS (
    SELECT DISTINCT
        first_listings.user_id,
        first_listings.category_name AS entry_category,
        first_listings.country_code AS country_code,
        first_listings.item_id AS item_id,
        added_listings.category_name AS distinct_added_categories -- the '-1' removes the entry_category from the count distinct of other categories
    FROM first_listings
    LEFT JOIN dwh.prod.items AS added_listings ON first_listings.user_id = added_listings.seller_user_id
    WHERE added_listings.created_at BETWEEN '2023-01-01' AND '2023-12-31'
    ORDER BY 2
),

added_category AS (
    SELECT DISTINCT
           entry_category,
           distinct_added_categories,
           country_code,
           COUNT(*) - 1 AS distinct_added_categories_cnt
    FROM users_distinct
    --WHERE distinct_added_categories <> entry_category -- comment this line if you want an analysis for all listings or only for listings which category is different from entry category
    GROUP BY 1, 2, 3
)

SELECT
    country_code,
    entry_category,
    distinct_added_categories,
    ROUND(SUM(distinct_added_categories_cnt) * 100.0 / SUM(SUM(distinct_added_categories_cnt)) OVER (PARTITION BY entry_category, country_code), 2) AS added_category_pctg
FROM added_category
GROUP BY 1, 2, 3
ORDER BY 2
