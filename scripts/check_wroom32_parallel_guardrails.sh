#!/usr/bin/env bash
set -euo pipefail

BASE_TAG="s3-baseline-game-mode-2026-05-27"
STRICT=0

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

if ! git rev-parse --verify "$BASE_TAG" >/dev/null 2>&1; then
  echo "ERROR: baseline tag '$BASE_TAG' not found"
  exit 2
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
echo "Branch: $current_branch"
echo "Baseline tag: $BASE_TAG"

mapfile -t changed_committed < <(git diff --name-only "$BASE_TAG"...HEAD)
mapfile -t changed_unstaged < <(git diff --name-only)
mapfile -t changed_staged < <(git diff --name-only --cached)
mapfile -t changed_untracked < <(git ls-files --others --exclude-standard)

declare -A seen=()
changed=()
for f in "${changed_committed[@]}" "${changed_unstaged[@]}" "${changed_staged[@]}" "${changed_untracked[@]}"; do
  [[ -z "$f" ]] && continue
  if [[ -z "${seen[$f]:-}" ]]; then
    seen[$f]=1
    changed+=("$f")
  fi
done

if [[ ${#changed[@]} -eq 0 ]]; then
  echo "No divergence from baseline."
  exit 0
fi

echo "Changed files since baseline:"
printf '  %s\n' "${changed[@]}"

unsafe=0
for f in "${changed[@]}"; do
  case "$f" in
    docs/game_mode_wroom32_parallel_plan.md|\
    docs/game_mode_esp32_backend_plan.md|\
    scripts/check_wroom32_parallel_guardrails.sh|\
    esp32/legacy-wroom32/*|\
    esp32/legacy-wroom32/*/*|\
    esp32/legacy-wroom32/*/*/*)
      ;;
    *)
      echo "WARN: outside current safe experimental allowlist -> $f"
      unsafe=1
      ;;
  esac
done

if [[ $unsafe -eq 1 && $STRICT -eq 1 ]]; then
  echo "STRICT mode: FAIL"
  exit 1
fi

if [[ $unsafe -eq 1 ]]; then
  echo "Guardrails: WARN (non-allowlist files changed)"
else
  echo "Guardrails: OK (changes are within experimental allowlist)"
fi
