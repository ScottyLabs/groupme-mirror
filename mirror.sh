#!/usr/bin/env bash

# File to store the last processed message ID
STATE_FILE="${STATE_DIRECTORY:-/var/lib/groupme-mirror}/last_id"
mkdir -p "$(dirname "$STATE_FILE")"

# Get the last ID or default to 0
LAST_ID=$(cat "$STATE_FILE" 2>/dev/null || echo "0")

# Parse new non-system messages
RESPONSE=$(curl -s "https://api.groupme.com/v3/groups/$GROUP_ID/messages?token=$GROUPME_ACCESS_TOKEN&limit=20")

echo "$RESPONSE" | jq -c ".response.messages[] | select(.id > \"$LAST_ID\" and .system == false)" | tac | while read -r msg; do

    NAME=$(echo "$msg" | jq -r '.name')
    TEXT=$(echo "$msg" | jq -r '.text // ""')
    IMAGES=$(echo "$msg" | jq -r '.attachments[] | select(.type == "image") | .url')

    # Format and post
    CONTENT="**$NAME**: $TEXT"
    if [ -n "$IMAGES" ]; then
        CONTENT="$CONTENT\n$IMAGES"
    fi

    curl -H "Content-Type: application/json" \
         -d "$(jq -n --arg msg "$CONTENT" '{content: $msg}')" \
         "$DISCORD_WEBHOOK_URL"

    # Update the state file with the current message ID
    echo "$msg" | jq -r '.id' > "$STATE_FILE"

    sleep 1
done
