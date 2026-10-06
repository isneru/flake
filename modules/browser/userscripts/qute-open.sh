#!/usr/bin/env bash

flags=()
while (($#)); do
  case $1 in
  --)
    shift
    break
    ;;
  -*) flags+=("$1") ;;
  *) break ;;
  esac
  shift
done
target="$*"

dev() {
  local rest=${1#*://}
  rest=${rest%%[/?#]*}
  rest=${rest##*@}
  [[ $rest == *" "* ]] && return 1
  [[ $rest =~ :[0-9]+$ ]] && return 0
  local host=${rest,,}
  host=${host#[}
  host=${host%]}
  case $host in
  localhost | *.localhost | *.local | *.test | ::1) return 0 ;;
  127.* | 10.* | 192.168.*) return 0 ;;
  esac
  [[ $host =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]
}

dev "$target" || flags+=(-s)
printf 'nop ;; open %s -- %s\n' "${flags[*]}" "$target" >>"$QUTE_FIFO"
