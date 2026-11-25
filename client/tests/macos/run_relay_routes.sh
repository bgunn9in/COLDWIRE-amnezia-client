#!/bin/bash
set -euo pipefail

test "$RUNNER_ENVIRONMENT" = github-hosted
test "$(uname -m)" = x86_64
work=$(mktemp -d "$RUNNER_TEMP/coldwire-routes.XXXXXX")
source_path="$PWD"
test_path="$source_path/client/tests/macos"

finish() {
    if [ -s "$work/qemu.pid" ]; then
        sudo -n kill -TERM "$(cat "$work/qemu.pid")" 2>/dev/null || true
    fi
}
trap finish EXIT

command -v qemu-system-x86_64 >/dev/null || brew install qemu
qemu=$(command -v qemu-system-x86_64)

image=jammy-server-cloudimg-amd64.img
ubuntu=https://cloud-images.ubuntu.com/jammy/current
(
    cd "$work"
    curl --fail --silent --show-error --location --retry 3 "$ubuntu/$image" -o "$image"
    curl --fail --silent --show-error --location --retry 3 "$ubuntu/SHA256SUMS" -o SHA256SUMS
    awk -v name="$image" '$2 == name || $2 == ("*" name) { print $1 "  " name }' SHA256SUMS > image.sha256
    test -s image.sha256
    shasum -a 256 -c image.sha256
)

mkdir "$work/seed"
ssh-keygen -q -t ed25519 -N '' -f "$work/key"
cat > "$work/seed/user-data" <<EOF
#cloud-config
ssh_pwauth: false
users:
  - name: cwlaboratory
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "$work/key.pub")
runcmd:
  - [touch, /run/coldwire-mac-test-fixture]
EOF
cat > "$work/seed/meta-data" <<'EOF'
instance-id: coldwire-macos-routing
local-hostname: coldwire-lab
EOF
cat > "$work/seed/network-config" <<'EOF'
version: 2
ethernets:
  control0:
    match:
      macaddress: "52:54:00:91:00:01"
    set-name: control0
    dhcp4: true
  lab0:
    match:
      macaddress: "52:54:00:91:00:02"
    set-name: lab0
    addresses: [192.168.91.2/24]
EOF
hdiutil makehybrid -o "$work/seed.iso" "$work/seed" -iso -joliet -default-volume-name CIDATA

sudo -n "$qemu" -daemonize -pidfile "$work/qemu.pid" -accel tcg,thread=multi \
    -m 1024 -smp 1 -display none -monitor none -serial "file:$work/guest.log" \
    -drive "file=$work/$image,if=virtio,format=qcow2,snapshot=on" -cdrom "$work/seed.iso" \
    -netdev user,id=control,restrict=on,hostfwd=tcp:127.0.0.1:39222-:22 \
    -device virtio-net-pci,netdev=control,mac=52:54:00:91:00:01 \
    -netdev vmnet-host,id=lab,isolated=on,start-address=192.168.91.1,end-address=192.168.91.254,subnet-mask=255.255.255.0 \
    -device virtio-net-pci,netdev=lab,mac=52:54:00:91:00:02

guest=(ssh -T -p 39222 -i "$work/key" -o BatchMode=yes -o ConnectTimeout=4
       -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$work/known_hosts" cwlaboratory@127.0.0.1)
for i in {1..45}; do
    if "${guest[@]}" 'test -f /run/coldwire-mac-test-fixture' 2>/dev/null; then
        break
    fi
    sleep 3
done
"${guest[@]}" 'test "$(hostname)" = coldwire-lab && test -f /run/coldwire-mac-test-fixture && command -v nft'
"${guest[@]}" 'sudo install -d -m 700 /run/coldwire-mac-test/panel /run/coldwire-mac-test/tools'
tar -C "$source_path/admin-panel" -czf - exit_config.py convert_profile.py ru-services.amnezia.json \
    ru-direct.amnezia.json dist/awg-native-linux-amd64.tar.gz |
    "${guest[@]}" 'sudo tar -xzf - -C /run/coldwire-mac-test/panel'
"${guest[@]}" 'sudo tee /run/coldwire-mac-test/prepare.py >/dev/null' < "$test_path/prepare_relay_guest.py"
"${guest[@]}" 'sudo /usr/bin/python3 /run/coldwire-mac-test/prepare.py'
umask 077
for name in lab.json ru-direct.vpn ru-services.vpn all.vpn; do
    "${guest[@]}" "sudo cat /run/coldwire-mac-test/$name" > "$work/$name"
done
python3 "$test_path/check_relay_routes.py" "$work"
