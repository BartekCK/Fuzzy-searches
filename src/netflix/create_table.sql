create table netflix
(
    id uuid not null,
    show_id TEXT not null,
    type TEXT,
    title TEXT not null,
    director TEXT,
    "cast" TEXT,
    country TEXT,
    date_added TEXT,
    release_year INT,
    rating TEXT,
    duration TEXT,
    listed_in TEXT,
    description TEXT
);

create unique index netflix_id_uindex
    on netflix (id);

alter table netflix
    add constraint netflix_pk
        primary key (id);

