create or replace function fake_table(
    _table_ident text[],
    _make_table_empty boolean default false,
    _leave_primary_key boolean default false,
    _drop_not_null boolean DEFAULT false,
    _drop_collation boolean DEFAULT false,
    _drop_partitions boolean DEFAULT false
)
returns void
--It frees a table from any constraint (we call such a table as a fake)
--faked table is a full copy of _table_name, but has no any constraint
--without foreign and primary things you can do whatever you want in testing context
 LANGUAGE plpgsql
AS $function$
declare
    _table record;
    _fk_table record;
    _part_table record;
    _fake_ddl text;
    _not_null_ddl text;
begin
    for _table in
        select
            quote_ident(coalesce((parse_ident(table_ident))[1], '')) table_schema,
            quote_ident(coalesce((parse_ident(table_ident))[2], '')) table_name,
            coalesce((parse_ident(table_ident))[1], '') table_schema_l,
            coalesce((parse_ident(table_ident))[2], '') table_name_l
        from
            unnest(_table_ident) as t(table_ident)
        loop
            for _fk_table in
                -- collect all table's relations including primary key and unique constraint
                select distinct *
                from (
                    select
                        fk_schema_name table_schema, fk_table_name table_name
						, fk_constraint_name constraint_name, false as is_pk, 1 as ord
                    from
                        pg_all_foreign_keys
                    where
                        fk_schema_name = _table.table_schema_l and fk_table_name = _table.table_name_l
                    union all
                    select
                        fk_schema_name table_schema, fk_table_name table_name
						, fk_constraint_name constraint_name, false as is_pk, 1 as ord
                    from
                        pg_all_foreign_keys
                    where
                        pk_schema_name = _table.table_schema_l and pk_table_name = _table.table_name_l
                    union all
                    select
                        table_schema, table_name
						, constraint_name
						, case when constraint_type = 'PRIMARY KEY' then true else false end as is_pk, 2 as ord
                    from
                        information_schema.table_constraints
                    where
                        table_schema = _table.table_schema_l
                        and table_name = _table.table_name_l
                        and constraint_type in ('PRIMARY KEY', 'UNIQUE')
                ) as t
                order by ord
            loop
				if not(_leave_primary_key and _fk_table.is_pk) then
	                _fake_ddl = format('alter table %1$I.%2$I drop constraint %3$I;',
	                	_fk_table.table_schema/*1*/, _fk_table.table_name/*2*/, _fk_table.constraint_name/*3*/
	                );
	                execute _fake_ddl;
				end if;
            end loop;

            if _make_table_empty then
                _fake_ddl = format('truncate table %1$s.%2$s;', _table.table_schema, _table.table_name);
                execute _fake_ddl;
            end if;

            --Free table from not null constraints
            _fake_ddl = format('alter table %1$s.%2$s ', _table.table_schema, _table.table_name);
            if _drop_not_null then
                select
                    string_agg(format('alter column %1$I drop not null', t.attname), ', ')
                into
                    _not_null_ddl
                from
                    pg_catalog.pg_attribute t
                where t.attrelid = (_table.table_schema || '.' || _table.table_name)::regclass
                    and t.attnum > 0 and attnotnull and attidentity = '' /*'d' or 'a' means generated as identity*/
					--We must be sure that the current column is not part of PK
					and not exists(
						select * from (
							select unnest(_keys(_table.table_schema, _table.table_name, 'p')) as col_name
						) as tt where col_name = t.attname::text);

                _fake_ddl = _fake_ddl || _not_null_ddl || ';';
            else
                _fake_ddl = null;
            end if;

            if _fake_ddl is not null then
                execute _fake_ddl;
            end if;

            if _drop_partitions then
                if pg_version_num() < 100000 then
                    raise exception 'Sorry, but declarative partitioning was introduced only starting with PostgreSQL version 10.';
                end if;
                for _part_table in select _parts from _parts(_table.table_schema, _table.table_name) loop
                    _fake_ddl = 'drop table if exists ' || _part_table._parts || ';';
                    execute _fake_ddl;
                end loop;
            end if;
        end loop;
end $function$;