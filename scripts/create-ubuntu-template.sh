#!/usr/bin/env bash
set -euo pipefail

VMID=""
NAME="ubuntu-2404-cloudinit-template"
NODE=""
STORAGE="local-lvm"
SNIPPET_STORE="local"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_FILE="/var/lib/vz/template/cache/noble-server-cloudimg-amd64.img"
MEMORY="2048"
CORES="2"
BRIDGE="vmbr0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid) VMID="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --node) NODE="$2"; shift 2 ;;
    --storage) STORAGE="$2"; shift 2 ;;
    --snippet-store) SNIPPET_STORE="$2"; shift 2 ;;
    --image-url) IMAGE_URL="$2"; shift 2 ;;
    --bridge) BRIDGE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$VMID" || -z "$NODE" ]]; then
  echo "Usage: $0 --vmid <id> --node <node> [--name ...] [--storage ...] [--snippet-store ...]" >&2
  exit 1
fi

mkdir -p /var/lib/vz/template/cache
if [[ ! -f "$IMAGE_FILE" ]]; then
  wget -O "$IMAGE_FILE" "$IMAGE_URL"
fi

qm destroy "$VMID" --purge 1 >/dev/null 2>&1 || true
qm create "$VMID" \
  --name "$NAME" \
  --node "$NODE" \
  --memory "$MEMORY" \
  --cores "$CORES" \
  --net0 virtio,bridge="$BRIDGE" \
  --scsihw virtio-scsi-pci \
  --serial0 socket \
  --vga serial0 \
  --agent enabled=1,fstrim_cloned_disks=1

qm importdisk "$VMID" "$IMAGE_FILE" "$STORAGE"
qm set "$VMID" --scsi0 "$STORAGE":vm-"$VMID"-disk-0
qm set "$VMID" --boot order=scsi0
qm set "$VMID" --ide2 "$STORAGE":cloudinit
qm set "$VMID" --ostype l26
qm set "$VMID" --ciuser ubuntu
qm set "$VMID" --ipconfig0 ip=dhcp
qm set "$VMID" --sshkeys ~/.ssh/id_rsa.pub >/dev/null 2>&1 || true
qm template "$VMID"

echo "[OK] Ubuntu template created: $NAME (VMID $VMID)"
