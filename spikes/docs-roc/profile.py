"""Capture samply CPU profiles with isolated compiler caches.

python3 spikes/docs-roc/profile.py /path/to/symbolized/roc /path/to/cache/roc/packages
Use an optimized compiler built from the nightly revision with -Dstrip=false.
Timings under profiling are not benchmark results. Run from the repository root.
"""

import json
import hashlib
import gzip
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile

compiler = str(Path(sys.argv[1]).resolve())
packages = Path(sys.argv[2]).resolve()
root = Path(sys.argv[3] if len(sys.argv) > 3 else ".roc-ansi-tmp/docs-roc-profiles").resolve()
root.mkdir(parents=True, exist_ok=True)
cases = {
    "check-import": ["check", "spikes/docs-roc/repro/import-only.roc"],
    "build-speed": ["build", "--opt=speed", "--timings", "spikes/docs-roc/main.roc", f"--output={root / 'renderer-speed'}"],
}
(root / "metadata.json").write_text(json.dumps({
    "compiler": subprocess.check_output([compiler, "version"], text=True).strip(),
    "compiler_sha256": hashlib.sha256(Path(compiler).read_bytes()).hexdigest(),
    "platform": platform.platform(),
    "samply": subprocess.check_output(["samply", "--version"], text=True).strip(),
    "sampling_hz": 500,
    "policy": "Fresh compiler cache per capture, package sources shared. CPU samples, not allocation measurements.",
}, indent=2) + "\n")
for name, args in cases.items():
    with tempfile.TemporaryDirectory(prefix="roc-profile-") as temporary:
        cache = Path(temporary)
        (cache / "roc").mkdir()
        (cache / "roc/packages").symlink_to(packages, target_is_directory=True)
        print(f"Profiling {name}", flush=True)
        with (root / f"{name}.log").open("w") as log:
            subprocess.run(
                ["samply", "record", "--save-only", "--rate", "500", "--output", str(root / f"{name}.json.gz"), "--", compiler, *args],
                env={**os.environ, "XDG_CACHE_HOME": str(cache)}, stdout=log, stderr=log, check=True,
            )
        capture = root / f"{name}.json.gz"
        data = capture.read_bytes()
        if data[:2] != b"\x1f\x8b":
            capture.write_bytes(gzip.compress(data))
        print(f"Saved {name}", flush=True)
