# pgSQLMock 1.0.1

Welcome to the pgSQLMock wiki!

pgSQLMock is a PostgreSQL extension which extends the highly popular unit testing framework pgTap designed to provide mocking and faking capabilities similar to those found in many modern high-level programming languages. Please, see more details at wiki page. Regarding pgTap details are [here](https://github.com/theory/pgtap).

pgTap described [here](https://testanything.org)

Mocking, faking and making your test independent
================================================

**First of all! The functionality described below could by used in pgTap context only. It really does ALTER and DROP which are rolled back by pgTap.**

Examples of implementing mocking and faking functionality can be found [`on GitHub`](https://github.com/v-maliutin/pgtap/tree/examples_forking_and_mocking/examples).

**How to install**

Install pgTap then

```sh
make
make install
make installcheck
...

Then execute the following command in the database where you want to install pgSQLMock


    CREATE EXTENSION pgSQLMock;

If you need to install pgSQLMock into a specific schema do the following

    CREATE EXTENSION pgSQLMock SCHEMA my_own_schema;

**Dependencies**

pgSQLMock requires PostgreSQL 9.1 or higher and pgTap 1.3.4 or higher.

Faking
------

Let's say we have a main table and a subordinate table.

    CREATE TABLE parent(
        some_id int primary key
    );

    CREATE TABLE child(
        parent_id int,
        some_data numeric,
        CONSTRAINT child_fk FOREIGN KEY(parent_id) REFERENCES parent(some_id)
    );

    --Your function simply sums up the values of the some_data column, filtering them by the master_id field.

    SELECT SUM(some_data) as sm FROM child WHERE parent_id = $1;

The main point here is that the parent table is intended exclusively for user input,
and you cannot make any assumptions about the values stored in the some_id field.
Consequently, you will not be able to insert any data into the child table until
the corresponding data exists in the parent table.

What you can do is drop the foreign key constraint, insert some data into the child table only,
and perform any necessary checks.

Please, do not worry that you've lost the relationship between tables and thus compromised relational integrity.
It's always well known which data are invalid for your system. Simply don't insert them. That's it.

### `fake_table()` ###

    PERFORM fake_table( :_table_ident, :_make_table_empty, :_leave_primary_key, :_drop_not_null, :_drop_collation, :_drop_partitions );
    PERFORM fake_table( :_table_ident, :_make_table_empty, :_leave_primary_key, :_drop_not_null, :_drop_collation );
    PERFORM fake_table( :_table_ident, :_make_table_empty, :_leave_primary_key, :_drop_not_null );
    PERFORM fake_table( :_table_ident, :_make_table_empty, :_leave_primary_key );
    PERFORM fake_table( :_table_ident, :_make_table_empty );
    PERFORM fake_table( :_table_ident );

**Parameters**

`:_table_ident`
: Text array of tables to be faked in the format 'my_schema.my_table'. Required.

`:_make_table_empty`
: Boolean. If TRUE the desired tables will be truncated. Optional. FALSE by default.

`:_leave_primary_key`
: Boolean. TRUE if you want primary key stay as is. Optional. FALSE by default.

`:_drop_not_null`
: Boolean. TRUE if you want not null constraints stay as is. Note! It does not work for generated as identity columns. Optional. FALSE by default.

`:_drop_collation`
: Boolean. Not yet implemented. Optional. FALSE by default.

`:_drop_partitions`
: Boolean. If TRUE any declarative partition of a table will be dropped. Works starting with PostgreSQL version 10.
Optional. FALSE by default.

Sometimes a table contains a lot of junk data, especially in a development environment.
However, to ensure that your test runs on completely valid data, you clear the table before testing,
insert valid data, and then run the check. This is why the _make_table_empty parameter is useful.
If you follow the steps outlined above, you can be assured that your test does not rely on
junk data and can be reproduced at any time. Example.

    perform fake_table(
        _table_ident => '{pgconf.account, pgconf.analytic, pgconf.osv, pgconf.transactions}'::text[],
        _make_table_empty => true,
		_leave_primary_key => false,
        _drop_not_null => false,
        _drop_collation => false
    );

 One note. The parameters `_leave_primary_key` and `_drop_not_null` are currently contradictory.
 If you'd like to keep a primary key while making all columns nullable
 `(_leave_primary_key => true, _drop_not_null => true)`, you'll receive a runtime error.
 This depends on whether the table truly has a primary key. I'm addressing this issue, but meanwhile,
 the solution is to set `_leave_primary_key => false`, `_drop_not_null => true`, and then immediately
 following the execution of 'fake_table', simply execute a command to create your primary key,
 e.g., alter table my_table add constraint...

 In general, it's important to remember that there's no way to create a primary key consisting
 of nullable columns. Furthermore, when creating a primary key across multiple columns,
 PostgreSQL automatically enforces a NOT NULL constraint on each one.

Mocking
-------

Imagine a situation where you have one function that is called by another function.
The first function (the inner one) has complex logic and depends on multiple tables.
The second function (the outer one) simply performs a few actions using the result
returned by the first function. Should you populate tables required for the inner function
with test case data for every test scenario when testing the outer function? Goog news you shouldn't.
Simply create a mock for each test scenario and invoke it like a regular inner function.
The mock will bear the same name as your inner function, but will act instead of your real function.

    CREATE OR REPLACE FUNCTION pgconf.time_machine_now()
    RETURNS time
    LANGUAGE sql
    AS $$
        SELECT now()::time;
    $$;

    PERFORM mock_func('pgconf', 'time_machine_now', '()'
        , _return_scalar_value => '13:00'::time);

On the script above you can see how to create a mock for the 'time_machine_now()' function.
In production 'time_machine_now()' will return the current time. In test, if function has been mocked,
it will return 13:00 always. This is a scalar mock.

Another mock you can do is a return set mock with sql string.

    CREATE OR REPLACE FUNCTION pgconf.time_machine_now()
    RETURNS TABLE ( t time )
    LANGUAGE sql
    AS $$
        SELECT now()::time;
    $$;

    PERFORM tap.mock_func('pgconf', 'time_machine_now', '()'
        , _return_set_value => 'select ''13:00''::time as t');

 And my favorite case is

 	PREPARE mock_time_machine_now AS SELECT '14:00'::time AS t;
    PERFORM tap.mock_func('pgconf', 'time_machine_now', '()'
        , _return_set_value => 'mock_time_machine_now');

### `mock_func()` ###

    PERFORM mock_func( :_func_schema, :_func_name, :_func_args, _return_scalar_value );
    PERFORM mock_func( :_func_schema, :_func_name, :_func_args, _return_set_value );
    PERFORM mock_func( :_func_schema, :_func_name, :_func_args );

**Parameters**

`:_func_schema`
: Text. This is the schema where your function is declared. Required.

`:_func_name`
: Text. Function name. Required.

`:_func_args`
: Text. PG supports something similar to polymorphism. That’s why you always have to provide
a specific signature. This way PG will be able to find the function you want to mock.
If there are no parameters, just give '()'.
But if your function has some parameters, you must specify them as follows:
(_int_param int, _text_param text = null, _ts_param = now()).
The simplest way to find correct signature of your function is to call get_routine_signature. It is required.

':_return_scalar_value'
: Text. Some scalar value that your mock have to return in test context. Optional. Default NULL.
Obviously, you have to provide either '_return_set_value' or '_return_scalar_value'.

':_return_set_value'
: Text. Some SQL code forming a dataset that your mock should return in text context.
You may provide a name for a prepared statement. There is a convention to name a prepared statement
using the following pattern: 'mock_my_dataset'. Optional. Default NULL.
Obviously, you have to provide either '_return_set_value' or '_return_scalar_value'.

### `get_routine_signature()` ###

    PERFORM get_routine_signature( :_routine_schema, :_routine_name );
    PERFORM get_routine_signature( :_routine_name );

**Parameters**

`:_routine_schema`
: Text. This is the schema where your routine is declared. Required.

`:_func_name`
: Text. Routine name. Required.

The simple way to find out how PostgreSQL stores the signature of your routine.
Use this function to select at least the arguments with defaults ('args_with_defs') to pass this value to 'mock_func'.

### `mock_view()` ###

    PERFORM mock_func( :_view_schema, :_view_name, :_return_set_sql );

**Parameters**

`:_view_schema`
: Text. This is the schema where your view is declared. Required.

`:_view_name`
: Text. View name. Required.

`:_return_set_sql`
: Text. Some SQL code forming a dataset that your mock should return in text context. Required.

Creates a mock replacement for a real view. See more details about mocking above regarding the 'mock_func' function.

Assert to controls count of calls
---------------------------------

### `call_count()` ###

    SELECT call_count( :_call_count, :_func_schema, :_func_name, :_func_args );

To be able to gather a count on function calls, please ensure that the track_functions setting is set to 'all'.

**Parameters**

`:_call_count`
: Int. How many calls you are expecting. Required.

`:_func_schema`
: Text. This is the schema where your function is declared. Required.

`:_func_name`
: Text. Function name. Required.

`:_func_args`
: Text. PG supports something similar to polymorphism. That’s why you always have to provide
a specific signature. This way PG will be able to find the function you want to mock.
If there are no parameters, just give '()'.
But if your function has some parameters, you must specify them as follows:
(_int_param int, _text_param text = null, _ts_param = now()). It is required.

Helping functions
-----------------

### `print_table_as_json()` ###

The greatest feature of pgTap is that every test run happens within its own transaction. That's awesome,
but it complicates tracking what's happening internally. Therefore, by calling the 'print_table_as_json'
function, you'll be able to see what data was present in a table (or query) at the time the test was running.

**Parameters**

`:_table_schema`
: Text. This is the schema where your table is declared. Required.

`:_table_name`
: Text. Table name. Required.

In the current version, all we need to do is create a table using some SQL statements in a certain schema
and pass the table and schema names to the function. The function will then issue a 'RAISE NOTICE' command
containing SQL code that you can copy-paste and execute. The result will appear as a regular table.
If you work in DBeaver look result of 'RAISE NOTICE' command in Output window.

### `print_query_as_json()` ###

It performs precisely the same action as 'print_table_as_json', except you don't have to create a table.
Simply prepare a statement and supply its name to the function.
It's a great idea that you can inspect any data you're working with during testing.
Simply construct a query returning your variables, settings, or any other relevant information,
and output them via the 'print_query_as_json' function.

**Parameters**

`:_statements`
: Text. This is the name of the prepared statement whose data you're looking to explore. Required.

### `drop_prepared_statement()` ###

Any prepared statement is a session-level object. Thus, if you reuse the same names across tests,
similar to my approach, you must remove previously created prepared statements before you can use it again.
It's advisable to leverage the 'setup' and 'teardown' features provided by pgTap.

**Parameters**

`:_statements`
: Array of text. Those are names of the prepared statements you want to drop. Required.

Compatibility
=============

Here are some notes on how pgSQLMock is built for particular versions of
PostgreSQL. This helps you to understand any side-effects. To see the specifics
for each version of PostgreSQL, consult the files in the `compat/` directory in
the pgTAP distribution.

10 and Up
---------

No changes. Everything should just work.

Metadata
========

Public Repository
-----------------

The source code for pgSQLMock is available on
[GitHub](https://github.com/v-maliutin/pgSQLMock/). Please feel free to fork and
contribute!

Mail List
---------

Join the pgTAP community by subscribing to the
[pgsqlmock-users mail list](https://groups.google.com/g/pgsqlmock-users).
All questions, comments, suggestions, and bug reports are welcomed there.

Author
------

[Slava Maliutin](https://)

Credits
-------

* David E. Wheeler for pgTap and reviews.

Copyright and License
---------------------

Copyright (c) 2024-2026 Slava Maliutin. Some rights reserved.

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose, without fee, and without a written agreement is
hereby granted, provided that the above copyright notice and this paragraph
and the following two paragraphs appear in all copies.

IN NO EVENT SHALL SLAVA MALIUTIN BE LIABLE TO ANY PARTY FOR DIRECT,
INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST
PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN
IF SLAVA MALIUTIN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

SLAVA MALIUTIN SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS,
AND SLAVA MALIUTIN HAS NO OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT,
UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
