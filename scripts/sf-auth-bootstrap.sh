#!/usr/bin/env bash
set -euo pipefail

# Import SFDX/SF auth URLs from environment variables into the local keychain.
#
# Usage:
#   Export one or more environment variables in the form:
#     SFDX_AUTH_URL_<ALIAS>="<sfdxAuthUrl>"
#   Then run:
#     bash scripts/sf-auth-bootstrap.sh
#
# Notes:
# - Works with either the new `sf` CLI or legacy `sfdx` CLI.
# - Does not set any org as default; you can set defaults later as needed.
# - For a quick list after import, set SF_AUTH_LIST_AFTER=1 in the env.

# Detect CLI: prefer sf, fallback to sfdx
if command -v sf >/dev/null 2>&1; then
  CLI="sf"
elif command -v sfdx >/dev/null 2>&1; then
  CLI="sfdx"
else
  echo "Error: Salesforce CLI (sf or sfdx) not found in PATH." >&2
  exit 1
fi

prefix="SFDX_AUTH_URL_"
exported=$(env | grep "^${prefix}" || true)
if [ -z "$exported" ]; then
  echo "No SFDX auth URL env vars found. Export one or more as ${prefix}<ALIAS>=<sfdxAuthUrl>" >&2
  exit 0
fi

echo "$exported" | while IFS= read -r line; do
  var="${line%%=*}"
  alias="${var#${prefix}}"
  url="${line#*=}"

  if [ -z "$url" ] || [ -z "$alias" ]; then
    echo "Skipping malformed entry: $line" >&2
    continue
  fi

  tmpfile="$(mktemp)"
  printf '%s\n' "$url" > "$tmpfile"

  echo "Importing auth for alias: $alias"
  if [ "$CLI" = "sf" ]; then
    sf org login sfdx-url --sfdx-url-file "$tmpfile" --alias "$alias" >/dev/null
  else
    sfdx auth:sfdxurl:store -f "$tmpfile" -a "$alias" >/dev/null
  fi

  rm -f "$tmpfile"
done

echo "Done importing SFDX auth URLs."

if [ "${SF_AUTH_LIST_AFTER:-0}" = "1" ]; then
  if [ "$CLI" = "sf" ]; then
    sf org list || true
  else
    sfdx force:org:list || true
  fi
fi
