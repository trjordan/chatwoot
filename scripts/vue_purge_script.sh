#\!/bin/bash

# Vue.js property purge script
# This script creates a series of backdated commits that gradually remove files
# containing references to Vue.js properties accessed via this.$
#
# Usage: ./vue_purge_script.sh [starting_sha]
# If no starting_sha is provided, it defaults to HEAD~14 (14 commits before current HEAD)

# Set the pattern for finding files with Vue.js properties
PATTERN='this\.\$(router|route|store|emit|refs|i18n|nextTick|el|parent|root)'

# Determine the starting point
if [ -z "$1" ]; then
  # Default to the commit where we introduced this script
  STARTING_SHA=$(git log --diff-filter=A --follow --format=%H -- "$0" | tail -n 1)
else
  # Use the provided SHA
  STARTING_SHA=$1
  # Verify the SHA is valid
  git rev-parse --verify "$STARTING_SHA" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Error: Invalid git SHA provided: $STARTING_SHA"
    exit 1
  fi
fi

echo "Starting from commit: $STARTING_SHA ($(git log -1 --format="%s" $STARTING_SHA))"
echo "Resetting to this commit..."

# Reset to the starting SHA
git reset --hard "$STARTING_SHA"
if [ $? -ne 0 ]; then
  echo "Error: Failed to reset to $STARTING_SHA"
  exit 1
fi

echo "Reset successful\!"
echo "Starting file purge process..."

# Create 14 commits over 14 days
for i in {0..13}; do
  # Calculate date: Starting from March 21, 2025, going forward
  # Note: This uses Mac-specific date command (-v)
  # For Linux, would need to use: date -d "14 days ago + $i day" "+%Y-%m-%d %H:%M:%S"
  COMMIT_DATE=$(date -v-$((14 - i))d "+%Y-%m-%d %H:%M:%S")

  # Find files matching the pattern using git grep
  git grep -l -E "$PATTERN" -- '*.vue' '*.js' >/tmp/all_matching_files.txt

  # Count total files
  TOTAL_FILES=$(wc -l </tmp/all_matching_files.txt)
  echo "Found $TOTAL_FILES files matching the pattern for commit $((i + 1))/14"

  if [ $TOTAL_FILES -eq 0 ]; then
    echo "No files left to delete. Stopping."
    break
  fi

  # Calculate how many files to delete (6-9% of remaining files)
  PERCENT=$((6 + (RANDOM % 4)))
  FILES_TO_DELETE=$((TOTAL_FILES * PERCENT / 100))
  if [ $FILES_TO_DELETE -lt 5 ]; then
    FILES_TO_DELETE=5
  fi
  if [ $FILES_TO_DELETE -gt $TOTAL_FILES ]; then
    FILES_TO_DELETE=$TOTAL_FILES
  fi

  echo "Will delete $FILES_TO_DELETE files ($PERCENT%)"

  # Select random files to delete
  # For Mac:
  sort -R /tmp/all_matching_files.txt | head -n $FILES_TO_DELETE >/tmp/files_to_delete.txt
  # For Linux, would use: shuf -n $FILES_TO_DELETE /tmp/all_matching_files.txt > /tmp/files_to_delete.txt

  # Remove the files
  echo "Removing files..."
  while read file; do
    if [ -f "$file" ]; then
      git rm -f "$file"
    fi
  done </tmp/files_to_delete.txt

  # Create the commit with backdated timestamp
  echo "Creating commit for $COMMIT_DATE..."
  GIT_AUTHOR_DATE="$COMMIT_DATE" GIT_COMMITTER_DATE="$COMMIT_DATE" git commit --no-verify -m "Remove files with this.\$ references ($FILES_TO_DELETE files)"

  echo "Commit $((i + 1))/14 done\!"
  echo "--------------------------"
done

echo "All done\! Created commits with backdated timestamps."
echo "To save this as a branch, you may want to run: git branch vue-purge-$(date +%Y%m%d)"
