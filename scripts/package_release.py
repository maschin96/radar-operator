#!/usr/bin/env python3
"""Create versioned, deterministic ZIP containers, source archive and SHA-256 sums.

Determinism covers packaging identical inputs. Godot/platform binary reproducibility
is a separate property and is not asserted here.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import subprocess
import time
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()


def package(output, builds, mode):
    if git('status', '--porcelain', '--untracked-files=normal'):
        raise RuntimeError('Release packaging requires a clean working tree so source and binaries match')
    version = re.search(r'^config/version="([^"]+)"', (ROOT / 'project.godot').read_text(), re.M)[1]
    commit = git('rev-parse', 'HEAD')
    epoch = int(git('show', '-s', '--format=%ct', 'HEAD'))
    timestamp = time.gmtime(max(epoch, 315532800))[:6]
    output.mkdir(parents=True, exist_ok=True)
    metadata = {'version': version, 'commit': commit, 'godot': '4.7.2', 'build_mode': mode,
                'license': 'GPL-3.0-or-later', 'source_archive': f'RadarOperator-{version}-source.zip',
                'source_url': f'https://github.com/maschin96/radar-operator/tree/{commit}'}
    shared = {'VERSION.json': json.dumps(metadata, indent=2).encode(),
              'LICENSE': (ROOT / 'LICENSE').read_bytes(),
              'GODOT-LICENSE.txt': (ROOT / 'docs/GODOT-LICENSE.txt').read_bytes(),
              'GODOT-COPYRIGHT.txt': (ROOT / 'docs/GODOT-COPYRIGHT.txt').read_bytes(),
              'INSTALL.md': (ROOT / 'docs/installation.md').read_bytes(),
              'CHANGELOG.md': (ROOT / 'CHANGELOG.md').read_bytes(),
              'KNOWN-ISSUES.md': (ROOT / 'docs/qa-und-bekannte-einschraenkungen.md').read_bytes()}
    archives = []
    for target in ['macos', 'windows', 'linux']:
        files = dict((name, (content, 0o100644)) for name, content in shared.items())
        if target == 'macos':
            with zipfile.ZipFile(builds / target / 'RadarOperator.zip') as source:
                for info in source.infolist():
                    if not info.is_dir():
                        files[info.filename] = (source.read(info), info.external_attr >> 16 or 0o100644)
            if not any(name.endswith('.app/Contents/MacOS/Radar Operator') or '.app/Contents/MacOS/' in name for name in files):
                raise RuntimeError('macOS app executable missing')
        else:
            executable = 'RadarOperator.exe' if target == 'windows' else 'RadarOperator.x86_64'
            for name in [executable, 'RadarOperator.pck']:
                path = builds / target / name
                if not path.is_file() or not path.stat().st_size:
                    raise RuntimeError(f'Required runtime file missing: {path}')
                files[name] = (path.read_bytes(), 0o100755 if name == executable else 0o100644)
        archive_path = output / f'RadarOperator-{version}-{target}.zip'
        with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, (content, mode_bits) in sorted(files.items()):
                info = zipfile.ZipInfo(name, timestamp)
                info.create_system = 3
                info.external_attr = mode_bits << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, content)
        archives.append(archive_path)
    source_path = output / metadata['source_archive']
    subprocess.run(['git', 'archive', '--format=zip', f'--prefix=RadarOperator-{version}/', f'--output={source_path.resolve()}', commit], cwd=ROOT, check=True)
    archives.append(source_path)
    sums = []
    for path in sorted(archives):
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None:
                raise RuntimeError(f'Corrupt archive: {path}')
        with path.open('rb') as stream:
            sums.append(f'{hashlib.file_digest(stream, "sha256").hexdigest()}  {path.name}\n')
    (output / 'SHA256SUMS.txt').write_text(''.join(sums))
    print(''.join(sums), end='')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'builds/release')
    parser.add_argument('--builds', type=Path, default=ROOT / 'builds')
    parser.add_argument('--mode', choices=['debug', 'release'], default='release')
    args = parser.parse_args()
    package(args.output, args.builds, args.mode)
