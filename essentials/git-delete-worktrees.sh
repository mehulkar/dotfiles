#!/usr/bin/env bash

set -euo pipefail

mapfile -t worktrees < <(git worktree list | awk '{print $1}' | tail -n +2)

if [ ${#worktrees[@]} -eq 0 ]; then
  echo "No worktrees found."
  exit 0
fi

to_delete=()

echo "Review worktrees:"
echo

for wt in "${worktrees[@]}"; do
  read -rp "Delete worktree '$wt'? [y/N]: " answer
  case "$answer" in
    [yY][eE][sS]|[yY])
      to_delete+=("$wt")
      ;;
  esac
done

echo
echo "Summary:"
for wt in "${to_delete[@]}"; do
  echo "  $wt"
done

if [ ${#to_delete[@]} -eq 0 ]; then
  echo "Nothing selected for deletion."
  exit 0
fi

read -rp "Proceed with deletion? [y/N]: " confirm
case "$confirm" in
  [yY][eE][sS]|[yY])
    echo
    echo "Deleting..."
    for wt in "${to_delete[@]}"; do
      git worktree remove "$wt"
    done
    echo "Done."
    ;;
  *)
    echo "Aborted."
    ;;
esac
