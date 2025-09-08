#!/bin/sh
echo "host replication $POSTGRES_USER 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf"

# Add PMM user access configuration
echo "# PMM monitoring access" >> "$PGDATA/pg_hba.conf"
echo "local   all             pmm                                md5" >> "$PGDATA/pg_hba.conf"
echo "host    all             pmm             0.0.0.0/0          md5" >> "$PGDATA/pg_hba.conf"
echo "host    all             pmm             ::0/0              md5" >> "$PGDATA/pg_hba.conf"

echo "PMM user access added to pg_hba.conf"
