from ipaddress import IPv4Address
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time

APP = '/Applications/AmneziaVPN.app/Contents/MacOS/AmneziaVPN'
DAEMON = ('/var/run/amneziavpn/daemon.socket', '/tmp/amneziavpn.socket')


def route(address):
    output = subprocess.check_output(['/sbin/route', '-n', 'get', address], text=True, timeout=4)
    return dict(re.findall(r'^\s*(destination|gateway|interface):\s+(\S+)', output, flags=re.MULTILINE))


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


def set_gateway(address):
    try:
        if route('default').get('gateway') == address:
            return
    except subprocess.CalledProcessError:
        pass
    privileged('/sbin/route', '-qn', 'delete', 'default', capture_output=True)
    privileged('/sbin/route', '-qn', 'add', 'default', address, check=True, capture_output=True)


def restore_gateway(address, interface, marker):
    try:
        deactivate()
    finally:
        set_gateway(address)
        assert route('default')['interface'] == interface
        marker.touch()


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

    subprocess.run(['/usr/bin/pkill', '-TERM', '-x', 'AmneziaVPN'], check=False)
    time.sleep(2)
    deactivate()
    previous = original['gateway']
    IPv4Address(previous)
    preserved = protect_existing_sockets(previous, targets)
    restored = root / 'gateway-restored'
    subprocess.Popen([sys.executable, __file__, '--restore', previous, original['interface'], restored],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    try:
        set_gateway(gateway)
        assert route('default')['gateway'] == gateway
        assert route('default')['interface'] == physical
        print(f'Isolated provider route active on {physical}', flush=True)
        baseline = [sample(target, provider, physical) for target in targets]
        print(f'PASS macOS IPv4 without VPN: observer={baseline}', flush=True)
        modes = [('ru-services', (provider, exit_ip, exit_ip)),
                 ('ru-direct', (provider, provider, exit_ip)),
                 ('all', (exit_ip, exit_ip, exit_ip))]
        for index, (mode, expected) in enumerate(modes):
            profile = (root / f'{mode}.vpn').read_text().strip()
            assert re.fullmatch(r'vpn://[A-Za-z0-9_-]+', profile)
            with (root / f'client-{mode}.log').open('wb') as log:
                client = subprocess.Popen([APP, '--import', profile, '--connect', str(index)],
                                          stdout=log, stderr=subprocess.STDOUT)
                try:
                    for _ in range(24):
                        if client.poll() is not None:
                            raise RuntimeError('The COLDWIRE client exited before connecting')
                        tunnel = route(targets[-1]).get('interface', '')
                        if tunnel.startswith('utun'):
                            status = subprocess.check_output(['/sbin/ifconfig', tunnel], text=True)
                            if f'inet 10.8.1.{index + 2} ' in status:
                                break
                        time.sleep(.5)
                    else:
                        raise RuntimeError(f'No AWG route appeared in mode {mode}')
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
                    notes = [line for line in lines if re.search(r'connectionState|split tunneling|error|handshake', line, re.I)]
                    for note in notes[-10:]:
                        print(re.sub(r'[A-Za-z0-9+/_=-]{40,}', '[redacted]', note), flush=True)
                    raise
                finally:
                    deactivate()
                    if client.poll() is None:
                        client.terminate()
                        try:
                            client.wait(timeout=4)
                        except subprocess.TimeoutExpired:
                            client.kill()
                            client.wait()
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
        time.sleep(100)
        if not marker.exists():
            restore_gateway(sys.argv[2], sys.argv[3], marker)
    else:
        main(Path(sys.argv[1]))
