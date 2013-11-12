postgres2node-orm
============

Description
-------------

Generate [node-orm2](https://github.com/dresende/node-orm2) models from a postgresql schema dump.

To obtain a database schema dump use `pg_dump --schema-only`

Usage
-------

```shell
perl postgres2node-orm.pl databaseDefinition.sql outputdir
```

Where `databaseDefinition.sql` is the schema dump and `outputdir` is an existing directory.

It generates one file per table, in the current format: `table_name.ts`

The extension is for TypeScript file, but you can edit easily the script to generate .js files (and changing TypeScript closure `() => ` with  JavaScript closure`function ()`).

Example
----------

In my dump I've got a table definiton like:

```SQL
CREATE TABLE users (
  id serial8 NOT NULL,
  stamp timestamp(0) WITH TIME ZONE NOT NULL DEFAULT NOW(),
  story json,
  private boolean NOT NULL DEFAULT FALSE,
  username varchar(90) NOT NULL,
  password varchar(40) NOT NULL,
  name varchar(60) NOT NULL,
  surname varchar(60) NOT NULL,
  email varchar(350) NOT NULL,
  board_lang varchar(2) DEFAULT NULL,
  timezone varchar(35) NOT NULL DEFAULT 'UTC',
  PRIMARY KEY (counter),
  CONSTRAINT usersLastCheck CHECK(EXTRACT(TIMEZONE FROM last) = '0') 
);
```

The output in `outputdir/users.ts` is
```TypeScript
import orm = require('orm');

module.exports = (db: orm.ORM, cb: (err?:Error) => void) => {
    db.define("users",
    /* definition */
    {
        id : { type: 'number', required: true, size: 8, rational: false},
        stamp : { type: 'date', required: true, time: true , defaultValue: "NOW()"},
        story : { type: 'object', required: false},
        private : { type: 'boolean', required: true, defaultValue: "FALSE"},
        username : { type: 'text', required: true, size: 90},
        password : { type: 'text', required: true, size: 40},
        name : { type: 'text', required: true, size: 60},
        surname : { type: 'text', required: true, size: 60},
        email : { type: 'text', required: true, size: 350},
        board_lang : { type: 'text', required: false, size: 2, defaultValue: "NULL"},
        timezone : { type: 'text', required: true, size: 35, defaultValue: "UTC"}    
    },
    /* options */
    {
        id: ['counter']
    });
    
    return cb();
};
```

In addition, the script will create a outputdir/index.ts in which there are present the load call for each table.
