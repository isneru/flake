#!/usr/bin/env bash

url="${QUTE_URL:?no URL in the environment}"
root="$HOME/repos"

say() {
  [[ -n ${QUTE_FIFO:-} ]] || return 0
  printf "message-%s '%s'\n" "$1" "${2//\'/}" >>"$QUTE_FIFO"
}

if [[ ! $url =~ ^https?://(www\.)?github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+) ]]; then
  say error "clone: not a github repository page"
  exit 1
fi
owner="${BASH_REMATCH[2]}"
repo="${BASH_REMATCH[3]%.git}"

case $owner in
about | account | apps | codespaces | collections | dashboard | enterprise | explore | features | issues | login | marketplace | new | notifications | orgs | pricing | pulls | search | settings | sponsors | topics)
  say error "clone: not a repository page"
  exit 1
  ;;
esac

dest="$root/$repo"

if [[ -d $dest/.git ]]; then
  say info "clone: opening $repo"
  setsid -f kitty --directory "$dest" -e nvim . >/dev/null 2>&1
  exit 0
fi

if [[ -e $dest ]]; then
  say error "clone: ~/repos/$repo already exists"
  exit 1
fi

mkdir -p "$root"
say info "clone: fetching $owner/$repo"

# shellcheck disable=SC2016
setsid -f bash -c '
  dest=$1 slug=$2
  if git clone --quiet "git@github.com:$slug.git" "$dest"; then
    notify-send -e -a qutebrowser "Cloned $slug" "$dest"
    kitty --directory "$dest" -e nvim .
  else
    notify-send -e -a qutebrowser -u critical "Clone failed" "$slug"
  fi
' _ "$dest" "$owner/$repo" >/dev/null 2>&1
