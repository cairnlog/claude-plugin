#!/usr/bin/env bash
# CairnLog UserPromptSubmit hook (plugin wrapper).
# Fail-soft: silently exit 0 if the CLI is not installed or not logged in.
# When authenticated, exec the cairnlog-hook-prompt binary which calls
# api.cairnlog.com and prepends [CairnLog Context] to the prompt.

set -e

if ! command -v cairnlog-hook-prompt >/dev/null 2>&1; then
  exit 0
fi

if [[ ! -f "${HOME}/.cairnlog/config.json" ]]; then
  exit 0
fi

exec cairnlog-hook-prompt
