#!/usr/bin/env bash

# This script is designed to make the rebuilding of my personal NixOS config much easier
# To view that NixOS config, go to my nixConfig repository
# The nixvim being referred to below is my Nix-based Neovim config, viewable within my nvimConfig repository

# TODO: Move this into my nixConfig using writeShellScriptBin

# Step -1: Check to make sure that any necessary packages are installed
missingDependencies=0
if [ ! "$(command -v getopts 2> /dev/null)" ]; then
  echo "ERROR: getopts not found"
  ((missingDependencies++))
fi
if [ ! "$(command -v git 2> /dev/null)" ]; then
  echo "ERROR: git not found"
  ((missingDependencies++))
fi
if [ ! "$(command -v home-manager 2> /dev/null)" ]; then
  echo "ERROR: home manager not found"
  ((missingDependencies++))
fi
if [ ! "$(command -v nix 2> /dev/null)" ]; then
  echo "ERROR: nix not found"
  ((missingDependencies++))
fi
if [ ! "$(command -v nh 2> /dev/null)" ]; then
  echo "ERROR: nh not found"
  ((missingDependencies++))
fi
if [ ! "$(command -v alejandra 2> /dev/null)" ]; then
  echo "ERROR: alejandra not found"
  ((missingDependencies++))
fi
if [ "$missingDependencies" -gt 0 ]; then
  echo "Missing dependencies: $missingDependencies"
  exit 1
fi

# Step 0: Handle flags and set path variable
upgradeFlakeLock=""
upgradeNixvim=""
noAutoFormat=""
updateHome=""
updateOS=""
updateFirmware=""
dryUpdate=""
cleanUpdate=""
while getopts "unfhoFdc" flag; do
  case "$flag" in
    u)  # Update flake.lock
      upgradeFlakeLock="1"
      ;;
    n)  # Update just the nixvim input in flake.lock
      upgradeNixvim="1"
      ;;
    f) # DON'T auto format
      noAutoFormat="1"
      ;;
    h)  # Update home manager
      updateHome="1"
      ;;
    o)  # Update the OS
      updateOS="1"
      ;;
    F)  # Update firmware
      updateFirmware="1"
      ;;
    d)  # Do a dry update
      dryUpdate="1"
      ;;
    c)  # Clean the system
      cleanUpdate="1"
      ;;
    *)  # There was an option that doesn't exist
      echo "You've used a flag that doesn't exist. Exiting program with failure"
      exit 1
      ;;
  esac
done

cwd="$(pwd)"
pattern="/nixConfig/[^/]+"
if grep -qE "$pattern" <<< "$cwd"; then
  path=$(sed -E "s~($pattern).*~\1~" <<< "$cwd")
else
  path="$NIX_CONFIG_PATH/nixConfig-main"
fi

export FLAKE="$path"

# Step 1: cd to the correct file location
cd "$path" || (echo "cd failed for some reason" && exit 1)
# Error handling: Ensure there is a flake.nix here
if [ ! -f "flake.nix" ] || { [ ! -d ".git" ] && [ ! -f ".git" ]; }; then
  echo "There's no flake.nix and/or git repo in $path, dumbass"
  cd "$cwd" || exit 1
  exit 1
fi

# Step 2: Upgrade flake.lock/nixvim?
if [ "$upgradeFlakeLock" ] && [ ! "$updateOS" ] && [ ! "$updateHome" ]; then
  nix flake update
elif [ "$upgradeNixvim" ]; then
  nix flake update nixvim-config
fi

if [ "$upgradeFlakeLock" ] || [ "$upgradeNixvim" ]; then
  cd "$HOME/Documents/Configs/nvimConfig/nvimConfig-main" || (echo "cd into nvimConfig failed for some reason" && exit 1)
  alejandra .
  nix flake update
  if [ -n "$(git diff HEAD -- flake.lock)" ]; then
    git reset HEAD -- .
    git add ./flake.lock
    git commit -m "Update flake.lock through gas script"
    git push
  fi
  cd "$path" || (echo "cd out of nvimConfig failed for some reason" && exit 1)
fi

# Step 3: Add to git stage
git add .

# Step 4: Auto-formatting
if [ "$noAutoFormat" ]; then
  echo "Skip auto-formatting"
else
  echo "Auto-formatting .nix files"
  alejandra .
fi

# Step 5: Rebuild Home Manager
if [ "$updateHome" ]; then
  homeString="nh home switch"

  # Update flake.lock/nixvim
  if [ "$upgradeFlakeLock" ]; then
    homeString="$homeString --update"
  elif [ "$upgradeNixvim" ]; then
    homeString="$homeString --update-input nixvim-config"
  fi

  if [ "$dryUpdate" ]; then
    homeString="$homeString --dry"
  else
    homeString="$homeString --backup-extension backup"
    if [ ! "$updateOS" ]; then
      homeString="$homeString --ask"
    fi
  fi
  homeString="$homeString --configuration $USERNAME@$FLAKE_HOSTNAME"
  $homeString
fi

# Step 6: Rebuild OS
if [ "$updateOS" ]; then
  osString="nh os switch"

  # Update flake.lock/nixvim
  if [ ! "$updateHome" ]; then
    if [ "$upgradeFlakeLock" ]; then
      osString="$osString --update"
    elif [ "$upgradeNixvim" ]; then
      osString="$osString --update-input nixvim-config"
    fi
  fi

  if [ "$dryUpdate" ]; then
    osString="$osString --dry"
  else
    osString="$osString --ask"
  fi
  osString="$osString --hostname $FLAKE_HOSTNAME"
  $osString
fi

# Step 7: Update firmware
if [ "$updateFirmware" ]; then
  fwupdmgr refresh
  fwupdmgr update
fi

# Step 7: Clean?
if [ "$cleanUpdate" ]; then
  nh clean all --ask --keep-since 7d --keep 10
  nix store optimise
fi

# Step 8: Go back and execute shell
# Shell is executed so that shell aliases and enviroment variables are reset
cd "$cwd" || exit 1
exec "$SHELL"
