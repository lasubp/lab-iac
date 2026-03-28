#!/usr/bin/env bash
set -euo pipefail

VMID=""
NAME="opnsense-template"
STORAGE="local-lvm"
ISO_STORE="local"
ISO_FILE="OPNsense-installer.iso"
MEMORY="4096"
CORES="2"
DISK_SIZE="32G"
BIOS="seabios"
NETWORK_MODEL="virtio"
WAN_BRIDGE="vmbr1"
LAN_BRIDGES=(vmbr2 vmbr3 vmbr4 vmbr5 vmbr6)
FORCE_RECREATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid) VMID="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --storage) STORAGE="$2"; shift 2 ;;
    --iso-store) ISO_STORE="$2"; shift 2 ;;
    --iso-file) ISO_FILE="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --cores) CORES="$2"; shift 2 ;;
    --disk-size) DISK_SIZE="$2"; shift 2 ;;
    --bios) BIOS="$2"; shift 2 ;;
    --network-model) NETWORK_MODEL="$2"; shift 2 ;;
    --wan-bridge) WAN_BRIDGE="$2"; shift 2 ;;
    --lan-bridges) IFS=',' read -r -a LAN_BRIDGES <<< "$2"; shift 2 ;;
    --force-recreate) FORCE_RECREATE=1; shift 1 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$VMID" ]]; then
  echo "Usage: $0 --vmid <id> [--name ...] [--storage ...] [--iso-store ...] [--iso-file ...] [--memory ...] [--cores ...] [--disk-size ...] [--bios ...] [--network-model ...] [--wan-bridge ...] [--lan-bridges bridge1,bridge2,...] [--force-recreate]" >&2
  exit 1
fi

if [[ ${#LAN_BRIDGES[@]} -eq 0 ]]; then
  echo "Provide at least one LAN bridge with --lan-bridges." >&2
  exit 1
fi

DISK_SIZE_GIB="${DISK_SIZE%G}"
DISK_SIZE_GIB="${DISK_SIZE_GIB%g}"
if [[ ! "$DISK_SIZE_GIB" =~ ^[0-9]+$ ]]; then
  echo "Invalid --disk-size '$DISK_SIZE'. Use a whole number of GiB, for example 32 or 32G." >&2
  exit 1
fi

if ! pvesm path "${ISO_STORE}:iso/${ISO_FILE}" >/dev/null 2>&1; then
  echo "ISO not found in Proxmox storage: ${ISO_STORE}:iso/${ISO_FILE}" >&2
  exit 1
fi

if qm status "$VMID" >/dev/null 2>&1; then
  if [[ "$FORCE_RECREATE" != "1" ]]; then
    echo "VMID $VMID already exists. Re-run with --force-recreate to destroy and recreate it." >&2
    exit 1
  fi
  qm destroy "$VMID" --purge 1 >/dev/null 2>&1
fi

NET_ARGS=("--net0" "${NETWORK_MODEL},bridge=${WAN_BRIDGE}")
for idx in "${!LAN_BRIDGES[@]}"; do
  NET_ARGS+=("--net$((idx + 1))" "${NETWORK_MODEL},bridge=${LAN_BRIDGES[$idx]}")
done

qm create "$VMID" \
  --name "$NAME" \
  --memory "$MEMORY" \
  --cores "$CORES" \
  --scsihw virtio-scsi-pci \
  --ostype l26 \
  --bios "$BIOS" \
  --serial0 socket \
  --vga serial0 \
  "${NET_ARGS[@]}"

qm set "$VMID" --scsi0 "$STORAGE":"$DISK_SIZE_GIB"
qm set "$VMID" --ide2 "$ISO_STORE":iso/"$ISO_FILE",media=cdrom
qm set "$VMID" --boot order=scsi0\;ide2

echo "[OK] OPNsense installer VM created: $NAME (VMID $VMID)"
echo "Boot it, install OPNsense, then set the boot order to disk-only or detach the ISO before templating."
echo "Example:"
echo "  qm set $VMID --boot order=scsi0"
echo "  qm set $VMID --delete ide2"
echo "Then shut it down and convert it to a template with:"
echo "  qm template $VMID"
