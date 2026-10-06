#!/usr/bin/env bash

dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
touch "$dir/qute-reload"
