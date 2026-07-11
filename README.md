# pgSQLMock 1.0.1

pgSQLMock is a PostgreSQL extension which extends the highly popular unit testing framework pgTap designed to provide mocking and faking capabilities similar to those found in many modern high-level programming languages. Please, see more details at wiki page. Regarding pgTap details are [here](https://github.com/theory/pgtap).

**How to install**

Install pgTap then

```sh
make
make install
make installcheck
```

Then execute the following command in the database where you want to install pgSQLMock


    CREATE EXTENSION pgSQLMock;

If you need to install pgSQLMock into a specific schema do the following

    CREATE EXTENSION pgSQLMock SCHEMA my_own_schema;

**Dependencies**

pgSQLMock requires PostgreSQL 9.1 or higher and pgTap 1.3.4 or higher.


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
