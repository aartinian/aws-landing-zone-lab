#!/usr/bin/env bash
# plans and applies the given root modules one after the other, in the given order.
# Roots without changes are skipped. Stops at the first error (e.g. no prod after a failed dev).
#
# usage: apply-roots.sh live/a live/b ...
# env:   STATE_BUCKET (required), GITHUB_STEP_SUMMARY (optional)
set -euo pipefail

: "${STATE_BUCKET:?STATE_BUCKET is not set}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
# download each provider once, the next roots link it from the cache (the lock files hold the
# linux_amd64 checksum, so Terraform trusts the cached copy)
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$(mktemp -d)}"

# new IDs are not known to the masking step: hide all account and OU IDs by pattern
mask() {
  sed -E \
    -e 's/[0-9]{12}/<account-id>/g' \
    -e 's/ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}/<ou-id>/g'
}

# on any error: name the root that failed in the summary (an ERR trap would also
# fire on plan exit code 2, which means "changes")
root=""
on_exit() {
  local status=$?
  if ((status != 0)); then
    echo "| \`${root}\` | **failed** |" >> "${summary}"
  fi
}
trap on_exit EXIT

{
  echo "| Root | Result |"
  echo "|---|---|"
} >> "${summary}"

for root in "$@"; do
  echo "::group::${root}"

  terraform -chdir="${root}" init -no-color -input=false \
    -backend-config="bucket=${STATE_BUCKET}"

  # -detailed-exitcode: 0 = no changes, 1 = error, 2 = changes
  set +e
  terraform -chdir="${root}" plan -no-color -lock-timeout=2m -detailed-exitcode -out=tfplan \
    | mask
  code=${PIPESTATUS[0]}
  set -e

  case "${code}" in
    0)
      echo "| \`${root}\` | no changes |" >> "${summary}"
      ;;
    2)
      result=$(terraform -chdir="${root}" show -no-color tfplan | grep -E '^Plan:' || true)
      terraform -chdir="${root}" apply -no-color -lock-timeout=2m tfplan | mask
      echo "| \`${root}\` | applied (${result:-see log}) |" >> "${summary}"
      ;;
    *)
      echo "::error::terraform plan failed in ${root}"
      false
      ;;
  esac

  echo "::endgroup::"
done
