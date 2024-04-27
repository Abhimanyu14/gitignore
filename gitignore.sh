#!/bin/bash

# Record the start time
start_time=$(date +%s)

# List of directories to exclude the gitignore updation
excludedDirectories="gitignore/ private-files/ samples/"

# Change to root directory
cd ..

# Function to update gitignore for a single repository
update_gitignore() {
  
  local dir=$1

  # Change to that subdirectory
  cd $dir

  # Stash local changes
  git stash >/dev/null 2>&1

  # Checkout the main branch
  git checkout main >/dev/null 2>&1

  # Pull from the remote
  git pull origin main >/dev/null 2>&1

  if ! cmp -s .gitignore ../gitignore/.gitignore; then
    # Print the repositories for which gitignore is updated
    echo "$dir"

    # Remove current gitignore file
    rm .gitignore

    # Copy gitignore from the repo
    cp ../gitignore/.gitignore .

    # Add the updated gitignore file
    git add .gitignore >/dev/null 2>&1

    # Commit the changes
    git commit -m "[TECH] updated gitignore" >/dev/null 2>&1

    # Push the latest commits
    git push origin main >/dev/null 2>&1
  fi

  # Pop the stashed changes
  git stash pop >/dev/null 2>&1

  # Change back to the root directory
  cd ..
}

# Export the function to make it available to parallel
export -f update_gitignore

# Iterate over all directories
for dir in */; do

  # Skip directories in exclude directories
  if [[ ${excludedDirectories} != *"$dir"* ]];then

    # Run update_gitignore function in parallel for each directory
    update_gitignore "$dir" &
  fi
done

# Record the end time
end_time=$(date +%s)

# Calculate the duration
duration=$((end_time - start_time))

# Empty line
echo "
gitignore updated in ${duration} seconds!
"
