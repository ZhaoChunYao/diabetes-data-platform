#!/bin/bash
# Quick verification script for final_submission package

echo "=========================================="
echo "Final Submission Package Verification"
echo "=========================================="
echo

# Check directory structure
echo "✓ Checking directory structure..."
for dir in dataset schema loaders backend frontend sql_dump docs; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir/"
    else
        echo "  ❌ $dir/ MISSING"
    fi
done
echo

# Check key files
echo "✓ Checking key files..."
files=(
    "USER_GUIDE.md"
    "README.md"
    "requirements.txt"
    "PACKAGE_SUMMARY.md"
    "backend/server_unified.py"
    "backend/run_server.sh"
    "frontend/index.html"
    "frontend/feature1.html"
    "frontend/feature2.html"
    "frontend/feature3.html"
    "frontend/feature4.html"
    "frontend/feature5.html"
    "schema/01_metadata_tables.sql"
    "schema/02_daily_aggregates.sql"
    "schema/03_timeseries_tables.sql"
    "loaders/master_loader.py"
    "sql_dump/project_554_complete.sql"
    "sql_dump/README.md"
    "dataset/README.md"
    "dataset/participants.tsv"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        size=$(ls -lh "$file" | awk '{print $5}')
        echo "  ✅ $file ($size)"
    else
        echo "  ❌ $file MISSING"
    fi
done
echo

# Check SQL dump size
echo "✓ Checking SQL dump..."
if [ -f "sql_dump/project_554_complete.sql" ]; then
    size=$(ls -lh sql_dump/project_554_complete.sql | awk '{print $5}')
    echo "  ✅ SQL dump size: $size"
    if [ "$size" == "1.4G" ] || [ "$size" == "1.5G" ]; then
        echo "  ✅ Size looks correct"
    else
        echo "  ⚠️  Size may be incorrect (expected ~1.4G)"
    fi
else
    echo "  ❌ SQL dump not found"
fi
echo

# Check dataset symlink
echo "✓ Checking dataset..."
if [ -L "dataset/processed" ]; then
    echo "  ✅ Processed data symlink exists"
    target=$(readlink dataset/processed)
    echo "  → Points to: $target"
else
    echo "  ⚠️  No symlink (dataset may be copied directly)"
fi
echo

# Count frontend files
echo "✓ Counting files..."
html_count=$(find frontend -name "*.html" | wc -l)
echo "  HTML files: $html_count"

# Check documentation
doc_size=$(wc -l USER_GUIDE.md | awk '{print $1}')
echo "  USER_GUIDE.md lines: $doc_size"
echo

# Summary
echo "=========================================="
echo "Verification Complete!"
echo "=========================================="
echo
echo "Next steps:"
echo "1. Import database: mysql -u root -p < sql_dump/project_554_complete.sql"
echo "2. Install deps: pip3 install -r requirements.txt"
echo "3. Start server: cd backend && python3 server_unified.py"
echo "4. Open browser: http://localhost:5001"
echo
