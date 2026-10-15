"""Measure small controls in separate cold compiler caches, sharing packages.

Usage: python3 spikes/docs-roc/repro/measure.py /path/to/roc /path/to/cache/roc/packages
Run from repository root. Needs /usr/bin/time; no third-party Python modules.
"""

import json
import os
import platform
import re
import subprocess
import sys
import tempfile
from pathlib import Path

compiler = str(Path(sys.argv[1]).resolve())
packages = Path(sys.argv[2]).resolve()
root = Path(".roc-ansi-tmp/docs-roc-repro")
root.mkdir(parents=True, exist_ok=True)
results = {
    "compiler": subprocess.check_output([compiler, "version"], text=True).strip(),
    "platform": platform.platform(),
    "cache_policy": "Each case has an empty compiler cache and shares only downloaded package sources.",
    "cases": {},
}
if len(sys.argv) > 3 and (root / "measurements.json").exists():
    previous = json.loads((root / "measurements.json").read_text())
    assert previous["compiler"] == results["compiler"]
    results = previous
for name in sys.argv[3:] or ["hello", "markdown", "import-only", "pdf", "runtime-pdf"]:
    for mode in ["check", "run"]:
        key = f"{name}-{mode}"
        with tempfile.TemporaryDirectory(prefix="roc-pdf-memory-") as temporary:
            cache = Path(temporary)
            (cache / "roc").mkdir()
            (cache / "roc/packages").symlink_to(packages, target_is_directory=True)
            env = {**os.environ, "XDG_CACHE_HOME": str(cache)}
            command = [compiler]
            if mode == "check":
                command.append("check")
            command.append(f"spikes/docs-roc/repro/{name}.roc")
            darwin = platform.system() == "Darwin"
            result = subprocess.run(
                ["/usr/bin/time", "-l" if darwin else "-v"] + command,
                env=env,
                text=True,
                capture_output=True,
            )
            (root / f"{key}.log").write_text(result.stdout + result.stderr)
            result.check_returncode()
            if darwin:
                rss = int(re.search(r"(\d+)\s+maximum resident set size", result.stderr)[1])
            else:
                rss = int(re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", result.stderr)[1]) * 1024
            results["cases"][key] = {"peak_rss_bytes": rss, "stdout": result.stdout.strip()}
            print(f"{key}: {rss / 1_000_000:.1f} MB peak RSS", flush=True)
            (root / "measurements.json").write_text(json.dumps(results, indent=2) + "\n")
