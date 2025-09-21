#!/bin/bash
set -u

# Check if a command is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <command>"
    exit 1
fi

COMMAND="$1"  # The command to run
SUCCESS_COUNT=0
TOTAL_RUNS=3000

for ((i=1; i<=TOTAL_RUNS; i++)); do
    # Run the command and redirect both stdout and stderr to /dev/null
    { $COMMAND; } > /dev/null 2>&1
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        ((SUCCESS_COUNT++))
    fi
done

# Print the summary of SUCCESS_COUNT
echo "$COMMAND SUCCESS_COUNT: $SUCCESS_COUNT"

if [ $SUCCESS_COUNT -gt 100 ]; then
    exit 1
else
    exit 0
fi
