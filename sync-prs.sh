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

# Loop through destinations and create PRs
for DEST in $DESTINATIONS; do
    echo "----------------------------------------------------------"
    echo "Checking synchronization: $CURRENT_BRANCH -> $DEST"
    
    # Check if there are changes to sync between the branches on origin
    DIFF_COUNT=$(git rev-list --count "origin/$DEST..origin/$CURRENT_BRANCH")
    
    if [ "$DIFF_COUNT" -eq 0 ]; then
        echo "No new changes to sync from origin/$CURRENT_BRANCH to origin/$DEST. Skipping..."
        continue
    fi

    echo "New commits detected: $DIFF_COUNT"

    # Create the Pull Request via GitHub CLI
    # If gh-cli is not installed, it will print a manual link or useful error.
    echo "Creating Pull Request to $DEST..."
    gh pr create \
        --base "$DEST" \
        --head "$CURRENT_BRANCH" \
        --title "Sync: $CURRENT_BRANCH updates $DEST" \
        --body "Automated Pull Request from $CURRENT_BRANCH to $DEST summarizing recent changes." \
        --draft=false
    
    if [ $? -eq 0 ]; then
        echo "Successfully created PR for $DEST."
    else
        echo "Failed to create PR for $DEST. Make sure you have 'gh' installed and you are logged in (gh auth login)."
        echo "Alternatively, you can open it manually at: https://github.com/eprabhu/Fibi-Release-Sync/compare/$DEST...$CURRENT_BRANCH"
    fi

done

echo "----------------------------------------------------------"
echo "Sync script execution completed."
