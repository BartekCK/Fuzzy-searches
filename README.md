## LIKE and ILIKE

LIKE and ILIKE are the simplest forms of text search (ILIKE is a case-insensitive version of LIKE).

```sql
SELECT title FROM movies WHERE title ILIKE 'stardust%';
```


If we want to be sure the substring stardust is not at the end of the string, we can use the underscore (_) character as a little trick

```sql
SELECT title FROM movies WHERE title ILIKE 'stardust_%';
```


## Regex
A more powerful string-matching syntax is a regular expression

In Postgres, a regular expression match is led by the ~ operator, with the optional ! (meaning not matching) and * (meaning case insensitive). To count all movies that do not begin with the, the following case-insensitive query will work. The characters inside the string are the regular expression.

```sql
SELECT COUNT(*) FROM movies WHERE title !~* '^the.*';
```


**Indexes:**
```sql
CREATE INDEX netflix_title_index ON netflix (lower(title) text_pattern_ops);
```

We used the text_pattern_ops because the title is of type text. If you need to index varchars, chars, or names, mapping is required.

**Indexes types mapping:**
- text -> text_pattern_ops
- varchars -> varchar_pattern_ops
- chars -> bpchar_pattern_ops
- names -> name_pattern_ops


## Bride of Levenshtein

**Require module:** `fuzzystrmatch`

Levenshtein is a string comparison algorithm that compares how similar two strings are by how many steps are required to change one string into another. Each replaced, missing, or added character counts as a step. The distance is the total number of steps away.

`SELECT levenshtein('bat', 'fads');` distance is 3
- b=> f
- t=>d
- +s

Changes in case cost a point, too, so you may find it best to convert all strings to the same case when querying.
```sql
SELECT movie_id, title FROM movies  
WHERE levenshtein(lower(title), lower('a hard day nght')) <= 3;
```

## Trigram

**Require module:** `pg_trgm`

It's a group of three consecutive characters taken from a string. We can measure the similarity of two strings by counting the number of trigrams they share. This simple idea turns out to be very effective for measuring the similarity of words in many natural languages.

```sql
SELECT show_trgm('Node.js');
```
Result `{  j,  n, js, no,de ,js ,nod,ode}`

It’s useful for doing a search where you’re okay with either slight misspellings or even minor words missing. The longer the string, the more trigrams and the more likely a match

**Module functions:**
- `similarity` ( `text`, `text` ) → `real` - Returns a number that indicates how similar the two arguments are. The range of the result is zero (indicating that the two strings are completely dissimilar) to one (indicating that the two strings are identical).
- `show_trgm` ( `text` ) → `text[]` - Returns an array of all the trigrams in the given string. (In practice this is seldom useful except for debugging.)
- `word_similarity` ( `text`, `text` ) → `real` - Returns a number that indicates the greatest similarity between the set of trigrams in the first string and any continuous extent of an ordered set of trigrams in the second string.
- `strict_word_similarity` ( `text`, `text` ) → `real` - Same as `word_similarity`, but forces extent boundaries to match word boundaries. Since we don't have cross-word trigrams, this function actually returns greatest similarity between first string and any continuous extent of words of the second string.
-  `SHOW` `pg_trgm.similarity_threshold` → `real` - Returns the current similarity threshold used by the `%` operator.
- `SET` `pg_trgm.similarity_threshold` -> `real` - Sets the current similarity threshold that is used by the `%` operator. The threshold must be between 0 and 1 (default is 0.3).



**Operators:**

- `text` `%` `text` → `boolean` - Returns `true` if its arguments have a similarity that is greater than the current similarity threshold set by `pg_trgm.similarity_threshold`.
- `text` `<%` `text` → `boolean` - Returns `true` if the similarity between the trigram set in the first argument and a continuous extent of an ordered trigram set in the second argument is greater than the current word similarity threshold
- `text` `%>` `text` → `boolean` - Commutator of the `<%` operator.
- `text` `<<%` `text` → `boolean` - Returns `true` if its second argument has a continuous extent of an ordered trigram set that matches word boundaries, and its similarity to the trigram set of the first argument is greater than the current strict word similarity threshold set by the `pg_trgm.strict_word_similarity_threshold` parameter.
- `text` `%>>` `text` → `boolean` - Commutator of the `<<%` operator.
- `text` `<->` `text` → `real` - Returns the “distance” between the arguments, that is one minus the `similarity()` value.
- `text` `<<->` `text` → `real` - Returns the “distance” between the arguments, that is one minus the `word_similarity()` value.
- `text` `<->>` `text` → `real` - Commutator of the `<<->` operator.
- `text` `<<<->` `text` → `real` - Returns the “distance” between the arguments, that is one minus the `strict_word_similarity()` value.
- `text` `<->>>` `text` → `real` - Commutator of the `<<<->` operator.

We’ll create a trigram index against movie names to start, using Generalized Index Search Tree (GIST), a generic index API made available by the PostgreSQL engine.

```sql
SELECT title from netflix where title % 'braking bad';
SELECT title, title <-> 'braking bad' AS sm FROM netflix WHERE title % 'braking bad' ORDER BY sm;
```


```sql
CREATE INDEX netflix_title_trigram ON netflix USING gist (title gist_trgm_ops);
```

Trigrams are an excellent choice for accepting user input without weighing queries down with wildcard complexity.

## Full text search
Next, we want to allow users to perform full-text searches based on matching words, even if they’re pluralized. If a user wants to search for certain words in a movie title but can remember only some of them, Postgres supports simple natural language processing.

```
SELECT title  
FROM movies  
WHERE title @@ 'night & day';

title

-------------------------------

A Hard Day's Night  
Six Days Seven Nights  
Long Day's Journey Into Night
```

The `@@` operator **converts the name field into a tsvector** and **converts the query into a tsquery**.

**tsvector** - is a datatype that splits a string into an array (or a vector) of tokens, which are searched against the given query. (sorted list of distinct _lexemes_)
- to_tsvector([ _`config`_ `regconfig`, ] _`document`_ `text`) returns `tsvector`

**tsquery** - is query in a given language
- to_tsquery([ _`config`_ `regconfig`, ] _`querytext`_ `text`) returns `tsquery` - must consist of single tokens separated by the `tsquery` operators `&` (AND), `|` (OR), `!` (NOT), and `<->` (FOLLOWED BY)

- plainto_tsquery([ _`config`_ `regconfig`, ] _`querytext`_ `text`) returns `tsquery` - transforms the unformatted text _`querytext`_ to a `tsquery` value. The text is parsed and normalized much as for `to_tsvector`, then the `&` (AND) `tsquery` operator is inserted between surviving words. (helps forgiving about its input)

### Indexing Lexemes

Full-text search is powerful. But if we don’t index our tables, it’s also slow. The EXPLAIN command is a powerful tool for digging into how queries are internally planned.

```sql
CREATE INDEX netflix_title_searchable ON netflix USING gin(to_tsvector('english', title));
```


### Ranking Search Results
Ranking attempts to measure how relevant documents are to a particular query, so that when there are many matches the most relevant ones can be shown first. PostgreSQL provides two predefined ranking functions, which take into account lexical, proximity, and structural information; that is, they consider how often the query terms appear in the document, how close together the terms are in the document, and how important is the part of the document where they occur.

- ts_rank([ _`weights`_ `float4[]`, ] _`vector`_ `tsvector`, _`query`_ `tsquery` [, _`normalization`_ `integer` ]) returns `float4`  - Ranks vectors based on the frequency of their matching lexemes.

- ts_rank_cd([ _`weights`_ `float4[]`, ] _`vector`_ `tsvector`, _`query`_ `tsquery` [, _`normalization`_ `integer` ]) returns `float4` - This function computes the _cover density_ ranking for the given document vector and query
