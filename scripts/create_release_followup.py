#!/usr/bin/env python3
"""Create a GitHub-signed release follow-up PR without overwriting branch work."""
from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def run(args: list[str], data: str | None = None) -> str:
    return subprocess.run(args, input=data, text=True, capture_output=True, check=True, cwd=ROOT).stdout


def api(endpoint: str, data: dict | None = None):
    args = ['gh', 'api', endpoint]
    if data is not None:
        args.extend(['--input', '-'])
    return json.loads(run(args, json.dumps(data) if data is not None else None))


def changes() -> tuple[dict, dict[str, str | None]]:
    paths = set(run(['git', 'diff', '--name-only', '-z', 'HEAD', '--', 'examples']).split('\0'))
    paths.update(run(['git', 'ls-files', '--others', '--exclude-standard', '-z', '--', 'examples']).split('\0'))
    paths.discard('')
    additions, deletions, blobs = [], [], {}
    for name in sorted(paths):
        path = ROOT / name
        if path.is_symlink() or not path.resolve().is_relative_to(ROOT):
            raise ValueError(f'Refusing a symlink or escaped follow-up path: {name}')
        if path.exists():
            content = path.read_bytes()
            additions.append({'path': name, 'contents': base64.b64encode(content).decode()})
            blobs[name] = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
        else:
            deletions.append({'path': name})
            blobs[name] = None
    return {'additions': additions, 'deletions': deletions}, blobs


def verify_commit(commit: dict, base: str, blobs: dict[str, str | None]) -> None:
    if (not commit['commit']['verification']['verified']
            or (commit.get('author') or {}).get('login') != 'github-actions[bot]'
            or len(commit['parents']) != 1 or commit['parents'][0]['sha'] != base
            or {item['filename'] for item in commit['files']} != set(blobs)):
        raise ValueError('Existing follow-up branch is not the expected signed bot commit; inspect it manually')
    for item in commit['files']:
        expected = blobs[item['filename']]
        if (expected is None and item['status'] != 'removed') or (expected is not None and item['sha'] != expected):
            raise ValueError('Follow-up branch content differs; refusing to overwrite it')


def main() -> None:
    repository = os.environ['GITHUB_REPOSITORY']
    version = os.environ['RELEASE_VERSION']
    base_branch = os.environ['GITHUB_REF_NAME']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Invalid repository')
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?', version):
        raise ValueError('Invalid release version')
    base = run(['git', 'rev-parse', 'HEAD']).strip()
    if base != os.environ['GITHUB_SHA']:
        raise ValueError('Follow-up checkout does not match the release commit')
    file_changes, blobs = changes()
    if not blobs:
        print('No release follow-up changes')
        return
    branch = f'release-followup/{version}'
    title = f'Update example URLs for {version}'
    refs = api(f'repos/{repository}/git/matching-refs/heads/{branch}')
    refs = [ref for ref in refs if ref['ref'] == f'refs/heads/{branch}']
    if not refs:
        api(f'repos/{repository}/git/refs', {'ref': f'refs/heads/{branch}', 'sha': base})
        sha = base
    else:
        sha = refs[0]['object']['sha']
    if sha == base:
        result = api('graphql', {'query': '''mutation($input: CreateCommitOnBranchInput!) {
          createCommitOnBranch(input: $input) { commit { oid } }
        }''', 'variables': {'input': {
            'branch': {'repositoryNameWithOwner': repository, 'branchName': branch},
            'expectedHeadOid': base, 'message': {'headline': title}, 'fileChanges': file_changes,
        }}})
        sha = result['data']['createCommitOnBranch']['commit']['oid']
    verify_commit(api(f'repos/{repository}/commits/{sha}'), base, blobs)
    owner = repository.split('/')[0]
    prs = api(f'repos/{repository}/pulls?state=open&head={owner}:{branch}')
    if prs:
        if len(prs) != 1 or prs[0]['base']['ref'] != base_branch or prs[0]['head']['sha'] != sha:
            raise ValueError('Existing release PR differs from this follow-up')
        print(prs[0]['html_url'])
        return
    pr = api(f'repos/{repository}/pulls', {
        'head': branch, 'base': base_branch, 'title': title,
        'body': f'Release follow-up for {version}.\n\nUpdated checked-in example package URLs. '
                'The published examples were validated after upload. Review and merge this PR to update main.',
    })
    print(pr['html_url'])


if __name__ == '__main__':
    main()
