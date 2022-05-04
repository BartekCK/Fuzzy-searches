/**
  LIKE and ILIKE
 */
select * from netflix where title ilike '%breaking%';

select * from netflix where title ilike 'bad_%';


/**
  Regex
 */

SELECT COUNT(*) FROM netflix WHERE title !~* '^the.*';
SELECT * FROM netflix WHERE title ~* '^crime.*';

CREATE INDEX netflix_title_index ON netflix (lower(title) text_pattern_ops);
DROP INDEX netflix_title_index;

explain analyse SELECT * FROM netflix WHERE lower(title) = 'selling sunset';

/**
  Bride of Levenshtein
 */

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

SELECT levenshtein('bat', 'fads');

SELECT * FROM netflix WHERE levenshtein(lower(title), 'seling sunset') < 2;


/**
  Trigram
 */
CREATE EXTENSION IF NOT EXISTS pg_trgm;

SELECT show_trgm('Node.js');

SELECT similarity('word', 'words two1');
SELECT word_similarity('word', 'words two1');
SELECT strict_word_similarity('word', 'words two1');

SELECT title from netflix where title % 'braking bad'; --misspelling

CREATE INDEX netflix_title_trigram ON netflix USING gist (title gist_trgm_ops);
DROP INDEX netflix_title_trigram;

explain analyse SELECT title from netflix where title % 'braking bad';

SELECT title, similarity(title, 'braking bad') AS sm FROM netflix WHERE title % 'braking bad' ORDER BY sm DESC;
SELECT title, title <-> 'braking bad' AS sm FROM netflix WHERE title % 'braking bad' ORDER BY sm;



/**
  Full text search
 */

-- tsvector type and "lexemes"
SELECT to_tsvector('english','Ala ma kota i ala ma psa, calka'); -- Take a look at the order of words


-- tsquery differences
SELECT title
FROM netflix
WHERE title @@ 'getting so fat';

SELECT title
FROM netflix
WHERE title @@ to_tsquery('getting & so & fat');

SELECT title
FROM netflix
WHERE title @@ plainto_tsquery('getting so fat');

SELECT title
FROM netflix
WHERE title @@ to_tsquery('wild & (west | country)');

-- Let's go deeper

explain analyse SELECT *
from netflix
where to_tsvector(type || ' ' || title || ' ' || director || ' ' || listed_in) @@ plainto_tsquery('movie christmas kenny comedy'); --Movie christmas kenny (Young) comedy


-- Create separate tsvector column
ALTER TABLE netflix
    ADD COLUMN document tsvector;
update netflix
set document = to_tsvector(type || ' ' || title || ' ' || coalesce(director,'') || ' ' || listed_in);

explain analyse select *
from netflix
where document @@ plainto_tsquery('movie christmas kenny comedy');

-- Create separate tsvector column with index
ALTER TABLE netflix
    ADD COLUMN document_with_idx tsvector;
update netflix
set document_with_idx = to_tsvector(type || ' ' || title || ' ' || coalesce(director,'') || ' ' || listed_in);
CREATE INDEX document_idx
    ON netflix
        USING GIN (document_with_idx);

explain analyse select *
                from netflix
                where document_with_idx @@ plainto_tsquery('movie christmas kenny comedy');

-- ts rank

select type, title, director, listed_in
from netflix
where document_with_idx @@ plainto_tsquery('john')
order by ts_rank(document_with_idx, plainto_tsquery('john')) desc ;


ALTER TABLE netflix
    ADD COLUMN document_with_weights tsvector;
update netflix
set document_with_weights = setweight(to_tsvector(coalesce(director, '')), 'A')||
                            setweight(to_tsvector(title), 'B') ||
                            setweight(to_tsvector(type), 'C') ||
                            setweight(to_tsvector(listed_in), 'D');
CREATE INDEX document_weights_idx
    ON netflix
        USING GIN (document_with_weights);

select type, title, director, listed_in, ts_rank(document_with_weights, plainto_tsquery('john')) as rank
from netflix
where document_with_weights @@ plainto_tsquery('john')
order by ts_rank(document_with_weights, plainto_tsquery('john')) desc ;



