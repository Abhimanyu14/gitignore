#!/bin/bash

# List of directories to exclude the gitignore updation
excludedDirectories="private-files/ samples/"

# Change to root directory
cd ..

# Iterate over all directories
for dir in */; do

  # Skip directories in exclude directories
  if [[ ${excludedDirectories} != *"$dir"* ]];then

    # Change to that subdirectory
    cd $dir

    # Stash local changes
    git stash

    # Checkout the main branch
    git checkout main

    # Pull from the remote
    git pull origin main

    # Push the latest commits
    git push origin main

    # Pop the stashed changes
    git stash pop

    # Change back to the root directory
    cd ..
  fi
done
