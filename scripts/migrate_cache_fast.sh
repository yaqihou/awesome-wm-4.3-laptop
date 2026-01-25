#!/bin/bash

# Fast wallpaper cache migration using CSV + DuckDB
# Usage: ./migrate_cache_fast.sh

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_FILE="$HOME/.config/awesome/wallpaper-cache.csv"
SQLITE_DB="$HOME/.config/awesome/wallpaper-ratio-cache.sqlite3"
BACKUP_SUFFIX=".migrated.backup"

echo "Fast Wallpaper Cache Migration"
echo "=============================="
echo "Script directory: $SCRIPT_DIR"
echo "CSV file: $CSV_FILE"
echo "SQLite database: $SQLITE_DB"
echo ""

# Check if DuckDB is available
if ! command -v duckdb &> /dev/null; then
    echo "Error: DuckDB is not installed or not in PATH"
    echo "Please install DuckDB first:"
    echo "  - On Ubuntu/Debian: sudo apt install duckdb"
    echo "  - On macOS: brew install duckdb"
    echo "  - Or download from: https://duckdb.org/docs/installation/"
    exit 1
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed or not in PATH"
    echo "Please install Python 3 first"
    exit 1
fi

# Step 1: Convert text cache to CSV using Python + Polars (ultra-fast)
echo "Step 1: Converting text cache to CSV using Python + Polars..."
cd "$SCRIPT_DIR"
python3 convert_to_csv_fast.py

if [ $? -ne 0 ]; then
    echo "Error: Failed to convert cache to CSV"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file was not created"
    exit 1
fi

# Step 2: Create backup of existing SQLite database if it exists
if [ -f "$SQLITE_DB" ]; then
    echo ""
    echo "Step 2: Backing up existing SQLite database..."
    cp "$SQLITE_DB" "${SQLITE_DB}${BACKUP_SUFFIX}"
    echo "Backup created: ${SQLITE_DB}${BACKUP_SUFFIX}"
fi

# Step 3: Load CSV into SQLite using DuckDB
echo ""
echo "Step 3: Loading CSV into SQLite database using DuckDB..."

# Create a temporary SQL file with the correct paths
TEMP_SQL=$(mktemp)
sed "s|/home/yaqi/.config/awesome/wallpaper-cache.csv|$CSV_FILE|g; s|/home/yaqi/.config/awesome/wallpaper-ratio-cache.sqlite3|$SQLITE_DB|g" "$SCRIPT_DIR/load_csv_to_sqlite.sql" > "$TEMP_SQL"

duckdb < "$TEMP_SQL"

if [ $? -ne 0 ]; then
    echo "Error: Failed to load CSV into SQLite database"
    rm -f "$TEMP_SQL"
    exit 1
fi

rm -f "$TEMP_SQL"

# Step 4: Verify the migration
echo ""
echo "Step 4: Verifying migration..."

if [ ! -f "$SQLITE_DB" ]; then
    echo "Error: SQLite database was not created"
    exit 1
fi

# Count entries using DuckDB
ENTRY_COUNT=$(duckdb -c "ATTACH DATABASE '$SQLITE_DB' AS db (TYPE SQLITE); SELECT COUNT(*) FROM db.wallpaper_cache;")
echo "SQLite database contains $ENTRY_COUNT entries"

# Step 5: Cleanup CSV file (optional)
echo ""
echo "Step 5: Cleaning up..."
if [ -f "$CSV_FILE" ]; then
    echo "Removing temporary CSV file..."
    rm "$CSV_FILE"
fi

echo ""
echo "Migration completed successfully!"
echo "================================"
echo "SQLite database: $SQLITE_DB"
echo "Total entries: $ENTRY_COUNT"
echo ""
echo "You can now use the SQLite database in your AwesomeWM configuration."

if [ -f "${SQLITE_DB}${BACKUP_SUFFIX}" ]; then
    echo "Original database backup: ${SQLITE_DB}${BACKUP_SUFFIX}"
fi