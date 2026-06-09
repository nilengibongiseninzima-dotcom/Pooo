#!/bin/bash
set -e

# Backup Script for ZA Server
# Usage: bash backup.sh <SERVER_IP> <BACKUP_DIR>

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: bash backup.sh <SERVER_IP> <BACKUP_DIR>"
    exit 1
fi

SERVER_IP=$1
BACKUP_DIR=$2
DATABASE_NAME="za_db"
APP_USER="appuser"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting backup from $SERVER_IP..."

# Create backup directory
mkdir -p $BACKUP_DIR/$TIMESTAMP

# Backup PostgreSQL
echo "Backing up PostgreSQL..."
ssh $APP_USER@$SERVER_IP "pg_dump -U postgres $DATABASE_NAME" > $BACKUP_DIR/$TIMESTAMP/database.sql

# Backup application files
echo "Backing up application files..."
rsync -avz $APP_USER@$SERVER_IP:/home/$APP_USER/app/ $BACKUP_DIR/$TIMESTAMP/app/

# Backup configuration
echo "Backing up configuration..."
rsync -avz $APP_USER@$SERVER_IP:/etc/ $BACKUP_DIR/$TIMESTAMP/etc/ || true

# Compress backup
echo "Compressing backup..."
tar -czf $BACKUP_DIR/backup_$TIMESTAMP.tar.gz -C $BACKUP_DIR $TIMESTAMP

# Cleanup
rm -rf $BACKUP_DIR/$TIMESTAMP

echo "Backup complete: $BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
