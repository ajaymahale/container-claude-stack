#!/usr/bin/env bash
# Store provider tokens in macOS Keychain. Re-runnable. Tokens never hit disk.
set -euo pipefail

store() {
  local label="$1" service="$2" pw=""
  read -rsp "Paste $label token (hidden): " pw; echo
  [ -n "$pw" ] || { echo "  empty — skipping $service"; return; }
  security add-generic-password -a "$USER" -s "$service" -w "$pw" -U
  echo "  stored: $service"
  pw=""
}

echo "== claude-stack secret bootstrap =="
echo "Stores tokens in macOS Keychain (services: cc-zai-token, cc-deepinfra-token, cc-deepseek-token)."
echo "anthropic/ccm uses native claude login — no token needed."
echo
store "z.ai (ccg)"            "cc-zai-token"
store "deepinfra (ccdideep)"  "cc-deepinfra-token"
store "deepseek (ccd)"        "cc-deepseek-token"
echo
echo "Done. Verify (prints the token):"
echo "  security find-generic-password -a \"\$USER\" -s cc-zai-token -w"
