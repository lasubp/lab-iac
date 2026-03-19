#!/usr/bin/env bash
set -euo pipefail

VMID=""
NAME="opnsense-template"
NODE=""
STORAGE="local-lvm"
ISO_STORE="local"
ISO_FILE="OPNsense-installer.iso"
MEMORY="4096"
CORES="2"
WAN_BRIDGE="vmbr1"
LAN1_BRIDGE="vmbr2"
LAN2_BRIDGE="vmbr3"
LAN3_BRIDGE="vmbr4"
LAN4_BRIDGE="vmbr5"
LAN5_BRIDGE="vmbr6"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid) VMID="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --node) NODE="$2"; shift 2 ;;
    --storage) STORAGE="$2"; shift 2 ;;
    --iso-store) ISO_STORE="$2"; shift 2 ;;
    --iso-file) ISO_FILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$VMID" || -z "$NODE" ]]; then
  echo "Usage: $0 --vmid <id> --node <node> [--name ...] [--storage ...] [--iso-store ...] [--iso-file ...]" >&2
  exit 1
fi

qm destroy "$VMID" --purge 1 >/dev/null 2>&1 || true
qm create "$VMID" \
  --name "$NAME" \
  --node "$NODE" \
  --memory "$MEMORY" \
  --cores "$CORES" \
  --scsihw virtio-scsi-pci \
  --ostype l26 \
  --bios seabios \
  --serial0 socket \
  --vga serial0 \
  --net0 virtio,bridge="$WAN_BRIDGE" \
  --net1 virtio,bridge="$LAN1_BRIDGE" \
  --net2 virtio,bridge="$LAN2_BRIDGE" \
  --net3 virtio,bridge="$LAN3_BRIDGE" \
  --net4 virtio,bridge="$LAN4_BRIDGE" \
  --net5 virtio,bridge="$LAN5_BRIDGE"

qm set "$VMID" --scsi0 "$STORAGE":32
qm set "$VMID" --ide2 "$ISO_STORE":iso/"$ISO_FILE",media=cdrom
qm set "$VMID" --boot order=ide2

echo "[OK] OPNsense installer VM created: $NAME (VMID $VMID)"
echo "Boot it, install OPNsense, shut it down, then convert it to a template with:"
echo "  qm template $VMID"
