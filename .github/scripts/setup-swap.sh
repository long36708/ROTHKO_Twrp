#!/usr/bin/env bash
# Create the swap an OrangeFox build needs when the runner does not already
# provide MIN_SWAP_GIB. Only the missing capacity (plus a 1 MiB mkswap header
# margin) is allocated, so preconfigured swap is left untouched.
set -euo pipefail

SWAPFILE="${SWAPFILE:-/swapfile-orangefox}"
SWAPSIZE="${SWAPSIZE:-}"
MIN_SWAP_GIB="${MIN_SWAP_GIB:-12}"

if ! [[ "${MIN_SWAP_GIB}" =~ ^[1-9][0-9]*$ ]]; then
  echo "MIN_SWAP_GIB must be a positive integer: ${MIN_SWAP_GIB}" >&2
  exit 1
fi

if [[ -n "${SWAPSIZE}" && ! "${SWAPSIZE}" =~ ^[1-9][0-9]*G$ ]]; then
  echo "SWAPSIZE must use whole GiB units, for example 16G: ${SWAPSIZE}" >&2
  exit 1
fi

gib_kib=$((1024 * 1024))
required_swap_kib=$((MIN_SWAP_GIB * gib_kib))
current_swap_kib="$(awk '/^SwapTotal:/ { print $2 }' /proc/meminfo)"

if ((current_swap_kib >= required_swap_kib)); then
  echo "Existing swap satisfies the ${MIN_SWAP_GIB} GiB requirement."
  free -h
  exit 0
fi

if ! sudo -n true 2>/dev/null; then
  echo "Passwordless sudo is required to create build swap." >&2
  exit 1
fi

if sudo swapon --show=NAME --noheadings 2>/dev/null |
  awk '{$1=$1; print}' | grep -Fxq "$SWAPFILE"; then
  echo "${SWAPFILE} is already active but total swap is below ${MIN_SWAP_GIB} GiB." >&2
  exit 1
fi

missing_swap_kib=$((required_swap_kib - current_swap_kib))
minimum_new_swap_kib=$((missing_swap_kib + 1024))
if [[ -z "${SWAPSIZE}" ]]; then
  swap_size_gib=$(((minimum_new_swap_kib + gib_kib - 1) / gib_kib))
  SWAPSIZE="${swap_size_gib}G"
else
  swap_size_gib="${SWAPSIZE%G}"
  if (($((swap_size_gib * gib_kib)) < minimum_new_swap_kib)); then
    echo "SWAPSIZE=${SWAPSIZE} is too small to provide ${MIN_SWAP_GIB} GiB total swap." >&2
    exit 1
  fi
fi

sudo rm -f "${SWAPFILE}"
echo "Creating ${SWAPSIZE} additional swap at ${SWAPFILE}"
if ! sudo fallocate -l "${SWAPSIZE}" "${SWAPFILE}" 2>/dev/null; then
  sudo dd if=/dev/zero of="${SWAPFILE}" bs=1M count=$((swap_size_gib * 1024)) status=none
fi

sudo chmod 600 "${SWAPFILE}"
sudo mkswap "${SWAPFILE}" >/dev/null
if ! sudo swapon "${SWAPFILE}"; then
  sudo rm -f "${SWAPFILE}"
  echo "Unable to enable ${SWAPFILE}. Preconfigure swap on an ext4 or xfs runner filesystem." >&2
  exit 1
fi

current_swap_kib="$(awk '/^SwapTotal:/ { print $2 }' /proc/meminfo)"
if ((current_swap_kib < required_swap_kib)); then
  echo "Swap setup did not reach the ${MIN_SWAP_GIB} GiB requirement." >&2
  exit 1
fi

free -h
