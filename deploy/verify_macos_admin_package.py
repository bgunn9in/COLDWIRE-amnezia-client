from argparse import ArgumentParser
import json
import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory


def main():
    parser = ArgumentParser(description='Verify the packaged COLDWIRE macOS administration helper.')
    parser.add_argument('package', type=Path)
    package = parser.parse_args().package.resolve()

    with TemporaryDirectory(prefix='coldwire-package-') as directory:
        scratch = Path(directory)
        expanded = scratch / 'expanded'
        subprocess.run(['pkgutil', '--expand-full', package, expanded], check=True, timeout=180)
        apps = [app for app in expanded.rglob('AmneziaVPN.app') if app.is_dir()]
        if len(apps) != 1:
            raise SystemExit('Expected one COLDWIRE app in the package.')

        app = apps[0]
        helper = app / 'Contents/MacOS/coldwire-admin-helper'
        if not helper.is_file() or not os.access(helper, os.X_OK):
            raise SystemExit('The package is missing an executable COLDWIRE administration helper.')

        subprocess.run(['lipo', helper, '-verify_arch', 'arm64', 'x86_64'], check=True)
        subprocess.run(['codesign', '--verify', '--strict', '--all-architectures', helper], check=True)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', '--all-architectures', app], check=True)

        request = json.dumps({'action': 'state', 'stateKey': '0' * 64})
        result = subprocess.run([helper, '--state', scratch / 'operator.bin'], input=request, text=True,
                                stdout=subprocess.PIPE, check=True, timeout=45)
        reply = json.loads(result.stdout)
        if not isinstance(reply, dict) or reply.get('ok') is not True or reply.get('installed') is not False:
            raise SystemExit('The COLDWIRE administration helper failed its empty-state check.')

        subprocess.run([app / 'Contents/MacOS/AmneziaVPN', '--version'],
                       env=dict(os.environ, QT_QPA_PLATFORM='cocoa'), check=True, timeout=45)

    print('Verified both COLDWIRE binaries, signatures and the administration helper state.')


if __name__ == '__main__':
    main()
