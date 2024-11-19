---
title: database stuff
tags: Linux
---

___
# database backup

- store mysql datapase pass in ***/root/.my.cnf*** so our script can access it.
- Chmod 600 --> is the way to go

```sh
[client]
user=root
password=crazypass
```

## backup one user database
```sh
mysqldump --add-drop-table --databases yourdatabasename >  /home/<username>/backups/db/$(/bin/date +\%Y-\%M-\%D).sql.bak
```

## backup all databases
```sh
mysqldump --all-databases --all-routines > /path/to/fulldump.sql
```

## to restore single database
```sh
mysql -u root -p [database_name] < backup_database.sql
```
- 

## to restore all databases
```sh
mysql -u root -p < all_databases_backup.sql
```
- tables need to exist, or backup needs to contain CREATE TABLE statements