#!/usr/bin/env bash
set -euo pipefail

# Debug mode: export SF_JWT_DEBUG=1 to enable bash tracing
if [ "${SF_JWT_DEBUG:-0}" = "1" ]; then
  set -x
fi

# Diagnose mode: set via env or flag
if [ "${1:-}" = "--diagnose" ]; then
  SF_JWT_DIAGNOSE=1
fi

# Print a small banner to confirm which script is running and its mtime
_script_path="$0"
if command -v readlink >/dev/null 2>&1; then
  _script_path="$(readlink -f "$0" 2>/dev/null || echo "$0")"
fi
echo "Using JWT script: $_script_path"
if [ "${SF_JWT_DIAGNOSE:-0}" = "1" ]; then
  echo "Diagnose mode: enabled (no auth will be attempted)"
fi
if command -v stat >/dev/null 2>&1; then
  if stat -c '%y' "$_script_path" >/dev/null 2>&1; then
    echo "Script modified: $(stat -c '%y' "$_script_path")"
  elif stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$_script_path" >/dev/null 2>&1; then
    echo "Script modified: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$_script_path")"
  fi
fi

# Authenticate to Salesforce orgs using JWT, driven by environment variables.
#
# Provide one or more sets of variables following this naming pattern:
#   SF_JWT_USERNAME_<ALIAS>      # Username of the integration user
#   SF_JWT_CLIENT_ID_<ALIAS>     # Connected App Consumer Key
#   SF_JWT_INSTANCE_URL_<ALIAS>  # https://login.salesforce.com | https://test.salesforce.com | https://<my-domain>.my.salesforce.com
#   SF_JWT_KEY_<ALIAS>           # Base64-encoded private key (recommended). If not base64, set SF_JWT_KEY_IS_B64_<ALIAS>=0
# Optional:
#   SF_JWT_SET_DEFAULT_<ALIAS>=1 # Set as default target org after login
#
# Usage:
#   Export the above variables (prefer Codespaces Secrets), then run:
#     bash scripts/sf-jwt-login.sh
#
# To limit to a single alias:
#   ONLY_ALIAS=myalias bash scripts/sf-jwt-login.sh

# Detect CLI: prefer sf, fallback to sfdx
if command -v sf >/dev/null 2>&1; then
  CLI="sf"
elif command -v sfdx >/dev/null 2>&1; then
  CLI="sfdx"
else
  echo "Error: Salesforce CLI (sf or sfdx) not found in PATH." >&2
  exit 1
fi

# Discover aliases via SF_JWT_CLIENT_ID_*
mapfile -t client_vars < <(env | grep '^SF_JWT_CLIENT_ID_' | cut -d= -f1 || true)

if [ ${#client_vars[@]} -eq 0 ]; then
  echo "No JWT env vars found. Define SF_JWT_CLIENT_ID_<ALIAS> et al. See docs/authentication.md." >&2
  exit 0
fi

mkdir -p "$HOME/.sf/keys"

for var in "${client_vars[@]}"; do
  alias="${var#SF_JWT_CLIENT_ID_}"

  if [ -n "${ONLY_ALIAS:-}" ] && [ "$alias" != "$ONLY_ALIAS" ]; then
    continue
  fi

  username_var="SF_JWT_USERNAME_${alias}"
  client_id_var="SF_JWT_CLIENT_ID_${alias}"
  instance_var="SF_JWT_INSTANCE_URL_${alias}"
  key_var="SF_JWT_KEY_${alias}"
  key_b64_flag_var="SF_JWT_KEY_IS_B64_${alias}"
  default_flag_var="SF_JWT_SET_DEFAULT_${alias}"

  # Read and trim whitespace/newlines from inputs
  username="${!username_var:-}"
  client_id="${!client_id_var:-}"
  instance="${!instance_var:-}"
  key_value="${!key_var:-}"
  # Trim with POSIX space class
  username="$(printf '%s' "$username" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  client_id="$(printf '%s' "$client_id" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  instance="$(printf '%s' "$instance" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  is_b64="${!key_b64_flag_var:-1}"
  set_default="${!default_flag_var:-0}"

  if [ -z "$username" ] || [ -z "$client_id" ] || [ -z "$instance" ] || [ -z "$key_value" ]; then
    echo "Skipping $alias: missing one or more variables: $username_var, $client_id_var, $instance_var, $key_var" >&2
    continue
  fi

  # Use a temp key path in diagnose mode to avoid persisting anything
  if [ "${SF_JWT_DIAGNOSE:-0}" = "1" ]; then
    key_path="$(mktemp)"
  else
    key_path="$HOME/.sf/keys/${alias}.key"
  fi
  if [ "$is_b64" = "1" ]; then
    echo "$key_value" | base64 -d > "$key_path" || {
      echo "Failed to base64-decode private key for $alias" >&2
      continue
    }
  else
    # Support raw env with escaped newlines ("\\n"). If present, convert to real newlines.
    if printf '%s' "$key_value" | grep -q '\\n'; then
      printf '%s' "$key_value" | sed -e 's/\\r\\n/\n/g' -e 's/\\n/\n/g' > "$key_path"
    else
      printf '%s\n' "$key_value" > "$key_path"
    fi
  fi
  chmod 600 "$key_path" || true

  # Normalize line endings and PEM header/footer formatting for raw keys
  if [ "$is_b64" != "1" ]; then
    # Remove CR from CRLF
    sed -i -e 's/\r$//' "$key_path" || true
    # Ensure header is on its own line (RSA and PKCS#8)
    sed -i -e '1 s/^\(-----BEGIN RSA PRIVATE KEY-----\)[[:space:]]\+/\1\n/' "$key_path" || true
    sed -i -e '1 s/^\(-----BEGIN PRIVATE KEY-----\)[[:space:]]\+/\1\n/' "$key_path" || true
    # Ensure footer is on its own line
    sed -i -e 's/[[:space:]]\+\(-----END RSA PRIVATE KEY-----\)/\n\1/g' "$key_path" || true
    sed -i -e 's/[[:space:]]\+\(-----END PRIVATE KEY-----\)/\n\1/g' "$key_path" || true
    # Rewrap body to 64 chars and strip stray spaces in body
    awk '
      BEGIN{inbody=0}
      /-----BEGIN (RSA )?PRIVATE KEY-----/ {print; inbody=1; next}
      /-----END (RSA )?PRIVATE KEY-----/ {print; inbody=0; next}
      {
        if (inbody==1) {
          gsub(/[\r\t ]+/, "", $0);
          line=$0;
          while (length(line) > 64) { print substr(line,1,64); line=substr(line,65); }
          if (length(line) > 0) print line;
        } else {
          print $0;
        }
      }
    ' "$key_path" > "$key_path.tmp" && mv "$key_path.tmp" "$key_path" || true
  fi

  # Quick sanity check on key header (do not print the key body)
  header_line="$(head -n 1 "$key_path" 2>/dev/null || true)"
  if [ -z "$header_line" ]; then
    echo "[FAIL] $alias: Private key file is empty. Check SF_JWT_KEY_$alias and base64 flag." >&2
    [ "${SF_JWT_DIAGNOSE:-0}" = "1" ] && rm -f "$key_path" && continue || continue
  fi
  case "$header_line" in
    *"BEGIN RSA PRIVATE KEY"*|*"BEGIN PRIVATE KEY"*)
      echo "[OK]   $alias: RSA private key detected"
      ;;
    *"BEGIN EC PRIVATE KEY"*)
      echo "[FAIL] $alias: EC key detected. RS256 requires an RSA private key. Generate with 'openssl genrsa 2048'." >&2
      [ "${SF_JWT_DIAGNOSE:-0}" = "1" ] && rm -f "$key_path" && continue || continue
      ;;
    *"BEGIN CERTIFICATE"*)
      echo "[FAIL] $alias: Certificate provided instead of PRIVATE KEY. Set SF_JWT_KEY_$alias to the PRIVATE KEY contents." >&2
      [ "${SF_JWT_DIAGNOSE:-0}" = "1" ] && rm -f "$key_path" && continue || continue
      ;;
    *)
      echo "[WARN] $alias: Unexpected key header: '$header_line'. Ensure an RSA PRIVATE KEY in PEM format." >&2
      ;;
  esac

  if [ "${SF_JWT_DIAGNOSE:-0}" = "1" ]; then
    # Report presence of required vars and exit this alias without logging in
    missing=0
    [ -z "$username" ] && echo "[FAIL] $alias: Missing $username_var" >&2 && missing=1
    [ -z "$client_id" ] && echo "[FAIL] $alias: Missing $client_id_var" >&2 && missing=1
    [ -z "$instance" ] && echo "[FAIL] $alias: Missing $instance_var" >&2 && missing=1
    if [ $missing -eq 0 ]; then
      echo "[OK]   $alias: username/clientId/instance present"
    fi
    echo "[INFO] $alias: instance=$instance base64_flag=$is_b64 default_flag=$set_default"
    rm -f "$key_path"
    continue
  fi

  echo "JWT login for alias: $alias (user: $username, host: $instance)"
  if [ "$CLI" = "sf" ]; then
    args=(org login jwt --username "$username" --client-id "$client_id" --jwt-key-file "$key_path" --instance-url "$instance" --alias "$alias")
    if [ "$set_default" = "1" ]; then
      args+=(--set-default)
    fi
    sf "${args[@]}" >/dev/null
  else
    args=(force:auth:jwt:grant -u "$username" -i "$client_id" -f "$key_path" -r "$instance" -a "$alias")
    sfdx "${args[@]}" >/dev/null
    if [ "$set_default" = "1" ]; then
      sfdx config:set defaultusername="$alias" >/dev/null
    fi
  fi

  echo "Logged in: $alias"
done

echo "JWT logins complete."
