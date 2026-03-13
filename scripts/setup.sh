#!/usr/bin/env bash
# BudgetVault Tweet Scheduler Setup
# Creates a venv, installs dependencies, and prints cron instructions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "=== BudgetVault Tweet Scheduler Setup ==="
echo ""

# 1. Create virtual environment
if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment already exists at $VENV_DIR"
else
    echo "Creating virtual environment at $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
    echo "Done."
fi

# 2. Install dependencies
echo ""
echo "Installing dependencies (tweepy, python-dotenv) ..."
"$VENV_DIR/bin/pip" install --upgrade pip --quiet
"$VENV_DIR/bin/pip" install tweepy python-dotenv --quiet
echo "Done."

# 3. Verify the script can import
echo ""
echo "Verifying imports ..."
"$VENV_DIR/bin/python3" -c "import tweepy; from dotenv import load_dotenv; print('All imports OK')"

# 4. Check for .env file
echo ""
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo ".env file found."
else
    echo "WARNING: No .env file found."
    echo "  Copy .env.example to .env and add your Twitter API credentials:"
    echo "  cp $SCRIPT_DIR/.env.example $SCRIPT_DIR/.env"
fi

# 5. Make the scheduler executable
chmod +x "$SCRIPT_DIR/tweet_scheduler.py"

# 6. Print cron instructions
PYTHON_PATH="$VENV_DIR/bin/python3"
SCHEDULER_PATH="$SCRIPT_DIR/tweet_scheduler.py"
LOG_PATH="$SCRIPT_DIR/cron.log"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To set up the cron job, run:"
echo "  crontab -e"
echo ""
echo "Then add this line (runs every 15 minutes):"
echo "  */15 * * * * $PYTHON_PATH $SCHEDULER_PATH >> $LOG_PATH 2>&1"
echo ""
echo "To test manually:"
echo "  $PYTHON_PATH $SCHEDULER_PATH"
echo ""
echo "To check the posting log:"
echo "  cat $SCRIPT_DIR/tweet_log.json | python3 -m json.tool"
echo ""
