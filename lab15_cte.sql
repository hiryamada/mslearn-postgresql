WITH batch_cte AS (
    SELECT azure_cognitive.summarize_abstractive(ARRAY(SELECT description FROM listings ORDER BY id), 'en', batch_size => 25) AS summary
),
summary_cte AS (
    SELECT
        ROW_NUMBER() OVER () AS id,
        ARRAY_TO_STRING(summary, ',') AS summary
    FROM batch_cte
)
UPDATE listings AS l
SET summary = s.summary
FROM summary_cte AS s
WHERE l.id = s.id;
