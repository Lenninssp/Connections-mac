#!/bin/zsh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
# Load API key from .env (KEY=VALUE format)
if [[ -f .env ]]; then
  export $(grep -v '^#' .env | xargs)
fi
swift build -c release
exec .build/release/Connections
