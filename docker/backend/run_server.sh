#!/bin/bash
# Start the Flask server for Diabetes Management Dashboard

echo "Starting Diabetes Management Dashboard Server..."
echo "=================================================="
echo

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 not found. Please install Python 3.8+"
    exit 1
fi

# Check if MySQL is running
if ! pgrep -x "mysqld" > /dev/null; then
    echo "⚠️  MySQL does not appear to be running"
    echo "   Start MySQL first: brew services start mysql (macOS)"
    echo "                     sudo systemctl start mysql (Linux)"
    exit 1
fi

# Check if database exists
if ! mysql -u root -e "USE project_554" 2>/dev/null; then
    echo "❌ Database 'project_554' not found"
    echo "   Please load the database first:"
    echo "   mysql -u root -p < ../sql_dump/project_554_complete.sql"
    exit 1
fi

echo "✅ MySQL is running"
echo "✅ Database 'project_554' found"
echo

# Start the server
echo "Starting Flask server on http://localhost:5001..."
python3 server_unified.py
