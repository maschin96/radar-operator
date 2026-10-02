#!/usr/bin/env python3
"""Extract one platform package and start its native executable without graphics."""
import hashlib
from pathlib import Path
import platform
import stat
import subprocess
import sys
import tempfile
import zipfile

folder = Path(sys.argv[1]).resolve()
target = {'Linux': 'linux', 'Darwin': 'macos', 'Windows': 'windows'}[platform.system()]
archive_path, = folder.glob(f'RadarOperator-*-{target}.zip')
sums = dict(line.split()[::-1] for line in (folder / 'SHA256SUMS.txt').read_text().splitlines())
with archive_path.open('rb') as stream:
    assert hashlib.file_digest(stream, 'sha256').hexdigest() == sums[archive_path.name]
with tempfile.TemporaryDirectory(prefix='radar-export-') as directory:
    root = Path(directory)
    with zipfile.ZipFile(archive_path) as archive:
        archive.extractall(root)
        for info in archive.infolist():
            path = root / info.filename
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode):
                content = path.read_text()
                path.unlink()
                path.symlink_to(content)
            elif path.is_file():
                path.chmod(mode & 0o777)
    assert (root / 'LICENSE').is_file() and (root / 'VERSION.json').is_file()
    if target == 'macos':
        executable, = root.glob('*.app/Contents/MacOS/*')
    else:
        executable = root / ('RadarOperator.exe' if target == 'windows' else 'RadarOperator.x86_64')
    completed = subprocess.run([str(executable), '--headless', '--audio-driver', 'Dummy', '--quit-after', '60'],
                               cwd=root, capture_output=True, text=True, timeout=90)
    output = completed.stdout + completed.stderr
    print(output)
    if completed.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
        raise SystemExit('Native export smoke failed')
