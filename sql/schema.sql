--- API access table

create table api_access (
  id serial primary key,

  identifier character(50) not null unique,

  name character(50) not null
);

--- point models

create table point (
    id serial primary key,
    identifier character(50) not null unique,

    geohash character(17) not null,

    latitude numeric(30,27) not null,
    longitude numeric(30,27) not null,

    name character varying(200) not null,
    date_created timestamp(3) with time zone not null default now(),

    provider character varying(100) not null,
    provider_id character varying(200) not null,

    version character varying(10) not null
);

create unique index point_identifier_index on point (identifier);
create index point_geohash_index on point (geohash bpchar_pattern_ops);
create index point_provider_index on point (provider);
create index point_provider_id_index on point (provider_id);

--- list models

create table list (
    id serial primary key,
    identifier character(50) not null unique,

    name character varying(50) not null,
    icon character varying(50) not null default 'default_icon',
    date_created timestamp(3) with time zone not null default now(),
    last_update timestamp(3) with time zone not null default now(),

    version character varying(10) not null
);

create unique index list_identifier_index on list (identifier);

--- geohash tables

create table list_geohash (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(17) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash UNIQUE (list_id, geohash)
);

create index list_geohash_geohash_index on list_geohash (geohash);

create table list_geohash_300 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(16) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_300 UNIQUE (list_id, geohash)
);

create index list_geohash_300_geohash_index on list_geohash_300 (geohash);

create table list_geohash_600 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(15) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_600 UNIQUE (list_id, geohash)
);

create index list_geohash_600_geohash_index on list_geohash_600 (geohash);

create table list_geohash_1200 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(14) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_1200 UNIQUE (list_id, geohash)
);

create index list_geohash_1200_geohash_index on list_geohash_1200 (geohash);

create table list_geohash_2400 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(13) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_2400 UNIQUE (list_id, geohash)
);

create index list_geohash_2400_geohash_index on list_geohash_2400 (geohash);

create table list_geohash_4800 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(12) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_4800 UNIQUE (list_id, geohash)
);

create index list_geohash_4800_geohash_index on list_geohash_4800 (geohash);

create table list_geohash_9600 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(11) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_9600 UNIQUE (list_id, geohash)
);

create index list_geohash_9600_geohash_index on list_geohash_9600 (geohash);

create table list_geohash_20000 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(10) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_20000 UNIQUE (list_id, geohash)
);

create index list_geohash_20000_geohash_index on list_geohash_20000 (geohash);

create table list_geohash_40000 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(9) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_40000 UNIQUE (list_id, geohash)
);

create index list_geohash_40000_geohash_index on list_geohash_40000 (geohash);

create table list_geohash_80000 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(8) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_80000 UNIQUE (list_id, geohash)
);

create index list_geohash_80000_geohash_index on list_geohash_80000 (geohash);

create table list_geohash_156000 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(7) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_156000 UNIQUE (list_id, geohash)
);

create index list_geohash_156000_geohash_index on list_geohash_156000 (geohash);

create table list_geohash_312000 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(6) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_312000 UNIQUE (list_id, geohash)
);

create index list_geohash_312000_geohash_index on list_geohash_312000 (geohash);

create table list_geohash_625000 (
    id serial primary key,
    list_id integer not null references list on delete cascade,

    avg_latitude numeric(30,27) not null,
    avg_longitude numeric(30,27) not null,

    geohash character(5) not null,
    n_points integer not null default 0,
    CONSTRAINT u_constraint_geohash_625000 UNIQUE (list_id, geohash)
);

create index list_geohash_625000_geohash_index on list_geohash_625000 (geohash);

create table list_meta (
    id serial primary key,
    identifier character(50) not null unique,

    list_id integer not null references list on delete cascade,

    action character varying(50) not null,
    uid character varying(30) not null,
    content jsonb not null,

    date_created timestamp(3) with time zone not null default now()
);

create unique index list_meta_identifier_index on list_meta (identifier);

create table list_point (
    list_id integer not null references list on delete cascade,
    point_id integer not null references point on delete cascade,

    date_created timestamp(3) with time zone not null default now()
);

create table point_meta (
    id serial primary key,
    identifier character(50) not null unique,

    list_id integer references list on delete cascade,
    point_id integer not null references point on delete cascade,

    action character varying(50) not null,
    uid character varying(30) not null,
    content jsonb not null,

    date_created timestamp(3) with time zone not null default now()
);

create unique index point_meta_identifier_index on point_meta (identifier);

create table event (
    id serial primary key,

    list_id integer references list on delete cascade,

    geohash character(17),

    event integer not null,
    date_created timestamp(3) with time zone not null default now(),

    object_identifier character(50) default '',
    object_identifier2 character(50) default ''
);

create index event_geohash_index on event (geohash bpchar_pattern_ops);
