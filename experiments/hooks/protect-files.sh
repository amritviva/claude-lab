#!/bin/bash
# Hook: Block edits to protected files
# Event: PreToolUse (matcher: Edit|Write)
# stdin: JSON with tool_name and tool_input from Claude
# exit 0 = allow, exit 2 = block

# Step 1: Read the JSON that Claude slid under the door
INPUT=$(cat)

# Step 2: Extract the file path using jq
# "// empty" means: if file_path doesn't exist, return empty string (don't crash)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Step 3: If no file path found, let it through (shouldn't happen for Edit/Write)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Step 4: The protected list — add or remove patterns as needed
PROTECTED_PATTERNS=(
  ".env"
  "package-lock.json"
  "yarn.lock"
  ".git/"
  "credentials"
  "secrets"
  "id_rsa"
  "id_ed25519"
  ".pem"
)

# Step 5: Check if the file matches any protected pattern
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    # BLOCK — stderr goes back to Claude as an error message
    echo "BLOCKED: Cannot edit '$FILE_PATH' — matches protected pattern '$pattern'" >&2
    exit 2
  fi
done

# Step 6: Not protected — allow the edit
exit 0
