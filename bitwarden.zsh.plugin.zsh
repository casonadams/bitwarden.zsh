# Constants
__BW_CACHE_FILE="/tmp/.bw_items_cache.json"
__BW_CACHE_SESSION="/tmp/.bw_session"
__BW_CACHE_MAX_AGE=21600  # 6 hours

# Print to stderr
__err() {
  print -r -- "$@" >&2
}

# Run a command safely and trim output
__safe_cmd() {
  "$@" 2>/dev/null | tr -d '\r\n '
}

# Check if cache exists and is fresh
__cache_valid() {
  [[ -f "$__BW_CACHE_FILE" ]] || return 1

  local mtime now
  if [[ "$(uname)" == "Darwin" ]]; then
    mtime=$(stat -f %m "$__BW_CACHE_FILE")
  else
    mtime=$(stat -c %Y "$__BW_CACHE_FILE")
  fi
  now=$(date +%s)
  (( now - mtime < __BW_CACHE_MAX_AGE ))
}

# Load cached session if valid
__load_session() {
  [[ -f "$__BW_CACHE_SESSION" ]] || return 1
  local session=$(<"$__BW_CACHE_SESSION")
  bw status --session "$session" 2>/dev/null | jq -e '.status == "unlocked"' >/dev/null || return 1
  echo "$session"
}

# Unlock and write session to cache
__unlock_session() {
  __err "Bitwarden is locked. Enter master password:"
  __safe_cmd bw unlock --raw | tee "$__BW_CACHE_SESSION"
}

# Refresh the Bitwarden cache (requires temporary session)
__refresh_cache() {
  local session
  session=$(__load_session) || session=$(__unlock_session)
  [[ -z "$session" ]] && {
    __err "Failed to unlock or load Bitwarden session"
    return 1
  }
  bw list items --session "$session" > "$__BW_CACHE_FILE"
}

# Ensure cache is usable or refresh if needed
__require_cache() {
  __cache_valid || __refresh_cache
}

# Escape for zsh tab-completion
__bw_escape_zsh() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str// /\\ }"
  str="${str//\!/\\!}"
  str="${str//\$/\\\$}"
  str="${str//\`/\\\`}"
  str="${str//\"/\\\"}"
  str="${str//\'/\\\'}"
  str="${str//\(/\\(}"
  str="${str//\)/\\)}"
  str="${str//\*/\\*}"
  str="${str//\&/\\&}"
  str="${str//\|/\\|}"
  str="${str//\^/\\^}"
  str="${str//\;/\\;}"
  echo "$str"
}

# Fetch password
bwpass() {
  __require_cache || return 1

  local input="${(Q)${1:-}}"
  local name="${input%%/*}"
  local user="${input#*/}"
  [[ "$input" != */* ]] && user=""

  local id=$(jq -r --arg name "$name" --arg user "$user" '
    .[] | select(.name == $name and (.login.username == $user or $user == "")) | .id' "$__BW_CACHE_FILE")

  [[ -z "$id" ]] && { __err "No matching item found."; return 1; }

  jq -r --arg id "$id" '.[] | select(.id == $id) | .login.password' "$__BW_CACHE_FILE" | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Generate OTP
bwotp() {
  command -v oathtool >/dev/null || {
    __err "'oathtool' is required."
    return 1
  }

  __require_cache || return 1

  local input="${(Q)${1:-}}"
  local name="${input%%/*}"
  local user="${input#*/}"
  [[ "$input" != */* ]] && user=""

  local id=$(jq -r --arg name "$name" --arg user "$user" '
    .[] |
    select(.login.totp != null and .name == $name and (.login.username == $user or $user == "")) |
    .id' "$__BW_CACHE_FILE")

  [[ -z "$id" ]] && { __err "No matching item found."; return 1; }

  local raw=$(jq -r --arg id "$id" '.[] | select(.id == $id) | .login.totp' "$__BW_CACHE_FILE" | tr -d '\r\n\t ')
  [[ -z "$raw" ]] && { __err "No TOTP secret found."; return 1; }

  local secret
  if [[ "$raw" == otpauth://* ]]; then
    secret=$(echo "$raw" | sed -n 's/.*[?&]secret=\([^&]*\).*/\1/p' | tr 'a-z' 'A-Z')
  else
    secret=$(echo "$raw" | tr 'a-z' 'A-Z')
  fi

  echo "$secret" | grep -qE '^[A-Z2-7]+=*$' || {
    __err "Invalid TOTP secret"
    return 1
  }

  oathtool --totp -b "$secret"
}

# Completion for bwpass
_bwpass_completions() {
  [[ -f "$__BW_CACHE_FILE" ]] || return
  local -a raw escaped
  raw=("${(@f)$(jq -r '
    .[] | select(.login.password != null and .login.username != null) |
    "\(.name)/\(.login.username)"' "$__BW_CACHE_FILE")}")
  for r in "${raw[@]}"; do
    escaped+=("$(__bw_escape_zsh "$r")")
  done
  compadd -Q -a escaped
}

# Completion for bwtotp
_bwotp_completions() {
  [[ -f "$__BW_CACHE_FILE" ]] || return
  local -a raw escaped
  raw=("${(@f)$(jq -r '
    .[] | select(.login.totp != null and .login.username != null) |
    "\(.name)/\(.login.username)"' "$__BW_CACHE_FILE")}")
  for r in "${raw[@]}"; do
    escaped+=("$(__bw_escape_zsh "$r")")
  done
  compadd -Q -a escaped
}

# Register completions
compdef _bwpass_completions bwpass
compdef _bwotp_completions bwotp

zstyle ':completion:*' list-prompt ''
zstyle ':completion:*' no-list true
