create or replace FUNCTION _param_of_mode(
	_param_modes text[], 
	_param_names text[], 
	_mode text default 'IN'
)
 RETURNS setof text
 LANGUAGE plpgsql
 STABLE
AS $function$
declare
	_type text;	
begin
	if _mode = 'IN' then
		_type = 'i';
	end if;

return query 
	select pn
	from(
		select _param_modes[i] as pm, _param_names[i] as pn
		from generate_series(1, cardinality(_param_names)) as i
	) as tt
	where tt.pm = _type or _param_modes is null;
end;
$function$
;


drop view tap_funky_ext;

create view tap_funky_ext as
select
	tf.oid,
	tf.schema,
	tf.name,
	tf.owner,
	tf.args,
	lower(coalesce(
		routine_info."returns",
		tf."returns"))                       AS "returns",
	tf.langoid,
	tf.is_strict,
	tf.kind,
	tf.is_definer,
	tf.returns_set,
	tf.volatility,
	tf.is_visible,
	l.lanname                                AS langname,
	format('(%s)',
		routine_info.args_with_defs
	)                                        AS args_with_defs,
	case 
		when nullif(routine_info.args_with_defs, '') is not null then
			format('raise notice ''%s'', %s;', 
				coalesce(param_names.placeholders, param.placeholders),
				param.dollars
			)
		else '' 
	end                                      as param_notice,
	param.dollars
from tap_funky tf
join pg_catalog.pg_proc p on p.oid = tf.oid
join pg_catalog.pg_namespace n ON p.pronamespace = n.oid
left join pg_catalog.pg_language l ON l.oid = p.prolang
left join lateral (
	select
		format('%1I.%2I', tf.schema, tf.name) as qualified
) routine_name on true
left join lateral (
	select
		case
			when lower(tf.schema) != 'pg_catalog'
				then _routineresult(concat(routine_name.qualified, '(', tf.args, ')'))
			else null
		end  collate "default" as "returns",
		case
			when lower(tf.schema) != 'pg_catalog'
				then _routineargsdefs(concat(routine_name.qualified, '(', tf.args, ')'))
			else null
		end  collate "default" as "args_with_defs"
) as routine_info on true
left join lateral (
	select 
		string_agg('$' || i, ', ') dollars,
		string_agg('%', ', ') placeholders
	from generate_series(1, p.pronargs) as i
) param on true
left join lateral (
	select string_agg(pn || ' = %', ', ') placeholders 
	from _param_of_mode(p.proargmodes, p.proargnames, 'IN') as pn
) param_names on true;


--this function creates a mock in place of a real function
create or replace function mock_func(
    _func_schema text
    , _func_name text
    , _func_args text
    , _return_set_value text default null
    , _return_scalar_value anyelement default null::text
	, _log_params bool default null
)
returns void
--creates a mock in place of a real function
 LANGUAGE plpgsql
AS $function$
declare
    _mock_ddl text;
    _func_result_type text;
    _func_qualified_name text;
    _func_language text;
	_returns_set bool;
	_variants text;
	_ex_msg text;
	_param_notice text;
	_dollars text;
begin
	--First of all, we have to identify which function we must mock. If there is no such function, throw an error.
	begin
	    select "returns", langname, returns_set, case when _log_params then param_notice else '' end, dollars
	    into strict _func_result_type, _func_language, _returns_set, _param_notice, _dollars
	    from tap_funky_ext
	    where "schema" = _func_schema
	        and "name" = _func_name
	        and args_with_defs = _func_args;
		exception when NO_DATA_FOUND or TOO_MANY_ROWS then
			select string_agg(E'\t - ' || format('%I.%I %s', "schema", "name", args_with_defs), E'\n')::text
			into _variants
			from tap_funky_ext
			where "name" = _func_name;
			_ex_msg = format('Routine %I.%I %s does not exist.',
				_func_schema, _func_name, _func_args) || E'\n' || 'Possible variants are:' || E'\n' ||
				coalesce(_variants, 'There is no such function in any schema');
            raise exception '%', coalesce(_ex_msg, 'Нет описания');
	end;
	--This is the case when we need to mock a function written in SQL.
	--But in order to be able to execute the mocking functionality, we need to have a function written in plpgsql.
	--That is why we create a hidden function which name starts with "__".
	if _func_language = 'sql' and _returns_set then
		_mock_ddl = format('
	        create function %1$I.__%2$I(_name text)
	             returns %3$s
	             language plpgsql
	        AS %4$sfunction%4$s
			begin
	            return query execute _query(_name);
			end;
	        %4$sfunction%4$s;',
			_func_schema/*1*/, _func_name/*2*/, _func_result_type/*3*/, '$'/*4*/);
	    execute _mock_ddl;
		_mock_ddl = format('
	        create or replace function %1$I.%2$I %3$s
	             returns %4$s
	             language plpgsql
	        AS %6$sfunction%6$s
			begin
				%7$s
	            return query select * from %1$I.__%2$I ( ''%5$s'' );
			end;
	        %6$sfunction%6$s;',
			_func_schema/*1*/, _func_name/*2*/, _func_args/*3*/, _func_result_type/*4*/,
			_return_set_value/*5*/, '$'/*6*/, _param_notice/*7*/);
	    execute _mock_ddl;
	end if;

	if _func_language = 'plpgsql' and _returns_set then
		_mock_ddl = format('
	        create or replace function %1$I.%2$I %3$s
	             returns %4$s
	             language plpgsql
	        AS %6$sfunction%6$s
			begin
				%7$s
	            return query execute _query( ''%5$s'' );
			end;
	        %6$sfunction%6$s;',
			_func_schema/*1*/, _func_name/*2*/, _func_args/*3*/, _func_result_type/*4*/,
			_return_set_value/*5*/, '$'/*6*/, _param_notice/*7*/);
	    execute _mock_ddl;
	end if;

	if not _returns_set then
		if _func_language = 'plpgsql' then
			_mock_ddl = format('
				create or replace function %1$I.%2$I %3$s
					RETURNS %4$s
					LANGUAGE %5$s
				AS %8$sfunction%8$s
					%9$s
					return %6$L::%7$s;
				%8$sfunction%8$s;',
				_func_schema/*1*/,  _func_name/*2*/, _func_args/*3*/, _func_result_type/*4*/,
				_func_language/*5*/, _return_scalar_value/*6*/, pg_typeof(_return_scalar_value)/*7*/, '$'/*8*/,
				_param_notice/*9*/);
			execute _mock_ddl;
		else
			_mock_ddl = format('
				create function %1$I.__%2$I %3$s
					returns %4$s
					language plpgsql
				AS %5$sfunction%5$s
				begin
					%6$s
					return %7$L::%8$s;
				end;
				%5$sfunction%5$s;',
				_func_schema/*1*/, _func_name/*2*/, _func_args/*3*/, _func_result_type/*4*/, '$'/*5*/, _param_notice/*6*/,
				_return_scalar_value/*7*/, pg_typeof(_return_scalar_value)/*8*/);
			execute _mock_ddl;
			_mock_ddl = format('
				create or replace function %1$I.%2$I %3$s
					RETURNS %4$s
					LANGUAGE %5$s
				AS %6$sfunction%6$s
					select %1$I.__%2$I (%7$s);
				%6$sfunction%6$s;',
				_func_schema/*1*/,  _func_name/*2*/, _func_args/*3*/, _func_result_type/*4*/,
				_func_language/*5*/, '$'/*6*/, _dollars/*7*/);
			execute _mock_ddl;
		end if;
	    execute _mock_ddl;
	end if;
end $function$;
