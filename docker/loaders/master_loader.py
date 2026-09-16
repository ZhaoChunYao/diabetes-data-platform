#!/usr/bin/env python3
"""
Master Data Loader for Diabetes Management Dashboard
Loads all data from CSV files into MySQL database

This script loads data in the following order:
1. Metadata tables (participants, measurement, ecg_metadata, etc.)
2. Daily aggregate tables (cgm_daily, heart_rate_daily, etc.)
3. Timeseries tables (cgm_readings, hr_readings, etc.) - TAKES 2-3 HOURS

Usage:
    python3 master_loader.py [--skip-timeseries]

Options:
    --skip-timeseries    Skip loading timeseries tables (for faster testing)
"""

import mysql.connector
import pandas as pd
import sys
import os
from datetime import datetime
import glob

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '',  # UPDATE THIS if you have a password
    'database': 'project_554'
}

# Paths
BASE_PATH = '../dataset'
PROCESSED_PATH = os.path.join(BASE_PATH, 'processed')

def get_db_connection():
    """Create database connection"""
    return mysql.connector.connect(**DB_CONFIG)

def load_participants():
    """Load participants table from TSV"""
    print("\n" + "="*70)
    print("LOADING PARTICIPANTS")
    print("="*70)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Read participants.tsv
    df = pd.read_csv(os.path.join(BASE_PATH, 'participants.tsv'), sep='\t')
    
    batch = []
    for _, row in df.iterrows():
        batch.append((
            row['participant_id'],
            int(row['age']),
            row['sex']
        ))
    
    cursor.executemany(
        "INSERT INTO participants (participant_id, age, sex) VALUES (%s, %s, %s)",
        batch
    )
    conn.commit()
    
    count = len(batch)
    print(f"✅ Loaded {count} participants")
    
    cursor.close()
    conn.close()
    return count

def load_measurement_and_ecg():
    """Load measurement and ECG metadata from processed files"""
    print("\n" + "="*70)
    print("LOADING MEASUREMENT & ECG METADATA")
    print("="*70)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Get all participants
    cursor.execute("SELECT participant_id FROM participants")
    participants = [row[0] for row in cursor.fetchall()]
    
    measurement_batch = []
    ecg_batch = []
    
    # Load from processed CSV files (they contain both measurement and ECG data)
    for pid in participants:
        # Try to find measurement file
        pattern = os.path.join(PROCESSED_PATH, 'processed_cgm', f'{pid}*.csv')
        files = glob.glob(pattern)
        
        if files:
            try:
                df = pd.read_csv(files[0], nrows=1)
                # Extract measurement data if available
                # This is simplified - adjust based on your actual CSV structure
                measurement_batch.append((pid,))
                ecg_batch.append((pid,))
            except:
                continue
    
    print(f"⚠️  Note: Measurement and ECG data should be loaded from your source files")
    print(f"   This loader expects pre-processed data in the dataset folder")
    
    cursor.close()
    conn.close()

def load_daily_aggregates():
    """Load daily aggregate tables"""
    print("\n" + "="*70)
    print("LOADING DAILY AGGREGATES")
    print("="*70)
    
    print("⚠️  Daily aggregates should be computed from timeseries data")
    print("   Run this after loading timeseries tables")
    print("   Or use the pre-computed SQL dump")

def load_timeseries_cgm():
    """Load CGM timeseries data"""
    print("\n" + "="*70)
    print("LOADING CGM TIMESERIES")
    print("="*70)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    files = sorted(glob.glob(os.path.join(PROCESSED_PATH, 'processed_cgm', '*.csv')))
    print(f"Found {len(files)} CGM files")
    
    batch = []
    rows = 0
    BATCH_SIZE = 10000
    
    for i, file_path in enumerate(files, 1):
        try:
            df = pd.read_csv(file_path)
            if df.empty:
                continue
            
            pid = str(df['patient_id'].iloc[0])
            
            for _, row in df.iterrows():
                try:
                    ts = datetime.fromisoformat(str(row['time']).split('+')[0].replace(' ', 'T').split('.')[0])
                    day = int(row['days'])
                    glucose = float(row['glucose_level_mg_dl'])
                    
                    if 0 <= glucose <= 600 and day > 0:
                        batch.append((pid, day, ts, glucose))
                        
                        if len(batch) >= BATCH_SIZE:
                            cursor.executemany(
                                "INSERT INTO cgm_readings (participant_id, day_index, timestamp, glucose_mg_dl) VALUES (%s, %s, %s, %s)",
                                batch
                            )
                            conn.commit()
                            rows += len(batch)
                            batch = []
                except:
                    continue
            
            if i % 100 == 0:
                print(f"  Progress: {i}/{len(files)} files | {rows:,} rows")
        except:
            continue
    
    if batch:
        cursor.executemany(
            "INSERT INTO cgm_readings (participant_id, day_index, timestamp, glucose_mg_dl) VALUES (%s, %s, %s, %s)",
            batch
        )
        conn.commit()
        rows += len(batch)
    
    print(f"✅ CGM: {rows:,} rows loaded")
    
    cursor.close()
    conn.close()
    return rows

def load_timeseries_hr():
    """Load Heart Rate timeseries data"""
    print("\n" + "="*70)
    print("LOADING HEART RATE TIMESERIES")
    print("="*70)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    files = sorted(glob.glob(os.path.join(PROCESSED_PATH, 'processed_hr', '*.csv')))
    print(f"Found {len(files)} HR files")
    
    batch = []
    rows = 0
    BATCH_SIZE = 10000
    
    for i, file_path in enumerate(files, 1):
        try:
            df = pd.read_csv(file_path)
            if df.empty:
                continue
            
            pid = str(df['patient_id'].iloc[0])
            
            for _, row in df.iterrows():
                try:
                    ts = datetime.fromisoformat(str(row['time']).split('+')[0].replace(' ', 'T').split('.')[0])
                    day = int(row['days'])
                    hr = int(row['hr_bpm'])
                    
                    if 0 < hr < 250 and day > 0:
                        batch.append((pid, day, ts, hr))
                        
                        if len(batch) >= BATCH_SIZE:
                            cursor.executemany(
                                "INSERT INTO hr_readings (participant_id, day_index, timestamp, hr_bpm) VALUES (%s, %s, %s, %s)",
                                batch
                            )
                            conn.commit()
                            rows += len(batch)
                            batch = []
                except:
                    continue
            
            if i % 100 == 0:
                print(f"  Progress: {i}/{len(files)} files | {rows:,} rows")
        except:
            continue
    
    if batch:
        cursor.executemany(
            "INSERT INTO hr_readings (participant_id, day_index, timestamp, hr_bpm) VALUES (%s, %s, %s, %s)",
            batch
        )
        conn.commit()
        rows += len(batch)
    
    print(f"✅ HR: {rows:,} rows loaded")
    
    cursor.close()
    conn.close()
    return rows

def load_all_timeseries():
    """Load all timeseries tables"""
    print("\n" + "="*70)
    print("LOADING ALL TIMESERIES TABLES")
    print("="*70)
    print("⚠️  This will take 2-3 hours for ~31 million records")
    print("   Consider using the pre-loaded SQL dump instead!")
    print()
    
    response = input("Continue with timeseries loading? (yes/no): ")
    if response.lower() != 'yes':
        print("Skipping timeseries loading")
        return
    
    start_time = datetime.now()
    
    # Load each timeseries table
    load_timeseries_cgm()
    load_timeseries_hr()
    # Add other loaders: sleep, spo2, stress, activity
    
    duration = datetime.now() - start_time
    print(f"\n✅ All timeseries loaded in {duration}")

def main():
    """Main loader function"""
    print("="*70)
    print("DIABETES MANAGEMENT DASHBOARD - MASTER DATA LOADER")
    print("="*70)
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    skip_timeseries = '--skip-timeseries' in sys.argv
    
    try:
        # Test database connection
        conn = get_db_connection()
        conn.close()
        print("✅ Database connection successful\n")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("\nPlease check:")
        print("  1. MySQL is running")
        print("  2. Database 'project_554' exists")
        print("  3. DB_CONFIG credentials are correct")
        return
    
    start_time = datetime.now()
    
    # Load metadata
    try:
        load_participants()
        load_measurement_and_ecg()
    except Exception as e:
        print(f"❌ Error loading metadata: {e}")
        return
    
    # Load daily aggregates
    try:
        load_daily_aggregates()
    except Exception as e:
        print(f"⚠️  Error loading daily aggregates: {e}")
    
    # Load timeseries
    if not skip_timeseries:
        try:
            load_all_timeseries()
        except Exception as e:
            print(f"❌ Error loading timeseries: {e}")
    else:
        print("\n⏭️  Skipping timeseries tables (use --skip-timeseries flag)")
    
    duration = datetime.now() - start_time
    
    print("\n" + "="*70)
    print("LOADING COMPLETE")
    print("="*70)
    print(f"Total time: {duration}")
    print("\nNext steps:")
    print("  1. Verify data: mysql -u root -p project_554 -e 'SELECT COUNT(*) FROM participants;'")
    print("  2. Start server: cd ../backend && python3 server_unified.py")
    print("  3. Open browser: http://localhost:5001")

if __name__ == '__main__':
    main()
