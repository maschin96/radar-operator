#!/usr/bin/env python3
"""Install the pinned official editor and optionally templates, verifying SHA-512."""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import urllib.request
import zipfile

VERSION = '4.7.2'
BASE = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/'


def install(destination, templates=False):
    destination.mkdir(parents=True, exist_ok=True)
    names = {'Linux': f'Godot_v{VERSION}-stable_linux.x86_64.zip',
             'Darwin': f'Godot_v{VERSION}-stable_macos.universal.zip',
             'Windows': f'Godot_v{VERSION}-stable_win64.exe.zip'}
    system = platform.system()
    checks = urllib.request.urlopen(BASE + 'SHA512-SUMS.txt').read().decode()
    sums = {line.split()[-1].lstrip('*'): line.split()[0] for line in checks.splitlines() if len(line.split()) == 2}

    def download(name):
        target = destination / name
        urllib.request.urlretrieve(BASE + name, target)
        with target.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha512').hexdigest()
        if digest != sums[name]:
            raise RuntimeError(f'SHA-512 mismatch: {name}')
        return target

    with zipfile.ZipFile(download(names[system])) as archive:
        archive.extractall(destination)
    executables = {'Linux': destination / f'Godot_v{VERSION}-stable_linux.x86_64',
                   'Darwin': destination / 'Godot.app/Contents/MacOS/Godot',
                   'Windows': destination / f'Godot_v{VERSION}-stable_win64_console.exe'}
    executable = executables[system]
    executable.chmod(0o755)
    if templates:
        roots = {'Linux': Path.home() / '.local/share/godot',
                 'Darwin': Path.home() / 'Library/Application Support/Godot',
                 'Windows': Path(os.environ.get('APPDATA', '.')) / 'Godot'}
        template_dir = roots[system] / 'export_templates' / f'{VERSION}.stable'
        template_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(download(f'Godot_v{VERSION}-stable_export_templates.tpz')) as archive:
            for member in archive.infolist():
                if member.is_dir():
                    continue
                relative = Path(member.filename).relative_to('templates')
                target = template_dir / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(member))
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'], 'a') as stream:
            stream.write(f'GODOT_BIN={executable.as_posix()}\n')
    print(executable)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    parser.add_argument('--templates', action='store_true')
    args = parser.parse_args()
    install(args.destination, args.templates)
