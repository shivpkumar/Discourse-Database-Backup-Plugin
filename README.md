Discourse-Database-Backup-Plugin
================================

Discourse plugin to automatically backup a non-AWS database daily

Assuming you've already setup a backup database on your machine, all you need to do is set the following environment variables:
- DB_BACKUP_HOST => the location of your host machine
- DB_BACKUP_DATABASE_NAME => the name of the database on your machine you'd like to backup
- DB_BACKUP_USERNAME => the username for the owner of the database
- DB_BACKUP_PASSWORD => the password for the owner of the database
