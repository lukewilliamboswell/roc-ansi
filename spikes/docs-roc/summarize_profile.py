"""Name samply frames and summarize CPU time using its local symbol server.

python3 spikes/docs-roc/summarize_profile.py /path/to/profile.json.gz
Requires samply and the original binary/debug info. Writes a named profile and
CPU summary alongside the capture. Uses localhost port 38478 temporarily.
"""

import collections
import gzip
import json
from pathlib import Path
import subprocess
import sys
import urllib.parse
import urllib.request

path = Path(sys.argv[1])
opener = gzip.open if path.read_bytes()[:2] == b'\x1f\x8b' else open
with opener(path, 'rt') as f:
    profile = json.load(f)
server = subprocess.Popen(['samply', 'load', '--no-open', '--port', '38478', str(path)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
try:
    for line in server.stdout:
        if 'symbolServer=' in line:
            base = urllib.parse.unquote(line.split('symbolServer=')[1].strip())
            break
    else:
        raise RuntimeError('No symbolication endpoint')
    memory_map = [[lib['debugName'], lib['breakpadId']] for lib in profile['libs']]
    frame_keys = {}
    addresses = []
    for ti, thread in enumerate(profile['threads']):
        frames, funcs, resources = thread['frameTable'], thread['funcTable'], thread['resourceTable']
        for fi in range(frames['length']):
            resource = funcs['resource'][frames['func'][fi]]
            if resource is not None and resource >= 0:
                lib = resources['lib'][resource]
                if lib is not None:
                    key = (lib, frames['address'][fi])
                    if key not in frame_keys:
                        frame_keys[key] = len(addresses)
                        addresses.append(key)
    names = {}
    for start in range(0, len(addresses), 3000):
        subset = addresses[start:start + 3000]
        body = {'jobs': [{'memoryMap': memory_map, 'stacks': [[[lib, address]] for lib, address in subset]}]}
        req = urllib.request.Request(base + '/symbolicate/v5', json.dumps(body).encode(), {'Content-Type': 'application/json'})
        result = json.load(urllib.request.urlopen(req, timeout=180))['results'][0]['stacks']
        for key, stack in zip(subset, result):
            names[key] = [frame.get('function', frame.get('module', '?') + ':' + frame.get('module_offset', '?')) for frame in stack]
    inclusive, self_counts = collections.Counter(), collections.Counter()
    total = 0
    for thread in profile['threads']:
        frames, funcs, resources = thread['frameTable'], thread['funcTable'], thread['resourceTable']
        frame_names = {}
        for fi in range(frames['length']):
            fn = frames['func'][fi]
            resource = funcs['resource'][fn]
            lib = resources['lib'][resource] if resource is not None and resource >= 0 else None
            resolved = names.get((lib, frames['address'][fi]), [thread['stringArray'][funcs['name'][fn]]])
            frame_names[fi] = resolved
            # Embed a name for portable browsing without the compiler binary.
            index = len(thread['stringArray'])
            thread['stringArray'].append(' → '.join(resolved))
            funcs['name'][fn] = index
        stacks = thread['stackTable']
        for si, stack in enumerate(thread['samples']['stack']):
            if stack is None:
                continue
            weight = thread['samples']['threadCPUDelta'][si] or 0
            if weight <= 0:
                continue
            total += weight
            leaf = frame_names[stacks['frame'][stack]][-1]
            self_counts[leaf] += weight
            seen = set()
            while stack is not None:
                seen.update(frame_names[stacks['frame'][stack]])
                stack = stacks['prefix'][stack]
            for name in seen:
                inclusive[name] += weight
    def rows(counter):
        return [{'function': fn, 'cpu_percent': round(100 * weight / total, 2), 'sampled_cpu_seconds': round(weight / 1e6, 4)} for fn, weight in counter.most_common(80)]
    summary = {'method': 'All threads; threadCPUDelta weighted CPU samples; inclusive functions deduplicated per stack; percentages overlap across ancestors; not allocation profiling.', 'sampled_cpu_seconds': total / 1e6, 'self': rows(self_counts), 'inclusive': rows(inclusive)}
    dest = path.with_name(path.name.replace('.json.gz', '-summary.json'))
    dest.write_text(json.dumps(summary, indent=2) + '\n')
    portable = path.with_name(path.name.replace('.json.gz', '-named.json.gz'))
    profile['meta']['symbolicated'] = True
    with gzip.open(portable, 'wt') as f:
        json.dump(profile, f)
    print(dest)
    print(json.dumps({'self': summary['self'][:12], 'inclusive': summary['inclusive'][:18]}, indent=2))
finally:
    server.terminate()
    server.wait()
