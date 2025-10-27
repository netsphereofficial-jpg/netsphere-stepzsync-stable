#!/bin/bash
# Script to clear the SQLite database and force recreation

echo "🗑️ Clearing SQLite database..."

# For iOS Simulator
xcrun simctl get_app_container booted com.health.stepzsync.stepzsync data 2>/dev/null | xargs -I {} rm -f "{}/Library/Application Support/step_tracking.db" 2>/dev/null

echo "✅ Database cleared! Restart the app to recreate with new schema."
