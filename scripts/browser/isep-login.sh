#!/usr/bin/env bash

lookup() {
  secret-tool lookup service isep-login field "$1"
}

store() {
  printf '%s' "$2" | secret-tool store --label="ISEP login ($1)" service isep-login field "$1"
}

if [ "${1:-}" = get ]; then
  user=$(lookup user)
  password=$(lookup password)
  printf '%s\n%s\n' "$user" "$password"
  exit
fi

read -rp "ISEP user: " user
read -rsp "ISEP password: " password
echo
store user "$user"
store password "$password"
echo "Stored in the keyring."
