#!/bin/sh

# -----------------------------------------------------------------------------
# Description:
#   Clones a remote git repository using a shallow clone (with --depth=1).
#   Runs on any UNIX compatible OS
#
# Requirements:
#   - git > 1.8.1.4
#   - Optional: GIT_TOKEN for private repositories
#
# Usage:
#   shallow-clone-helper.sh -r <url> [-d <dir>] [-f]
#
# Parameters:
#   -r   Repository URL (required)
#   -d   Destination directory (optional)
#   -f   Force overwrite if destination exists
#
# Environment:
#   GIT_TOKEN   Authentication token for private GitHub repositories
# -----------------------------------------------------------------------------

set -eu

# shared functions (ideally should live in some shared lib)

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

err() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'WARN: %s\n' "$*" >&2
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || \
        err "required command not found: $1"
}

# requirements check
require_cmd git
# TODO: improvement - version check

# parameters

REPO_URL=""
DEST=""
FORCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        -r|--repo)
            [ $# -ge 2 ] && [ "${2#-}" = "$2" ] || err "missing value for $1"
            REPO_URL="$2"
            shift 2
            ;;
        -d|--dest)
            [ $# -ge 2 ] && [ "${2#-}" = "$2" ] || err "missing value for $1"
            DEST="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=1
            shift 1
            ;;
        *)
            log "Unknown argument: $1"
            exit 1
            ;;
    esac
done
# REPO_URL is required
[ -n "$REPO_URL" ]  || err "missing URL"

# authentication for private repositories

if [ -n "${GIT_TOKEN:-}" ]; then
    ASKPASS=/tmp/askpass_$$
    cat >"$ASKPASS" <<'EOF'
#!/bin/sh
case "$1" in
    Username*) printf '%s\n' "${GIT_USERNAME:-oauth2}" ;;
    Password*) printf '%s\n' "$GIT_TOKEN" ;;
esac
EOF

    chmod 700 "$ASKPASS"
    export GIT_ASKPASS="$ASKPASS"

    trap 'rm -f "$ASKPASS"' EXIT INT TERM
fi

# destination check

# only overwrite if -force flag is provided
if [ -e "$DEST" ]; then
    [ "$FORCE" = 1 ] || err "$DEST exists, use -f to overwrite"
    rm -rf -- "$DEST"
else
    log "creating destination directory /tmp/clone_$$"
    mkdir -p /tmp/clone_$$
    DEST=/tmp/clone_$$
fi


# actual clone

# TODO: add retries on failures
# TODO: add branch as parameter (question - various gir version support?)

log "cloning $REPO_URL to $DEST"

# disable terminal prompt to avoid git requests for username
GIT_TERMINAL_PROMPT=0 git clone -q --depth=1 "$REPO_URL" "$DEST" \
|| err "git clone failed"

log "done"