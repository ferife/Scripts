#!/usr/bin/env bash

# This script will help maintain my floorp profile settings after home-manager updates
# I have to do this because those settings have not been made to work yet completely through nix

# BEFORE RELOADING
# - create backup of currently existing profile
# - reload

# AFTER RELOADING
# - Confirm existence of backup profile
#   - If profile backup doesn't exist
#     - "ERROR: No existing profile backup"
#     - exit 1
#   - Else (does exist)
#     - Create backup of generated profile (just in case)
#     - Delete generated profile
#     - Replace with custom profile backup

backups_directory="$HOME/NEVER_DELETE/settings-backups/floorp-profiles"
profiles_directory="$HOME/.floorp"
autogen_profile_backups="nh-gen-backups"

# Function to do this
function sync_directories {
  local source_dir="$1"
  local target_dir="$2"
  local exclude_list=("native-messaging-hosts" "$autogen_profile_backups")

  for item in "$source_dir"/*; do
    if [ ! -d "$item" ]; then
      # Not a directory
      continue
    fi
    dir_name=$(basename "$item")
    for exclude_dir in "${exclude_list[@]}"; do
      if [ "$dir_name" = "$exclude_dir" ]; then
        # Skipping excluded directory
        continue 2
      fi
    done

    target="$target_dir/$dir_name"
    if [ -d "$target" ]; then
      # Name collision, removing old directory
      rm -rf "$target"
    fi

    # Copy from source to target
    cp -r "$item" "$target_dir/"
  done
}

# Flags
before=""
while getopts "b" flag; do
  case "$flag" in
    b)  # Before reloading
      before="1"
      ;;
    *)  # There was an option that doesn't exist
      echo "You've used a flag that doesn't exist. Exiting program with failure"
      exit 1
      ;;
  esac
done

if [ ! -d "$backups_directory" ]; then
  echo "ERROR: Backups Directory $backups_directory does not exist"
  exit 1
fi
if [ ! -d "$profiles_directory" ]; then
  echo "ERROR: Floorp Profiles Directory $profiles_directory does not exist"
  exit 1
fi

if [ -n "$before" ]; then
  # Before rebuild

  sync_directories "$profiles_directory" "$backups_directory"
else
  # After rebuild

  sync_directories "$profiles_directory" "$backups_directory/$autogen_profile_backups"

  if [ -z "$(ls -A "$backups_directory")" ]; then
    echo "ERROR: Backups Directory is Empty"
    exit 1
  fi

  sync_directories "$backups_directory" "$profiles_directory"
fi
