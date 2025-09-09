#!/bin/bash
echo "Setting up custom pg_hba.conf..."
cp /etc/pg_hba_custom.conf "$PGDATA/pg_hba.conf"
echo "Custom pg_hba.conf has been applied."
