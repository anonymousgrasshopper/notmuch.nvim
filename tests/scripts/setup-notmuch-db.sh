#!/usr/bin/env bash
set -euo pipefail

# Set up disposable test state under tests/tmp.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$ROOT/tests/tmp"
MAIL_ROOT="$TEST_ROOT/mail"
HOME_ROOT="$TEST_ROOT/home"
FIXTURE_ROOT="$ROOT/tests/fixtures/corpora"

# Clean up and recreate test directories
rm -rf "$TEST_ROOT"
mkdir -p "$MAIL_ROOT" "$HOME_ROOT" "$TEST_ROOT/hooks"

# Copy fixture emails.
# Start with default corpus. Add more corpora as needed.
cp -a "$FIXTURE_ROOT/default/." "$MAIL_ROOT/"

# Sample notmuch config file
cat > "$HOME_ROOT/.notmuch-config" <<EOF
[database]
path=$MAIL_ROOT
hook_dir=$TEST_ROOT/hooks

[user]
name=Test User
primary_email=test@example.com

[new]
tags=unread;inbox;
ignore=

[search]
exclude_tags=deleted;spam;

[maildir]
synchronize_flags=true
EOF

NOTMUCH_CONFIG="$HOME_ROOT/.notmuch-config" HOME="$HOME_ROOT" notmuch new

echo "Created test Notmuch database at: $MAIL_ROOT"
echo "Using HOME=$HOME_ROOT"
