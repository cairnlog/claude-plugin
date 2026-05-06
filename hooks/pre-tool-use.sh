#!/usr/bin/env bash
# CairnLog PreToolUse hook (plugin wrapper).
# Fail-soft: silently exit 0 if the CLI is not installed or not logged in.
# When authenticated, exec the cairnlog-hook-tool binary which evaluates
# the next tool call against active gates (allow / deny / ask / warn).

set -e

if ! command -v cairnlog-hook-tool >/dev/null 2>&1; then
  exit 0
fi

if [[ ! -f "${HOME}/.cairnlog/config.json" ]]; then
  exit 0
fi

exec cairnlog-hook-tool
