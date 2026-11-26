from base64 import b64encode
from http.server import BaseHTTPRequestHandler
from ipaddress import IPv4Address, IPv4Network
import json
from pathlib import Path
from socket import AF_INET6
from socketserver import ThreadingTCPServer
import os
import secrets
import subprocess
import sys
import time

ROOT = Path('/opt/coldwire-mac-test')
PANEL = ROOT / 'panel'
TOOLS = ROOT / 'tools'
GATEWAY = '192.168.94.2'
ENTRY = '192.168.94.4'
PROVIDER = '192.168.94.1'
EXIT = '192.168.92.2'
OBSERVER = '192.168.93.2'
NAMESPACE = 'cw-mac-exit'
IPV6_OBSERVER = '2001:db8:91::2'


class SourceHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(self.client_address[0].encode())

    def log_message(self, *args):
        pass


class IPv6Observer(ThreadingTCPServer):
    address_family = AF_INET6


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def netns(name, *args, **kwargs):
    return run('ip', 'netns', 'exec', name, *args, **kwargs)


def link(namespace, subnet, host, guest):
    run('ip', 'netns', 'add', namespace)
    run('ip', 'link', 'add', host, 'type', 'veth', 'peer', 'name', guest)
    run('ip', 'link', 'set', guest, 'netns', namespace)
    run('ip', 'addr', 'add', subnet + '.1/24', 'dev', host)
    run('ip', 'link', 'set', host, 'up')
    netns(namespace, 'ip', 'link', 'set', 'lo', 'up')
    netns(namespace, 'ip', 'addr', 'add', subnet + '.2/24', 'dev', guest)
    netns(namespace, 'ip', 'link', 'set', guest, 'up')
    netns(namespace, 'ip', 'route', 'add', 'default', 'via', subnet + '.1')


def prefixes(mode):
    return [IPv4Network(row['ip']) for row in json.loads((PANEL / f'{mode}.amnezia.json').read_text())]


def key():
    return b64encode(secrets.token_bytes(32)).decode()


def public(private):
    return subprocess.check_output([TOOLS / 'awg', 'pubkey'], input=private + '\n', text=True).strip()


def configure():
    from urllib.error import URLError
    from urllib.request import ProxyHandler, build_opener

    assert os.geteuid() == 0 and Path('/run/coldwire-mac-test-fixture').is_file()
    sys.path.insert(0, str(PANEL))
    import exit_config
    from convert_profile import encode

    services, direct = prefixes('ru-services'), prefixes('ru-direct')
    common = next(str(address) for prefix in services
                  for address in (prefix.network_address + (prefix.num_addresses > 1),)
                  if address.is_global and any(address in other for other in direct))
    direct_only = next(str(address) for prefix in direct
                       for address in (prefix.network_address, prefix.broadcast_address)
                       if address.is_global and all(address not in other for other in services))
    outside = '203.0.113.17'
    assert all(IPv4Address(outside) not in prefix for prefix in services + direct)
    targets = (common, direct_only, outside)

    run('tar', '-xzf', PANEL / 'dist/awg-native-linux-amd64.tar.gz', '-C', TOOLS)
    run('modprobe', 'tun')
    run('modprobe', 'ipip')
    run('ip', '-6', 'addr', 'add', IPV6_OBSERVER + '/64', 'dev', 'lab0', 'nodad')
    # vmnet sees only the fixed outer addresses of the host and guest.
    run('ip', 'tunnel', 'add', 'cwpath0', 'mode', 'ipip', 'local', '192.168.91.2',
        'remote', '192.168.91.1', 'dev', 'lab0')
    run('ip', 'addr', 'add', GATEWAY, 'peer', PROVIDER + '/32', 'dev', 'cwpath0')
    rebound = '192.168.94.3'
    run('ip', 'route', 'add', rebound + '/32', 'dev', 'cwpath0')
    run('ip', 'addr', 'add', ENTRY + '/32', 'dev', 'cwpath0')
    run('ip', 'link', 'set', 'cwpath0', 'up')
    run('sysctl', '-qw', 'net.ipv4.ip_forward=1')
    link(NAMESPACE, '192.168.92', 'exit-host', 'exit-peer')
    link('cw-mac-observer', '192.168.93', 'look-host', 'look-peer')
    netns(NAMESPACE, 'sysctl', '-qw', 'net.ipv4.ip_forward=1')
    for address in targets:
        netns('cw-mac-observer', 'ip', 'addr', 'add', address + '/32', 'dev', 'lo')
        run('ip', 'route', 'add', address + '/32', 'via', OBSERVER)
    for namespace, command in ((None, f'''
table inet coldwire_access {{
    set spa_clients {{ type ipv4_addr; flags timeout; }}
    chain entry {{
        type nat hook prerouting priority dstnat; policy accept;
        ip saddr {{ {PROVIDER}, {rebound} }} ip daddr {ENTRY} udp dport 32497 dnat to {EXIT}:51820
    }}
    chain forward {{
        type filter hook forward priority filter; policy drop;
        ip saddr @spa_clients ip daddr {EXIT} udp dport 51820 accept
        ip daddr {EXIT} udp dport 51820 drop
        ct state established,related accept
        ip saddr {{ {PROVIDER}, {rebound}, {EXIT} }} ip daddr {{ {', '.join(targets)} }} tcp dport 18080 accept
    }}
}}'''), (NAMESPACE, f'''
table ip cw_mac_nat {{
    chain exit {{
        type nat hook postrouting priority srcnat; policy accept;
        ip saddr 10.8.1.0/24 ip daddr {{ {', '.join(targets)} }} tcp dport 18080 snat to {EXIT}
    }}
}}''')):
        nft = ('nft', '-f', '-')
        if namespace:
            netns(namespace, *nft, input=command, text=True)
        else:
            run(*nft, input=command, text=True)

    private = key()
    state = dict(private_key=private, public_key=public(private), psk=key(), port=51820,
                 parameters=exit_config.parameters(key()), endpoint=EXIT, clients={})
    exit_config.DNS = (GATEWAY, ENTRY)
    peer = key()
    peer_public = public(peer)
    name = 'macos-lab'
    state['clients'][name] = {'address': '10.8.1.2', 'public_key': peer_public}
    profile = exit_config.client_profile(state, name, peer, peer_public, '10.8.1.2')
    spa_key = secrets.token_hex(32)
    profile = exit_config.convert(profile, ENTRY, 32497, spa_key=spa_key)
    exit_config.write_private(ROOT / 'client.vpn', encode(profile))
    spa_config = ROOT / 'spa-keys.json'
    exit_config.write_private(spa_config, json.dumps(dict(cookie_key=secrets.token_hex(32), devices=[spa_key])))
    run('systemd-run', '--unit=cw-mac-spa', TOOLS / 'coldwire-spa', '--bind', ENTRY, '--keys', spa_config)

    run('systemd-run', '--unit=cw-mac-observer', '/usr/sbin/ip', 'netns', 'exec', 'cw-mac-observer',
        sys.executable, __file__, 'observe')
    run('systemd-run', '--unit=cw-mac-ipv6-observer', sys.executable, __file__, 'observe-ipv6')
    run('systemd-run', '--unit=cw-mac-awg', '/usr/sbin/ip', 'netns', 'exec', NAMESPACE,
        TOOLS / 'amneziawg-go', '-f', 'awg0')
    for _ in range(80):
        if Path('/run/amneziawg/awg0.sock').exists():
            break
        time.sleep(.1)
    else:
        raise RuntimeError('AWG socket did not start')
    native = '\n'.join(line for line in exit_config.server_config(state).splitlines()
                       if not line.startswith(('Address =', 'MTU =')))
    netns(NAMESPACE, TOOLS / 'awg', 'setconf', 'awg0', '/dev/stdin', input=native, text=True)
    netns(NAMESPACE, 'ip', 'addr', 'add', '10.8.1.1/24', 'dev', 'awg0')
    netns(NAMESPACE, 'ip', 'link', 'set', 'awg0', 'mtu', '1280', 'up')
    opener = build_opener(ProxyHandler({}))
    for target in targets:
        for attempt in range(16):
            try:
                with opener.open(f'http://{target}:18080/', timeout=3) as received:
                    assert received.read().decode() == '192.168.93.1'
                break
            except URLError:
                if attempt == 15:
                    raise
                time.sleep(.75)
    (ROOT / 'lab.json').write_text(json.dumps(dict(provider=PROVIDER, gateway=GATEWAY, entry=ENTRY,
                                                   exit=EXIT, targets=targets, rebound=rebound)), encoding='utf-8')
    print('Ready: isolated relay, exit and observer', flush=True)


if __name__ == '__main__':
    if sys.argv[1:] == ['observe']:
        ThreadingTCPServer(('0.0.0.0', 18080), SourceHandler).serve_forever()
    elif sys.argv[1:] == ['observe-ipv6']:
        IPv6Observer((IPV6_OBSERVER, 18081), SourceHandler).serve_forever()
    else:
        configure()
