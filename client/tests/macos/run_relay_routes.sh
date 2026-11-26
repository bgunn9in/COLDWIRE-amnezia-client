#!/bin/bash
set -euo pipefail

test "$RUNNER_ENVIRONMENT" = github-hosted
test "$(uname -m)" = arm64
work=$(mktemp -d "$RUNNER_TEMP/coldwire-routes.XXXXXX")
source_path="$PWD"
test_path="$source_path/client/tests/macos"
guest_root=/opt/coldwire-mac-test

finish() {
    local result=$?
    if [ "${v6_alias:-}" = yes ]; then
        sudo -n /sbin/ifconfig "$outer_if" inet6 2001:db8:91::1 -alias || true
    fi
    if [ -n "${lab_if:-}" ] &&
        default_if=$(/sbin/route -n get -inet default | awk '$1 == "interface:" { print $2 }') &&
        [ -n "$default_if" ] && [ "$default_if" != "$lab_if" ]; then
        sudo -n /sbin/ifconfig "$lab_if" inet 192.168.94.1 -alias || true
        sudo -n /sbin/ifconfig "$lab_if" inet 192.168.94.3 -alias || true
        sudo -n /sbin/ifconfig "$lab_if" -tunnel mtu "$gif_mtu" down || true
    fi
    if [ "$result" -ne 0 ] && [ -f "$work/guest.log" ]; then
        sudo -n tail -n 55 "$work/guest.log" | sed -E 's/ssh-ed25519 [A-Za-z0-9+\/=]+/[test SSH public key]/g' || true
    fi
    if [ -f "$work/qemu.pid" ]; then
        sudo -n kill -TERM "$(sudo -n cat "$work/qemu.pid")" 2>/dev/null || true
    fi
}
trap finish EXIT

gif_status=$(/sbin/ifconfig gif0)
if grep -Eq '^[[:space:]]+(tunnel|inet6?)[[:space:]]|(<|,)UP(,|>)' <<< "$gif_status"; then
    printf 'The runner already uses gif0:\n%s\n' "$gif_status" >&2
    exit 1
fi
gif_mtu=$(awk 'NR == 1 { for (i = 1; i < NF; ++i) if ($i == "mtu") print $(i + 1) }' <<< "$gif_status")
[[ "$gif_mtu" =~ ^[0-9]+$ ]]

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
for i in {1..70}; do
    if "${guest[@]}" true </dev/null 2>"$work/ssh.log"; then
        break
    fi
    sleep 3
done
if ! "${guest[@]}" 'test "$(cat /var/lib/cloud/data/instance-id)" = coldwire-macos-routing && test -x /usr/sbin/nft'; then
    cat "$work/ssh.log"
    "${guest[@]}" 'hostname; ip -brief address; cloud-init status --long; ls -l /usr/sbin/nft' || true
    exit 1
fi
"${guest[@]}" "sudo touch /run/coldwire-mac-test-fixture && sudo install -d -m 700 $guest_root/panel $guest_root/tools"
tar -C "$source_path/admin-panel" -czf - exit_config.py convert_profile.py ru-services.amnezia.json \
    ru-direct.amnezia.json dist/awg-native-linux-amd64.tar.gz |
    "${guest[@]}" "sudo tar -xzf - -C $guest_root/panel"
(
    cd "$source_path/admin-panel/servers/spa"
    GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -o "$work/coldwire-spa" .
)
"${guest[@]}" "sudo sh -c 'cat > $guest_root/tools/coldwire-spa && chmod 755 $guest_root/tools/coldwire-spa'" < "$work/coldwire-spa"
"${guest[@]}" "sudo tee $guest_root/prepare.py >/dev/null" < "$test_path/prepare_relay_guest.py"
if ! "${guest[@]}" "sudo /usr/bin/python3 $guest_root/prepare.py"; then
    "${guest[@]}" 'sudo journalctl -u cw-mac-observer --no-pager -n 20; sudo ip netns exec cw-mac-observer ss -ltn' || true
    exit 1
fi
umask 077
"${guest[@]}" "sudo tar -C $guest_root -cf - lab.json client.vpn" | tar -xf - -C "$work"
outer_if=$(/sbin/route -n get -inet 192.168.91.2 | awk '$1 == "interface:" { print $2 }')
[[ "$outer_if" =~ ^bridge[0-9]+$ ]]
/sbin/ifconfig "$outer_if" | grep -q 'inet 192\.168\.91\.1 '
sudo -n /sbin/ifconfig "$outer_if" inet6 2001:db8:91::1 prefixlen 64 alias
v6_alias=yes
lab_if=gif0
sudo -n /sbin/ifconfig "$lab_if" tunnel 192.168.91.1 192.168.91.2
sudo -n /sbin/ifconfig "$lab_if" inet 192.168.94.1 192.168.94.2 netmask 255.255.255.255 mtu 1480 up
/sbin/ifconfig "$lab_if"

"${guest[@]}" "if test -x /usr/bin/tcpdump; then sudo systemd-run --unit=cw-mac-trace /usr/bin/tcpdump -ln -i cwpath0 -c 150 'icmp or tcp port 18080 or udp port 32497'; fi"
if ! python3 "$test_path/check_relay_routes.py" "$work" "$lab_if" "$outer_if" "${guest[@]}"; then
    "${guest[@]}" 'ip -s link show cwpath0; ip -s link show lab0; ip -6 address show dev lab0; sudo journalctl -u cw-mac-trace -u cw-mac-observer -u cw-mac-ipv6-observer --no-pager -n 70' || true
    exit 1
fi
