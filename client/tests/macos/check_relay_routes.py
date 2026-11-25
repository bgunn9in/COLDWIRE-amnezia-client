from ipaddress import IPv4Address
import json
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import sys
import time

APP = '/Applications/AmneziaVPN.app/Contents/MacOS/AmneziaVPN'
DAEMON = ('/var/run/amneziavpn/daemon.socket', '/tmp/amneziavpn.socket')
PREFERENCES = ('/usr/bin/defaults', 'write', 'org.amneziavpn.AmneziaVPN')


def route(address):
    output = subprocess.check_output(['/sbin/route', '-n', 'get', '-inet', address], text=True, timeout=4)
    return dict(re.findall(r'^\s*(destination|gateway|interface|flags):[ \t]+(\S+)', output, flags=re.MULTILINE))


def privileged(*args, **kwargs):
    return subprocess.run(['sudo', '-n', *args], timeout=8, **kwargs)


def deactivate():
    path = next((path for path in DAEMON if Path(path).is_socket()), None)
    if path:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as control:
            control.settimeout(2)
            control.connect(path)
            control.sendall(b'{"type":"deactivate"}\n')
            try:
                control.recv(4096)
            except TimeoutError:
                pass


def prepare_keychain(root):
    keychain = root / 'coldwire-test.keychain-db'
    password = secrets.token_hex(16)
    security = '/usr/bin/security'
    chain = subprocess.run([security, 'list-keychains', '-d', 'user'], check=True, text=True, capture_output=True)
    old = re.findall(r'^\s*"([^"]+)"\s*$', chain.stdout, re.MULTILINE)
    for args in [('create-keychain', '-p', password, keychain), ('unlock-keychain', '-p', password, keychain),
                 ('list-keychains', '-d', 'user', '-s', keychain, *old)]:
        subprocess.run([security, *args], check=True, capture_output=True)
    for account in ('settingsKeyTag', 'settingsIvTag'):
        subprocess.run([security, 'add-generic-password', '-s', 'AmneziaVPN-Keychain', '-a', account,
                        '-T', APP, '-X', secrets.token_hex(32), keychain], check=True, capture_output=True)


def protect_existing_sockets(old, targets):
    sockets = privileged('/usr/sbin/lsof', '-nP', '-iTCP', '-sTCP:ESTABLISHED', '-Fn',
                         capture_output=True, text=True).stdout
    installed = []
    for address in sorted(set(re.findall(r'->((?:\d+\.){3}\d+):\d+\b', sockets))):
        if address in targets or route(address).get('gateway') != old:
            continue
        result = privileged('/sbin/route', '-n', 'add', '-host', address, old, capture_output=True)
        if result.returncode == 0:
            installed.append(address)
    return installed


def sample(ip, expected, physical, allowed_tunnel=None):
    interface = route(ip).get('interface', '')
    if interface != physical and interface != allowed_tunnel:
        raise RuntimeError(f'Probe route left the isolated lab: {interface}')
    found = subprocess.check_output(['/usr/bin/curl', '--noproxy', '*', '--fail', '--silent',
                                     '--show-error', '--connect-timeout', '2', '--max-time', '4',
                                     f'http://{ip}:18080/'], text=True, timeout=6, stderr=subprocess.DEVNULL)
    if str(IPv4Address(found)) != expected:
        raise AssertionError(f'{ip}: observer saw {found}, expected {expected}')
    return found


def set_gateway(address, interface):
    try:
        current = route('default')
        if (current.get('gateway'), current.get('interface')) == (address, interface):
            return
    except subprocess.CalledProcessError:
        pass
    privileged('/sbin/route', '-qn', 'delete', '-inet', 'default', capture_output=True)
    privileged('/sbin/route', '-qn', 'add', '-inet', 'default', address, '-ifp', interface, check=True)


def restore_gateway(address, interface, marker):
    try:
        deactivate()
    finally:
        set_gateway(address, interface)
        assert route('default')['interface'] == interface
        marker.touch()


def stop_client(client):
    if client.poll() is None:
        client.terminate()
        try:
            client.wait(timeout=4)
        except subprocess.TimeoutExpired:
            client.kill()
            client.wait()


def import_profile(root):
    profile = (root / 'client.vpn').read_text().strip()
    assert re.fullmatch(r'vpn://[A-Za-z0-9_-]+', profile)
    log_path = root / 'import.log'
    with log_path.open('wb') as log:
        client = subprocess.Popen([APP, '--import', profile], stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(90):
                if 'Started COLDWIRE version' in log_path.read_text(errors='replace'):
                    saved = subprocess.run(['/usr/bin/defaults', 'read', PREFERENCES[-1], 'Servers.serversList'],
                                           capture_output=True)
                    if saved.returncode == 0:
                        print('Imported the temporary COLDWIRE client profile', flush=True)
                        return
                if client.poll() is not None:
                    break
                time.sleep(.5)
            notes = re.sub(r'[A-Za-z0-9+/_=-]{40,}', '[redacted]', log_path.read_text(errors='replace'))
            print('\n'.join(notes.splitlines()[-20:]), flush=True)
            raise RuntimeError('The client did not finish importing the lab profile')
        finally:
            stop_client(client)


def main(root):
    assert sys.platform == 'darwin' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted'
    lab = json.loads((root / 'lab.json').read_text())
    provider, exit_ip, gateway = lab['provider'], lab['exit'], lab['gateway']
    assert (provider, exit_ip, gateway) == ('192.168.91.1', '192.168.92.2', '192.168.91.2')
    targets = tuple(lab['targets'])
    assert len(set(targets)) == 3
    for address in targets:
        IPv4Address(address)
    original = route('default')
    physical = route(gateway)['interface']
    assert physical != original['interface']
    assert f'inet {provider} ' in subprocess.check_output(['/sbin/ifconfig', physical], text=True), physical
    subprocess.run(['/sbin/ping', '-c', '1', '-W', '1800', gateway], check=True, timeout=5)

    subprocess.run(['/usr/bin/pkill', '-TERM', '-x', 'AmneziaVPN'], check=False)
    time.sleep(2)
    deactivate()
    prepare_keychain(root)
    for key, value in (('autoUpdateCheck', 'false'), ('saveLogs', 'true'), ('autoConnect', 'false')):
        subprocess.run([*PREFERENCES, f'Conf.{key}', '-bool', value], check=True)
    import_profile(root)
    previous = original['gateway']
    IPv4Address(previous)
    preserved = protect_existing_sockets(previous, targets)
    restored = root / 'gateway-restored'
    subprocess.Popen([sys.executable, __file__, '--restore', previous, original['interface'], restored],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    try:
        set_gateway(gateway, physical)
        selected = route(targets[-1])
        assert selected.get('interface') == physical, selected
        print(f'Isolated provider route active on {physical}: {selected}', flush=True)
        baseline = [sample(target, provider, physical) for target in targets]
        print(f'PASS macOS IPv4 without VPN: observer={baseline}', flush=True)
        modes = [('all', (exit_ip, exit_ip, exit_ip)),
                 ('ru-services', (provider, exit_ip, exit_ip)),
                 ('ru-direct', (provider, provider, exit_ip))]
        for mode, expected in modes:
            for target in targets:
                # Forget the host-only bridge's ARP clones before new routes are installed.
                privileged('/usr/sbin/arp', '-d', target, 'ifscope', physical, capture_output=True)
            enabled = mode != 'all'
            if enabled:
                rows = json.loads((Path('admin-panel') / f'{mode}.amnezia.json').read_text())
                pairs = [value for row in rows for value in (row['ip'], '[]')]
                subprocess.run([*PREFERENCES, 'Conf.ExceptSites', '-dict', *pairs], check=True)
                subprocess.run([*PREFERENCES, 'Conf.routeMode', '-int', '2'], check=True)
            subprocess.run([*PREFERENCES, 'Conf.sitesSplitTunnelingEnabled', '-bool', str(enabled).lower()], check=True)
            with (root / f'client-{mode}.log').open('wb') as log:
                client = subprocess.Popen([APP, '--connect', '0'],
                                          stdout=log, stderr=subprocess.STDOUT,
                                          env=dict(os.environ, QT_LOGGING_RULES='*.debug=true;qt.*.debug=false'))
                try:
                    for _ in range(120):
                        if client.poll() is not None:
                            raise RuntimeError('The COLDWIRE client exited before connecting')
                        status = subprocess.check_output(['/sbin/ifconfig', '-a'], text=True, timeout=5)
                        iface = re.search(r'^(utun\d+):[^\n]*(?:\n\t[^\n]*)*?\n\tinet 10\.8\.1\.2 ',
                                          status, re.MULTILINE)
                        if iface and route(targets[-1]).get('interface') == iface[1]:
                            tunnel = iface[1]
                            break
                        time.sleep(.5)
                    else:
                        raise RuntimeError(f'No AWG route appeared in mode {mode}: {route(targets[-1])}')
                    for attempt in range(3):
                        try:
                            seen = [sample(target, want, physical, tunnel) for target, want in zip(targets, expected)]
                            break
                        except subprocess.CalledProcessError:
                            if attempt == 2:
                                raise RuntimeError(f'The observer did not answer in mode {mode}') from None
                            time.sleep(1)
                    print(f'PASS macOS IPv4 {mode}: observer={seen}', flush=True)
                except Exception:
                    lines = (root / f'client-{mode}.log').read_text(errors='replace').splitlines()
                    notes = [line for line in lines if re.search(r'connect|import|split tunneling|error|failed|handshake|started', line, re.I)]
                    for note in notes[-25:]:
                        print(re.sub(r'[A-Za-z0-9+/_=-]{40,}', '[redacted]', note), flush=True)
                    interfaces = subprocess.check_output(['/sbin/ifconfig', '-a'], text=True, timeout=5)
                    for line in interfaces.splitlines():
                        if line.startswith('utun') or 'inet 10.8.1.' in line:
                            print(line, flush=True)
                    if client.poll() is None:
                        stack = root / 'coldwire-stacks.txt'
                        subprocess.run(['/usr/bin/sample', str(client.pid), '2', '10', '-file', stack],
                                       timeout=8, capture_output=True, check=False)
                        if stack.is_file():
                            lines = stack.read_text(errors='replace').splitlines()
                            main_thread = next((i for i, line in enumerate(lines) if 'DispatchQueue_1:' in line), 0)
                            print('\n'.join(lines[main_thread:main_thread + 38]), flush=True)
                    log = privileged('/usr/bin/log', 'show', '--last', '2m', '--style', 'compact',
                                     '--predicate', 'process == "AmneziaVPN-service" OR process == "amneziawg-go"',
                                     capture_output=True, text=True, check=False).stdout
                    notes = [line for line in log.splitlines() if re.search(r'activate|tunnel|failed|error', line, re.I)]
                    for note in notes[-12:]:
                        print(re.sub(r'[A-Za-z0-9+/_=-]{40,}', '[redacted]', note), flush=True)
                    raise
                finally:
                    deactivate()
                    stop_client(client)
                    time.sleep(1)
    finally:
        restore_gateway(previous, original['interface'], restored)
        print('Restored the runner default route', flush=True)
        for address in preserved:
            privileged('/sbin/route', '-qn', 'delete', '-host', address, previous, capture_output=True)


if __name__ == '__main__':
    if sys.argv[1] == '--restore':
        assert sys.platform == 'darwin' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted'
        marker = Path(sys.argv[4])
        time.sleep(250)
        if not marker.exists():
            restore_gateway(sys.argv[2], sys.argv[3], marker)
    else:
        main(Path(sys.argv[1]))
