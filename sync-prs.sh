#!/bin/bash

# Configuration file path
CONFIG_FILE="branch-sync-config.json"

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Function to get destination branches for a given source branch
get_destinations() {
    local source=$1
    # Use python for more reliable JSON parsing
    for py in "python3.13" "python3" "python"; do
        result=$($py -c "import json, sys; config = json.load(open('$CONFIG_FILE')); print('\n'.join(config['sync_rules'].get('$source', [])))" 2>/dev/null)
        if [ $? -eq 0 ] && [ ! -z "$result" ]; then
            echo "$result"
            return 0
        fi
    done
    return 1
}

# The GitHub URL for your repository
REPO_URL="https://github.com/eprabhu/Fibi-Release-Sync"

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "Current Branch: $CURRENT_BRANCH"

# Fetch destinations from config
DESTINATIONS=$(get_destinations "$CURRENT_BRANCH")

if [ -z "$DESTINATIONS" ]; then
    echo "No synchronization rules found for branch: $CURRENT_BRANCH"
    exit 0
fi

echo "Found destination branches for $CURRENT_BRANCH:"
echo "$DESTINATIONS"

# First, ensure your current branch is pushed to origin
echo "Syncing $CURRENT_BRANCH with origin..."
git push origin "$CURRENT_BRANCH"

# Loop through destinations and generate PR links
for DEST in $DESTINATIONS; do
    echo "----------------------------------------------------------"
    echo "Checking synchronization: $CURRENT_BRANCH -> $DEST"
    
    # Check if there are changes to sync between the branches on origin
    git fetch origin > /dev/null 2>&1
    DIFF_COUNT=$(git rev-list --count "origin/$DEST..origin/$CURRENT_BRANCH")
    
    if [ "$DIFF_COUNT" -eq 0 ]; then
        echo "No new changes to sync from origin/$CURRENT_BRANCH to origin/$DEST. Skipping..."
        continue
    fi

    echo "New commits detected: $DIFF_COUNT"

    # GENERATE THE PR LINK
    # The format is: REPO_URL/compare/BASE...HEAD
    # We replace spaces with %20 for the URL
    TITLE="Sync: $CURRENT_BRANCH to $DEST"
    BODY="Automated sync of $DIFF_COUNT commits from $CURRENT_BRANCH."
    
    # Simple URL encoding for title and body (replaces space with +)
    ENCODED_TITLE=$(echo "$TITLE" | sed 's/ /+/g')
    ENCODED_BODY=$(echo "$BODY" | sed 's/ /+/g')

    PR_LINK="$REPO_URL/compare/$DEST...$CURRENT_BRANCH?expand=1&title=$ENCODED_TITLE&body=$ENCODED_BODY"

    echo "Link generated for $DEST:"
    echo "$PR_LINK"
    
    # Automatically open the browser on Windows (where you are)
    echo "Opening your browser to create the PR..."
    start "$PR_LINK" 2>/dev/null || open "$PR_LINK" 2>/dev/null

done

echo "----------------------------------------------------------"
echo "Sync script execution completed."
