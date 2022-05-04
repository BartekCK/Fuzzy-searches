select count(*) from quotes;


/**
  Regex
 */

CREATE INDEX IF NOT EXISTS author_title_lower_index ON quotes (lower(author) text_pattern_ops);
DROP INDEX author_title_lower_index;

explain analyse SELECT * FROM quotes WHERE lower(author) = 'albert einstein';




/**
  TRIGRAMS
 */
CREATE INDEX quotes_author_trigram ON quotes USING gist (author gist_trgm_ops);
-- Misspelling with index ~200ms
explain analyse SELECT * from quotes where author %>> 'alberd einstein';

DROP INDEX quotes_author_trigram;
-- Misspelling in name ~4s without index
SELECT * from quotes where author %>> 'alberd einstein';


/**
  FTS
 */
ALTER TABLE quotes
    ADD COLUMN quotes_document_with_idx tsvector;
update quotes
set quotes_document_with_idx = to_tsvector(quotes.author || ' ' || quotes.category || ' ' || quotes.quote);
CREATE INDEX quotes_document_idx
    ON quotes
        USING GIN (quotes_document_with_idx);


SELECT * FROM quotes WHERE to_tsvector(quotes.category) @@ 'albert & einstein';
SELECT * FROM quotes WHERE quotes_document_with_idx @@ to_tsquery('albert & einstein');

