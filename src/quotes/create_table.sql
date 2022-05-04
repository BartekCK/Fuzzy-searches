create table quotes
(
    id       uuid not null,
    author   TEXT,
    category TEXT,
    quote    TEXT
);

create unique index quotes_id_uindex
    on quotes (id);

alter table quotes
    add constraint quotes_pk
        primary key (id);
