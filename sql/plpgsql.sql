---
--- point pl/pgsql
---


--- create_point
create or replace function create_point(_identifier character(50),
                      _geohash character varying,
                      _latitude numeric(30,27),
                      _longitude numeric(30,27),
                      _name character varying,
                      _provider character varying,
                      _provider_id character varying,
                      _version character varying)
               returns void as $$
declare
  _point_id integer;
begin
  insert into point (
      identifier,
      geohash,
      latitude,
      longitude,
      name,
      provider,
      provider_id,
      version
    ) values (
      _identifier,
      _geohash,
      _latitude,
      _longitude,
      _name,
      _provider,
      _provider_id,
      _version);
end;
$$ language plpgsql;




--- update_point
create or replace function update_point(_identifier character(50),
                      _name character varying,
                      _geohash character varying,
                      _latitude numeric(30,27),
                      _longitude numeric(30,27),
                      _no_event boolean)
               returns void as $$
declare
  _new_geohash character varying;
  _list_id integer;
  _list_ids integer[];
  _row record;
begin
  select point.id as point_id, point.geohash into _row from point where point.identifier = _identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  
  select coalesce(_geohash, _row.geohash) into _new_geohash;
  update point
  set name = coalesce(_name, name),
    latitude = coalesce(_latitude, latitude),
    longitude = coalesce(_longitude, longitude),
    geohash = _new_geohash
  where identifier = _identifier;

  if _new_geohash != _row.geohash then

    select array_agg(list_id) into _list_ids from list_point where list_point.point_id = _row.point_id group by list_id;
    foreach _list_id in array _list_ids
    loop
      perform _remove_point_from_list(_row.point_id, _identifier, _row.geohash, _list_id, _no_event);
    end loop;
    foreach _list_id in array _list_ids
    loop
      perform _add_point_to_list(_row.point_id, _identifier, _list_id, _new_geohash, _latitude, _longitude, _no_event);
    end loop;
  end if;

  if _no_event = false then
    perform create_event_for_point(_identifier, 7);
  end if;
end;
$$ language plpgsql;



--- delete_point
create or replace function delete_point(_identifier character(50)) returns void as $$
declare
  _list_id integer;
  _list_ids integer[];
  _row record;
begin
  select point.id as point_id, point.geohash into _row from point where point.identifier = _identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  select array_agg(list_id) into _list_ids from list_point where list_point.point_id = _row.point_id group by list_id;
  foreach _list_id in array _list_ids
  loop
    perform _remove_point_from_list(_row.point_id, _identifier, _row.geohash, _list_id, false);
  end loop;

  delete FROM point WHERE identifier = _identifier;
end;
$$ language plpgsql;





--- create_point_meta
create or replace function create_point_meta(_identifier character(50),
                         _point_identifier character(50),
                         _list_identifier character(50),
                         _action character varying,
                         _uid character varying,
                         _content character varying,
                         _no_event boolean)
               returns void as $$
declare
  _point_id integer;
  _list_id integer;
begin
  select id into _point_id from point where identifier = _point_identifier;
  if not found then
    raise exception 'Point identifier lookup failed';
  end if;
  if char_length(_list_identifier) != 0 then
    select list.id into _list_id from list where list.identifier = _list_identifier;
    if not found then
      raise exception 'List identifier lookup failed';
    end if;
  else
    _list_id := null;
  end if;
  insert into point_meta (identifier, point_id, list_id, uid, action, content) values (_identifier, _point_id, _list_id, _uid, _action, _content::jsonb);
  if not _no_event then
    perform create_event_for_point_meta(_identifier, _point_identifier, 9);
  end if;
end;
$$ language plpgsql;




--- update_point_meta
create or replace function update_point_meta(_identifier character(50),
                         _uid character varying,
                         _action character varying,
                         _content character varying)
               returns void as $$
begin
  update point_meta SET uid=_uid, action=_action, content=_content::jsonb WHERE identifier=_identifier;
  perform create_event_for_point_meta(_identifier, null, 10);
end;
$$ language plpgsql;




--- delete_point_meta
create or replace function delete_point_meta(_identifier character(50)) returns void as $$
begin
  perform create_event_for_point_meta(_identifier, null, 11);
  delete FROM point_meta WHERE identifier = _identifier;
end;
$$ language plpgsql;




---
--- list pl/pgsql
---




--- get_list_point
create or replace function get_list_point(_identifier character(50),
                      _geohash character,
                      _exclude_geohash character varying array,
                      _last_point_date timestamp with time zone,
                      _limit integer)
               returns table (id integer,
                      identifier character(50),
                      latitude numeric,
                      longitude numeric,
                      name character varying,
                      provider character varying,
                      provider_id character varying,
                      date_created timestamp with time zone)
               as $$
declare
  _list_id integer;
begin
  select list.id into _list_id from list where list.identifier = _identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  return query select * from (select point.id,
            point.identifier,
            point.latitude,
            point.longitude,
            point.name,
            point.provider,
            point.provider_id,
            list_point.date_created
    from point
    inner join list_point on (list_point.point_id = point.id and list_point.list_id = _list_id)
    where (geohash similar to _geohash || '%')
    and not geohash like any (select * from unnest(_exclude_geohash))
    and list_point.date_created > _last_point_date
    order by list_point.date_created
    limit _limit) as t order by id;
end;
$$ language plpgsql;




--- get_points_for_events
create or replace function get_points_for_events(_event_ids integer array)
               returns table (id integer,
                      identifier character(50),
                      latitude numeric,
                      longitude numeric,
                      name character varying,
                      provider character varying,
                      provider_id character varying,
                      note character varying,
                      notification boolean)
               as $$
begin
  return query select point.id,
            point.identifier,
            point.latitude,
            point.longitude,
            point.name,
            point.provider,
            point.provider_id
    from point
    where point.identifier in (select object_identifier from event where event.id in (select * from unnest(_event_ids)))
    order by point.id;
end;
$$ language plpgsql;




--- get_metas_for_point_ids
create or replace function get_metas_for_point_ids(_point_ids integer array, _list_identifier character(50))
               returns table (point_id integer,
                      identifier character(50),
                      uid character varying,
                      action character varying,
                      content character varying,
                      list character(50))
               as $$
declare
  _list_id integer;
begin
  if char_length(_list_identifier) != 0 then
    select list.id into _list_id from list where list.identifier = _list_identifier;
    if not found then
      raise exception 'Identifier lookup failed';
    end if;
  else
    _list_id := null;
  end if;
  return query select point_meta.point_id,
            point_meta.identifier,
            point_meta.uid,
            point_meta.action,
            point_meta.content::character varying,
            list.identifier as list
    from point_meta
    left join list on (list.id = point_meta.list_id)
    where point_meta.point_id in (select * from unnest(_point_ids))
    and (point_meta.list_id is null or point_meta.list_id = _list_id)
    order by point_meta.point_id;
end;
$$ language plpgsql;




--- get_point_metas_for_events
create or replace function get_point_metas_for_events(_event_ids integer array)
               returns table (identifier character(50),
                      uid character varying,
                      action character varying,
                      content character varying,
                      list character(50))
               as $$
begin
  return query select point_meta.identifier,
            point_meta.uid,
            point_meta.action,
            point_meta.content::character varying,
            list.identifier as list
    from point_meta
    left join list on (list.id = point_meta.list_id)
    where point_meta.identifier in (select object_identifier from event where event.id in (select * from unnest(_event_ids)));
end;
$$ language plpgsql;




--- create_list
create or replace function create_list(_identifier character(50),
                     _name character varying,
                     _icon character varying,
                     _version character varying)
               returns void as $$
begin
  insert into list (identifier, name, icon, version) values (_identifier, _name, _icon, _version);
end;
$$ language plpgsql;




--- get_list_for_events
create or replace function get_list_for_events(_event_ids integer array)
               returns table (identifier character(50),
                      name character varying,
                      icon character varying)
               as $$
begin
  return query select list.identifier,
            list.name,
            list.icon
    from list
    where list.identifier in (select object_identifier from event where event.id in (select * from unnest(_event_ids)));
end;
$$ language plpgsql;




--- get_list_metas_for_events
create or replace function get_list_metas_for_events(_event_ids integer array)
               returns table (identifier character(50),
                      uid character varying,
                      action character varying,
                      content character varying)
               as $$
begin
  return query select list_meta.identifier,
            list_meta.uid,
            list_meta.action,
            list_meta.content::character varying
    from list_meta
    where list_meta.identifier in (select object_identifier from event where event.id in (select * from unnest(_event_ids)));
end;
$$ language plpgsql;




--- get_list_geohash_zones
create or replace function get_list_geohash_zones(_identifier character(50), _max_points integer)
               returns table (geohash character,
                      n_points integer,
                      avg_latitude numeric(30,27),
                      avg_longitude numeric(30,27))
               as $$
declare
  _list_id integer;
begin
  select id into _list_id from list where identifier = _identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  return query select geohash, n_points, avg_latitude, avg_longitude from (
    select list_geohash_625000.geohash, list_geohash_625000.n_points, 625000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_625000 where list_geohash_625000.list_id = _list_id and list_geohash_625000.n_points <= _max_points
  union all
    select list_geohash_312000.geohash, list_geohash_312000.n_points, 312000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_312000 where list_geohash_312000.list_id = _list_id and list_geohash_312000.n_points <= _max_points
  union all
    select list_geohash_156000.geohash, list_geohash_156000.n_points, 156000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_156000 where list_geohash_156000.list_id = _list_id and list_geohash_156000.n_points <= _max_points
  union all
    select list_geohash_80000.geohash, list_geohash_80000.n_points, 80000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_80000 where list_geohash_80000.list_id = _list_id and list_geohash_80000.n_points <= _max_points
  union all
    select list_geohash_40000.geohash, list_geohash_40000.n_points, 40000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_40000 where list_geohash_40000.list_id = _list_id and list_geohash_40000.n_points <= _max_points
  union all
    select list_geohash_20000.geohash, list_geohash_20000.n_points, 20000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_20000 where list_geohash_20000.list_id = _list_id and list_geohash_20000.n_points <= _max_points
  union all
    select list_geohash_9600.geohash, list_geohash_9600.n_points, 9600 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_9600 where list_geohash_9600.list_id = _list_id and list_geohash_9600.n_points <= _max_points
  union all
    select list_geohash_4800.geohash, list_geohash_4800.n_points, 4800 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_4800 where list_geohash_4800.list_id = _list_id and list_geohash_4800.n_points <= _max_points
  union all
    select list_geohash_2400.geohash, list_geohash_2400.n_points, 2400 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_2400 where list_geohash_2400.list_id = _list_id and list_geohash_2400.n_points <= _max_points
  union all
    select list_geohash_1200.geohash, list_geohash_1200.n_points, 1200 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_1200 where list_geohash_1200.list_id = _list_id and list_geohash_1200.n_points <= _max_points
  union all
    select list_geohash_600.geohash, list_geohash_600.n_points, 600 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_600 where list_geohash_600.list_id = _list_id
  ) as t order by geohash_size desc;
end;
$$ language plpgsql;




--- get_list_geohash_zones_for_point
create or replace function get_list_geohash_zones_for_point(_identifier character(50),
                                _point_identifier character(50),
                                _max_points integer)
               returns table (geohash character,
                      n_points integer,
                      avg_latitude numeric(30,27),
                      avg_longitude numeric(30,27))
               as $$
declare
  _list_id integer;
  _point_row record;
begin
  select id into _list_id from list where identifier = _identifier;
  if not found then
    raise exception 'List identifier lookup failed';
  end if;
  select id, point.geohash into _point_row from point where identifier = _point_identifier;
  if not found then
    raise exception 'Point identifier lookup failed';
  end if;
  return query select geohash, n_points, avg_latitude, avg_longitude from (
    select list_geohash_625000.geohash, list_geohash_625000.n_points, 625000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_625000 where list_geohash_625000.geohash = substring(_point_row.geohash for 5) and list_geohash_625000.list_id = _list_id and list_geohash_625000.n_points <= _max_points
  union all
    select list_geohash_312000.geohash, list_geohash_312000.n_points, 312000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_312000 where list_geohash_312000.geohash = substring(_point_row.geohash for 6) and list_geohash_312000.list_id = _list_id and list_geohash_312000.n_points <= _max_points
  union all
    select list_geohash_156000.geohash, list_geohash_156000.n_points, 156000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_156000 where list_geohash_156000.geohash = substring(_point_row.geohash for 7) and list_geohash_156000.list_id = _list_id and list_geohash_156000.n_points <= _max_points
  union all
    select list_geohash_80000.geohash, list_geohash_80000.n_points, 80000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_80000 where list_geohash_80000.geohash = substring(_point_row.geohash for 8) and list_geohash_80000.list_id = _list_id and list_geohash_80000.n_points <= _max_points
  union all
    select list_geohash_40000.geohash, list_geohash_40000.n_points, 40000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_40000 where list_geohash_40000.geohash = substring(_point_row.geohash for 9) and list_geohash_40000.list_id = _list_id and list_geohash_40000.n_points <= _max_points
  union all
    select list_geohash_20000.geohash, list_geohash_20000.n_points, 20000 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_20000 where list_geohash_20000.geohash = substring(_point_row.geohash for 10) and list_geohash_20000.list_id = _list_id and list_geohash_20000.n_points <= _max_points
  union all
    select list_geohash_9600.geohash, list_geohash_9600.n_points, 9600 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_9600 where list_geohash_9600.geohash = substring(_point_row.geohash for 11) and list_geohash_9600.list_id = _list_id and list_geohash_9600.n_points <= _max_points
  union all
    select list_geohash_4800.geohash, list_geohash_4800.n_points, 4800 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_4800 where list_geohash_4800.geohash = substring(_point_row.geohash for 12) and list_geohash_4800.list_id = _list_id and list_geohash_4800.n_points <= _max_points
  union all
    select list_geohash_2400.geohash, list_geohash_2400.n_points, 2400 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_2400 where list_geohash_2400.geohash = substring(_point_row.geohash for 13) and list_geohash_2400.list_id = _list_id and list_geohash_2400.n_points <= _max_points
  union all
    select list_geohash_1200.geohash, list_geohash_1200.n_points, 1200 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_1200 where list_geohash_1200.geohash = substring(_point_row.geohash for 14) and list_geohash_1200.list_id = _list_id and list_geohash_1200.n_points <= _max_points
  union all
    select list_geohash_600.geohash, list_geohash_600.n_points, 600 as geohash_size, avg_latitude, avg_longitude
    from list_geohash_600 where list_geohash_600.geohash = substring(_point_row.geohash for 15) and list_geohash_600.list_id = _list_id
  ) as t order by geohash_size desc;
end;
$$ language plpgsql;




--- get_zone_tree_level
create or replace function get_zone_tree_level(_identifier character(50),
                         _geohash_length integer,
                         _from_nodes character array,
                         _from_nodes_size integer)
               returns table (geohash character,
                            n_points integer,
                            avg_latitude numeric(30,27),
                            avg_longitude numeric(30,27))
               as $$
declare
  _list_id integer;
begin
  select id into _list_id from list where identifier = _identifier;
  if not found then
    raise exception 'List identifier lookup failed';
  end if;
  if _geohash_length <= 5 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_625000 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 6 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_312000 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 7 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_156000 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 8 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_80000 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 9 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_40000 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 10 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_20000 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 11 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_9600 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 12 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_4800 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 13 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_2400 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 14 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_1200 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 15 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_600 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length = 16 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash_300 l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  elsif _geohash_length >= 17 then
  return query select l.geohash, l.n_points, l.avg_latitude, l.avg_longitude
          from list_geohash l where list_id = _list_id
          and substring(l.geohash for _from_nodes_size) in (select * from unnest(_from_nodes));
  end if;
end;
$$ language plpgsql;




--- get_lists_aroundme
create or replace function get_lists_aroundme(_geohashes character array)
               returns table (identifier character(50),
                      name character varying,
                      icon character varying,
                      n_installs integer)
               as $$
begin
  return query select distinct list.identifier, list.name, list.icon, list.n_installs
    from list
    inner join list_geohash_20000 on (list_geohash_20000.list_id = list.id and list_geohash_20000.geohash in (select * from unnest(_geohashes)))
    where is_public = true;
end;
$$ language plpgsql;




--- get_complete_list_infos
create or replace function get_complete_list_infos(_identifier character(50))
               returns table (name character varying,
                      icon character varying,
                      n_points integer,
                      n_installs integer,
                      last_update timestamp with time zone)
               as $$
begin
  return query select list.name,
            list.icon,
            (select count(*) from list_point where list_point.list_id = list.id)::integer as n_points,
            list.last_update
    from list
    where list.identifier = _identifier;
end;
$$ language plpgsql;




--- get_list_metas
create or replace function get_list_metas(_list_identifier character(50))
               returns table (identifier character(50),
                      uid character varying,
                      action character varying,
                      content character varying)
               as $$
declare
  _list_id integer;
begin
  select id into _list_id from list where list.identifier = _list_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  return query select list_meta.identifier,
            list_meta.uid,
            list_meta.action,
            list_meta.content::character varying
    from list_meta
    where list_meta.list_id = _list_id;
end;
$$ language plpgsql;




--- update_list
create or replace function update_list(_identifier character(50),
                     _name character(50),
                    _icon character(50))
               returns void as $$
begin
  update list set name = coalesce(_name, name), icon = coalesce(_icon, icon) where identifier = _identifier;
  perform create_event_for_list(_identifier, 1);
end;
$$ language plpgsql;




--- add_point_to_list
create or replace function add_point_to_list(_point_identifier character(50),
                         _list_identifier character(50),
                         _no_event boolean)
               returns void as $$
declare
  _row record;
  _list_id integer;
begin
  select id as point_id, geohash, latitude, longitude into _row from point where identifier = _point_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  select id into _list_id from list where identifier = _list_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  if exists(select 1 from list_point where list_id = _list_id and point_id = _row.point_id) then
    return;
  end if;
  perform _add_point_to_list(_row.point_id, _point_identifier, _list_id, _row.geohash, _row.latitude, _row.longitude, _no_event);
end;
$$ language plpgsql;




--- _add_point_to_list
create or replace function _add_point_to_list(_point_id integer,
                        _point_identifier character(50),
                        _list_id integer,
                        _geohash character varying,
                        _latitude numeric(30,27),
                        _longitude numeric(30,27),
                        _no_event boolean)
               returns void as $$
declare
begin
  insert into list_point (list_id, point_id) values (_list_id, _point_id);
  perform add_geohash_to_list(_list_id, _geohash, _latitude, _longitude);
  if not _no_event then
    perform create_event(_list_id, _geohash, 5, _point_identifier, null);
  end if;
end;
$$ language plpgsql;




--- remove_point_from_list
create or replace function remove_point_from_list(_point_identifier character(50),
                          _list_identifier character(50),
                          _no_event boolean)
               returns void as $$
declare
  _row record;
  _list_id integer;
begin
  select id as point_id, geohash into _row from point where identifier = _point_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  select id into _list_id from list where identifier = _list_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  if not exists(select 1 from list_point where list_id = _list_id and point_id = _row.point_id) then
    return;
  end if;
  perform _remove_point_from_list(_row.point_id, _point_identifier, _row.geohash, _list_id, _no_event);
end;
$$ language plpgsql;




--- _remove_point_from_list
create or replace function _remove_point_from_list(_point_id integer,
                           _point_identifier character(50),
                           _geohash character varying,
                           _list_id integer,
                           _no_event boolean)
               returns void as $$
begin
  delete from list_point where list_id = _list_id and point_id = _point_id;
  perform remove_geohash_from_list(_list_id, _geohash);
  delete from event where list_id = _list_id and object_identifier = _point_identifier;
  if not _no_event then
    perform create_event(_list_id, _geohash, 6, _point_identifier, null);
  end if;
end;
$$ language plpgsql;



--- add_geohash_to_list
create or replace function add_geohash_to_list(_list_id integer,
                           _geohash character varying,
                           _latitude numeric(30,27),
                           _longitude numeric(30,27))
               returns void as $$
declare
  _geohash_id integer;
  _sub_geohash character varying;
begin
  select _geohash into _sub_geohash;
  select id into _geohash_id from list_geohash where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash set n_points=n_points+1,
                  avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
                  avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 16) into _sub_geohash;
  select id into _geohash_id from list_geohash_300 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_300 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_300 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_300 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 15) into _sub_geohash;
  select id into _geohash_id from list_geohash_600 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_600 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_600 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_600 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 14) into _sub_geohash;
  select id into _geohash_id from list_geohash_1200 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_1200 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_1200 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_1200 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 13) into _sub_geohash;
  select id into _geohash_id from list_geohash_2400 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_2400 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_2400 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_2400 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 12) into _sub_geohash;
  select id into _geohash_id from list_geohash_4800 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_4800 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_4800 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_4800 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 11) into _sub_geohash;
  select id into _geohash_id from list_geohash_9600 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_9600 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_9600 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_9600 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 10) into _sub_geohash;
  select id into _geohash_id from list_geohash_20000 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_20000 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_20000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_20000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 9) into _sub_geohash;
  select id into _geohash_id from list_geohash_40000 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_40000 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_40000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_40000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 8) into _sub_geohash;
  select id into _geohash_id from list_geohash_80000 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_80000 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_80000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_80000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 7) into _sub_geohash;
  select id into _geohash_id from list_geohash_156000 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_156000 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_156000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_156000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 6) into _sub_geohash;
  select id into _geohash_id from list_geohash_312000 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_312000 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_312000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_312000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

  select substring(_geohash for 5) into _sub_geohash;
  select id into _geohash_id from list_geohash_625000 where geohash = _sub_geohash and list_id = _list_id;
  if not found then
    begin
      insert into list_geohash_625000 (list_id, geohash, n_points, avg_latitude, avg_longitude) values (_list_id, _sub_geohash, 1, _latitude, _longitude);
    exception when others then
      update list_geohash_625000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
      where list_id = _list_id and geohash = _sub_geohash;
    end;
  else
    update list_geohash_625000 set n_points=n_points+1,
            avg_latitude = (avg_latitude * n_points + _latitude) / (n_points + 1),
            avg_longitude = (avg_longitude * n_points + _longitude) / (n_points + 1)
    where list_id = _list_id and geohash = _sub_geohash;
  end if;

end;
$$ language plpgsql;




--- remove_geohash_from_list
create or replace function remove_geohash_from_list(_list_id integer, _geohash character) returns void as $$
declare
  _sub_geohash character varying;
begin
  select _geohash into _sub_geohash;
  if found then
    update list_geohash set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 16) into _sub_geohash;
  if found then
    update list_geohash_300 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 15) into _sub_geohash;
  if found then
    update list_geohash_600 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 14) into _sub_geohash;
  if found then
    update list_geohash_1200 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 13) into _sub_geohash;
  if found then
    update list_geohash_2400 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 12) into _sub_geohash;
  if found then
    update list_geohash_4800 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 11) into _sub_geohash;
  if found then
    update list_geohash_9600 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 10) into _sub_geohash;
  if found then
    update list_geohash_20000 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 9) into _sub_geohash;
  if found then
    update list_geohash_40000 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 8) into _sub_geohash;
  if found then
    update list_geohash_80000 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 7) into _sub_geohash;
  if found then
    update list_geohash_156000 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 6) into _sub_geohash;
  if found then
    update list_geohash_312000 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

  select substring(_geohash for 5) into _sub_geohash;
  if found then
    update list_geohash_625000 set n_points=n_points-1 where geohash = _sub_geohash and list_id = _list_id;
  end if;

end;
$$ language plpgsql;




--- create_list_meta
create or replace function create_list_meta(_identifier character(50),
                      _list_identifier character(50),
                      _uid character varying,
                      _action character varying,
                      _content character varying)
               returns void as $$
declare
  _list_id integer;
begin
  select id into _list_id from list where identifier = _list_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  insert into list_meta (identifier, list_id, uid, action, content) values (_identifier, _list_id, _uid, _action, _content::jsonb);
  perform create_event_for_list_meta(_identifier, 2);
end;
$$ language plpgsql;




--- update_list_meta
create or replace function update_list_meta(_identifier character(50),
                      _uid character varying,
                      _action character varying,
                      _content character varying)
               returns void as $$
begin
  update list_meta SET uid=_uid, action=_action, content=_content::jsonb WHERE identifier=_identifier;
  perform create_event_for_list_meta(_identifier, 3);
end;
$$ language plpgsql;




--- delete_list_meta
create or replace function delete_list_meta(_identifier character(50)) returns void as $$
begin
  perform create_event_for_list_meta(_identifier, 4);
  delete FROM list_meta WHERE identifier = _identifier;
end;
$$ language plpgsql;




---
--- event pl/pgsql
---




--- create_event
create or replace function create_event(_list_id integer,
                    _geohash character(17),
                    _event integer,
                    _object_identifier character(50),
                    _object_identifier2 character varying)
               returns void as $$
begin
  insert into event (
      list_id,
      geohash,
      event,
      object_identifier,
      object_identifier2
    ) values (
      _list_id,
      _geohash,
      _event,
      _object_identifier,
      _object_identifier2);
end;
$$ language plpgsql;




--- create_event_for_list
create or replace function create_event_for_list(_list_identifier character(50), _event integer) returns void as $$
declare
  _list_id integer;
begin
  select id into _list_id from list where identifier = _list_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  perform create_event(_list_id, null, _event, null, null);
end;
$$ language plpgsql;




--- create_event_for_point
create or replace function create_event_for_point(_point_identifier character(50), _event integer) returns void as $$
declare
  _list_id integer;
  _geohash character varying;
begin
  for _list_id, _geohash in select list_id, geohash from list_point inner join point on (point.id = list_point.point_id and point.identifier = _point_identifier)
    loop
      perform create_event(_list_id, _geohash, _event, _point_identifier, null);
    end loop;
end;
$$ language plpgsql;




--- create_event_for_point_meta
create or replace function create_event_for_point_meta(_point_meta_identifier character(50),
                             _point_identifier character(50),
                             _event integer)
               returns void as $$
declare
  _list_id integer;
  _row record;
begin
  select list_id, point.geohash, point.id as point_id into _row from point_meta inner join point on (point.id = point_meta.point_id) where point_meta.identifier = _point_meta_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  if _row.list_id is not null then
    perform create_event(_row.list_id, _row.geohash, _event, _point_meta_identifier, _point_identifier);
  else
    for _list_id in select list_id from list_point where list_point.point_id = _row.point_id
      loop
        perform create_event(_list_id, _row.geohash, _event, _point_meta_identifier, _point_identifier);
      end loop;
  end if;
end;
$$ language plpgsql;




--- create_event_for_list_meta
create or replace function create_event_for_list_meta(_list_meta_identifier character(50), _event integer) returns void as $$
declare
  _list_id integer;
begin
  select list_id into _list_id from list_meta where list_meta.identifier = _list_meta_identifier;
  if not found then
    raise exception 'Identifier lookup failed';
  end if;
  perform create_event(_list_id, null, _event, _list_meta_identifier, null);
end;
$$ language plpgsql;




--- consume_event
create or replace function consume_event(_list_identifier character(50),
                     _geohash character varying,
                     _last_date timestamp with time zone) 
               returns table (id integer,
                      date timestamp with time zone,
                      event integer, object_identifier character(50),
                      object_identifier2 character(50))
               as $$
declare
  _list_id integer;
begin
  if char_length(_list_identifier) != 0 then
    select list.id into _list_id from list where list.identifier = _list_identifier;
    if not found then
      raise exception 'Identifier lookup failed';
    end if;
  end if;
  return query select event.id,
            event.date_created,
            event.event,
            coalesce(event.object_identifier, ''),
            coalesce(event.object_identifier2, '')
  from event
  where ((_list_id is not null and event.list_id = _list_id) or (_list_id is null and event.list_id is null)) and
      (
      ((_geohash is null or char_length(_geohash) = 0) and geohash is null)
      or
      (
        (_geohash is not null and char_length(_geohash) != 0)
        and
        (geohash like _geohash || '%')
      )
      )
      and ((_last_date is not null and event.date_created > _last_date) or (_last_date is null))
  order by event.date_created asc
  limit 50;
end;
$$ language plpgsql;




--- last_event_date
create or replace function last_event_date(_list_identifier character(50),
                       _geohash character varying,
                       _last_date timestamp with time zone)
               returns table (last_date timestamp with time zone)
               as $$
declare
  _list_id integer;
begin
  if char_length(_list_identifier) != 0 then
    select list.id into _list_id from list where list.identifier = _list_identifier;
    if not found then
      raise exception 'Identifier lookup failed';
    end if;
  else
    _list_id := null;
  end if;
  return query select max(event.date_created) from event
  where ((_list_id is not null and event.list_id = _list_id) or (_list_id is null and event.list_id is null)) and
      (
      ((_geohash is null or char_length(_geohash) = 0) and geohash is null)
      or
      (
        (_geohash is not null or  char_length(_geohash) != 0)
        and
        (geohash = _geohash || '%')
      )
      )
      and ((_last_date is not null and event.date_created > _last_date) or (_last_date is null));
end;
$$ language plpgsql;

--- Jjonb Utils
--- from : http://michael.otacoo.com/postgresql-2/manipulating-jsonb-data-with-key-unique/

CREATE OR REPLACE FUNCTION jsonb_append(jsonb, jsonb)
RETURNS jsonb AS $$
WITH json_union AS
(SELECT * FROM jsonb_each_text($1)
  UNION ALL
  SELECT * FROM jsonb_each_text($2))
SELECT json_object_agg(key, value)::jsonb FROM json_union;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION jsonb_add_key_value_single(jsonb, text, text)
RETURNS jsonb as $$
SELECT jsonb_append($1, json_build_object($2, $3)::jsonb);
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION jsonb_append_key_value_pairs(jsonb, variadic text[])
RETURNS jsonb AS $$
SELECT jsonb_append($1, json_object($2)::jsonb);
$$ LANGUAGE SQL;
