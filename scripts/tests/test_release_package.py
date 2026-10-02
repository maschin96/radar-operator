"""Packaging regression checks with synthetic binaries and an isolated source repo."""
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('package_release', Path(__file__).parents[1] / 'package_release.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'docs').mkdir()
        (self.root / 'project.godot').write_text('config/version="0.5.0"\n')
        for name in ['LICENSE', 'CHANGELOG.md', 'docs/installation.md',
                     'docs/qa-und-bekannte-einschraenkungen.md',
                     'docs/GODOT-LICENSE.txt', 'docs/GODOT-COPYRIGHT.txt']:
            (self.root / name).write_text(name)
        self.command('init')
        self.command('add', '.')
        self.command('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-m', 'fixture')
        self.builds = self.root / '.git/builds'
        for platform in ['macos', 'windows', 'linux']:
            (self.builds / platform).mkdir(parents=True)
        with zipfile.ZipFile(self.builds / 'macos/RadarOperator.zip', 'w') as archive:
            info = zipfile.ZipInfo('Radar Operator.app/Contents/MacOS/Radar Operator')
            info.external_attr = 0o100755 << 16
            archive.writestr(info, b'executable')
        for platform, executable in [('windows', 'RadarOperator.exe'), ('linux', 'RadarOperator.x86_64')]:
            (self.builds / platform / executable).write_bytes(b'executable')
            (self.builds / platform / 'RadarOperator.pck').write_bytes(b'runtime')

    def command(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, stderr=subprocess.DEVNULL)

    def test_deterministic_packages_include_runtime_source_and_licenses(self):
        first, second = self.root / '.git/first', self.root / '.git/second'
        with patch.object(MODULE, 'ROOT', self.root):
            MODULE.package(first, self.builds, 'release')
            MODULE.package(second, self.builds, 'release')
        self.assertEqual((first / 'SHA256SUMS.txt').read_bytes(), (second / 'SHA256SUMS.txt').read_bytes())
        for line in (first / 'SHA256SUMS.txt').read_text().splitlines():
            digest, name = line.split()
            self.assertEqual(digest, hashlib.sha256((first / name).read_bytes()).hexdigest())
        with zipfile.ZipFile(first / 'RadarOperator-0.5.0-linux.zip') as archive:
            for name in ['LICENSE', 'GODOT-LICENSE.txt', 'GODOT-COPYRIGHT.txt', 'VERSION.json', 'RadarOperator.pck']:
                self.assertIn(name, archive.namelist())
            self.assertTrue(archive.getinfo('RadarOperator.x86_64').external_attr >> 16 & 0o111)
        with zipfile.ZipFile(first / 'RadarOperator-0.5.0-source.zip') as archive:
            self.assertIn('RadarOperator-0.5.0/project.godot', archive.namelist())

    def test_dirty_source_and_missing_runtime_are_rejected(self):
        with patch.object(MODULE, 'ROOT', self.root):
            (self.root / 'uncommitted.txt').write_text('new source')
            with self.assertRaisesRegex(RuntimeError, 'clean working tree'):
                MODULE.package(self.root / '.git/output', self.builds, 'release')
            (self.root / 'uncommitted.txt').unlink()
            (self.builds / 'windows/RadarOperator.pck').unlink()
            with self.assertRaisesRegex(RuntimeError, 'runtime file missing'):
                MODULE.package(self.root / '.git/output', self.builds, 'release')
