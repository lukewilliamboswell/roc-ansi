"""Separate compiler/runner RSS from the standalone PDF renderer.

Usage: python3 spikes/docs-roc/probe_memory.py /path/to/roc /path/to/docs-roc
Run from the repository root; /usr/bin/time reports the whole process peak.
"""

import json
import platform
import re
import subprocess
import sys
from pathlib import Path

compiler, renderer = (str(Path(value).resolve()) for value in sys.argv[1:3])
root = Path(".roc-ansi-tmp/docs-roc-memory")
root.mkdir(parents=True, exist_ok=True)
minimal = root / "minimal.md"
minimal.write_text("# Memory control\n\nOne short paragraph.\n")
sample = "spikes/docs-roc/chapter.md"
cases = [
    ("check_only", [compiler, "check", "spikes/docs-roc/main.roc"]),
    ("source_minimal", [compiler, "spikes/docs-roc/main.roc", "--", str(minimal), str(root / "source-minimal")]),
    ("source_sample", [compiler, "spikes/docs-roc/main.roc", "--", sample, str(root / "source-sample")]),
    ("native_minimal", [renderer, str(minimal), str(root / "native-minimal")]),
    ("native_sample", [renderer, sample, str(root / "native-sample")]),
]
results = {
    "platform": platform.platform(),
    "compiler": subprocess.check_output([compiler, "version"], text=True).strip(),
    "cases": {},
}
for name, command in cases:
    darwin = platform.system() == "Darwin"
    result = subprocess.run(
        ["/usr/bin/time", "-l" if darwin else "-v"] + command,
        text=True,
        capture_output=True,
        check=True,
    )
    (root / f"{name}.log").write_text(result.stdout + result.stderr)
    if darwin:
        rss = int(re.search(r"(\d+)\s+maximum resident set size", result.stderr)[1])
    else:
        rss = int(re.search(r"Maximum resident set size \(kbytes\):\s*(\d+)", result.stderr)[1]) * 1024
    results["cases"][name] = {"peak_rss_bytes": rss, "stdout": result.stdout.strip()}
    print(f"{name}: {rss / 1_000_000:.1f} MB peak RSS", flush=True)

for fixture in ["minimal", "sample"]:
    assert (root / f"source-{fixture}/manual.pdf").read_bytes() == (root / f"native-{fixture}/manual.pdf").read_bytes()
print("PASS source and native PDFs match byte-for-byte for both document sizes")
(root / "measurements.json").write_text(json.dumps(results, indent=2) + "\n")
