#!/usr/bin/env python3
"""Store generated versioned docs in release assets and restore them for Pages."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import tempfile
from urllib.request import Request, urlopen

REPOSITORY = 'lukewilliamboswell/roc-ansi'
VERSION = re.compile(r'[0-9]+\.[0-9]+\.[0-9]+')


def version(value: str) -> str:
    if not VERSION.fullmatch(value):
        raise ValueError(f'Invalid documentation version: {value}')
    return value


def asset_name(value: str) -> str:
    return f'roc-ansi-docs-{version(value)}.tar.gz'


def pack(docs_root: Path, value: str, output: Path) -> Path:
    source = docs_root / version(value)
    if not (source / 'index.html').is_file():
        raise ValueError(f'Missing generated documentation: {source}/index.html')
    output.mkdir(parents=True, exist_ok=True)
    destination = output / asset_name(value)
    # Stable metadata makes retries comparable without replacing release assets.
    with destination.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', mtime=0, filename='') as zipped:
        with tarfile.open(fileobj=zipped, mode='w') as archive:
            for path in sorted(source.rglob('*')):
                if path.is_symlink():
                    raise ValueError(f'Refusing documentation symlink: {path}')
                if not path.is_file():
                    continue
                info = archive.gettarinfo(str(path), arcname=f'{value}/{path.relative_to(source).as_posix()}')
                info.uid = info.gid = info.mtime = 0
                info.uname = info.gname = ''
                info.mode = 0o644
                with path.open('rb') as content:
                    archive.addfile(info, content)
    print(f'Packed {destination}')
    return destination


def restore(archive_path: Path, value: str, output: Path) -> None:
    version(value)
    with tarfile.open(archive_path, 'r:gz') as archive:
        members = archive.getmembers()
        for member in members:
            path = PurePosixPath(member.name)
            if ('\\' in member.name or path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] != value
                    or not (member.isfile() or member.isdir())):
                raise ValueError(f'Unsafe documentation archive entry: {member.name}')
        if not any(member.name == f'{value}/index.html' and member.isfile() for member in members):
            raise ValueError(f'Archive lacks {value}/index.html')
        output.mkdir(parents=True, exist_ok=True)
        # Stage outside the destination tree; never extract links or follow an
        # existing directory symlink in the output. Callers use isolated output.
        if (output / value).exists() or (output / value).is_symlink():
            raise ValueError(f'Documentation destination already exists: {output / value}')
        with tempfile.TemporaryDirectory(prefix='docs-restore-', dir=output) as tmp:
            stage = Path(tmp)
            for member in members:
                target = stage / member.name
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with archive.extractfile(member) as source, target.open('wb') as destination:
                        shutil.copyfileobj(source, destination)
            shutil.move(str(stage / value), str(output / value))


def github(endpoint: str):
    if os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN'):
        result = subprocess.run(['gh', 'api', endpoint], check=True, capture_output=True, text=True)
        return json.loads(result.stdout)
    request = Request('https://api.github.com/' + endpoint, headers={'Accept': 'application/vnd.github+json', 'User-Agent': 'roc-ansi-docs'})
    with urlopen(request, timeout=60) as response:
        return json.load(response)


def fetch(output: Path) -> None:
    page = 1
    while True:
        releases = github(f'repos/{REPOSITORY}/releases?per_page=100&page={page}')
        for release in releases:
            value = release['tag_name']
            if release['draft'] or release['prerelease'] or not VERSION.fullmatch(value):
                continue
            assets = [item for item in release['assets'] if item['name'] == asset_name(value)]
            if not assets:
                continue  # Some older releases never had documentation archives.
            if len(assets) != 1:
                raise ValueError(f'Multiple documentation assets for {value}')
            asset = assets[0]
            expected_url = f'https://github.com/{REPOSITORY}/releases/download/{value}/{asset_name(value)}'
            if asset['browser_download_url'] != expected_url:
                raise ValueError('Unexpected documentation asset URL')
            with tempfile.TemporaryDirectory(prefix='roc-docs-download-') as tmp:
                archive = Path(tmp) / asset_name(value)
                with urlopen(expected_url, timeout=60) as response, archive.open('wb') as target:
                    shutil.copyfileobj(response, target)
                digest = asset.get('digest')
                if digest and digest != 'sha256:' + hashlib.sha256(archive.read_bytes()).hexdigest():
                    raise ValueError(f'Documentation digest mismatch for {value}')
                restore(archive, value, output)
            print(f'Restored release documentation for {value}')
        if len(releases) < 100:
            return
        page += 1


def publish(archive: Path, value: str) -> None:
    if archive.name != asset_name(value):
        raise ValueError('Documentation archive name does not match its release')
    release = github(f'repos/{REPOSITORY}/releases/tags/{value}')
    existing = [item for item in release['assets'] if item['name'] == archive.name]
    if existing:
        digest = 'sha256:' + hashlib.sha256(archive.read_bytes()).hexdigest()
        if len(existing) != 1 or existing[0].get('digest') != digest:
            raise ValueError('Existing documentation asset differs; refusing to replace it')
        print(f'Documentation asset already published for {value}')
        return
    subprocess.run(['gh', 'release', 'upload', value, str(archive), '--repo', REPOSITORY], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    package = commands.add_parser('pack')
    package.add_argument('version')
    package.add_argument('--docs-root', type=Path, default=Path('.roc-ansi-tmp/release-docs'))
    package.add_argument('--output', type=Path, default=Path('.roc-ansi-tmp/docs-assets'))
    download = commands.add_parser('fetch')
    download.add_argument('--output', type=Path, required=True, help='New directory for restored versioned docs')
    upload = commands.add_parser('publish')
    upload.add_argument('version')
    upload.add_argument('archive', type=Path)
    args = parser.parse_args()
    if args.command == 'pack':
        pack(args.docs_root, args.version, args.output)
    elif args.command == 'fetch':
        if args.output.exists():
            raise ValueError('Use a new output directory for fetched release docs')
        args.output.mkdir(parents=True)
        fetch(args.output)
    else:
        publish(args.archive, args.version)


if __name__ == '__main__':
    main()
