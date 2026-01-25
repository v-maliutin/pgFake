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
	format('raise notice ''%s'', %s;', 
		coalesce(param_names.placeholders, params.placeholders),
		params.dollars
	)                                        as raise_notice
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
) params on true
left join lateral (
	select string_agg(pn || ' = %', ', ') placeholders from unnest(p.proargnames) as pn
) param_names on true;
