"""Cold-cache source/build matrix; downloaded packages are shared.

python3 spikes/docs-roc/matrix.py /path/to/roc /path/to/cache/roc/packages
Each command has a 180-second cap. Run from the repository root.
"""

import hashlib
import json
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import tempfile
import time

compiler = str(Path(sys.argv[1]).resolve())
packages = Path(sys.argv[2]).resolve()
root = Path(".roc-ansi-tmp/docs-roc-matrix").resolve()
root.mkdir(parents=True, exist_ok=True)
results = {
    "compiler": subprocess.check_output([compiler, "version"], text=True).strip(),
    "compiler_sha256": hashlib.sha256(Path(compiler).read_bytes()).hexdigest(),
    "platform": platform.platform(),
    "policy": "Sequential, one observation per command, empty compiler cache per source/build case; package sources shared; native runs repeated three times. 180s cap. Decimal RSS bytes.",
    "cases": {},
}


def measure(name, command, env):
    darwin = platform.system() == "Darwin"
    start = time.monotonic()
    with (root / f"{name}.log").open("w+") as log:
        process = subprocess.Popen(
            ["/usr/bin/time", "-l" if darwin else "-v", *command],
            stdout=log, stderr=log, env=env, start_new_session=True,
        )
        try:
            code = process.wait(timeout=180)
            status = "ok" if code == 0 else f"exit {code}"
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            status = "timeout (180s); RSS unavailable"
        elapsed = time.monotonic() - start
        log.seek(0)
        output = log.read()
    pattern = r"(\d+)\s+maximum resident set size" if darwin else r"Maximum resident set size \(kbytes\):\s*(\d+)"
    match = re.search(pattern, output)
    if darwin and status == "ok":
        # Popen.wait(timeout=...) polls and overstates short native runs.
        elapsed = float(re.search(r"([\d.]+) real\s+", output)[1])
    record = {"command": command, "status": status, "wall_seconds": elapsed,
              "peak_rss_bytes": int(match[1]) * (1 if darwin else 1024) if match else None}
    render_time = re.search(r"total=(\d+)ms", output)
    if render_time:
        record["renderer_seconds"] = int(render_time[1]) / 1000
    results["cases"][name] = record
    (root / "measurements.json").write_text(json.dumps(results, indent=2) + "\n")
    print(name, json.dumps(record), flush=True)
    return status == "ok"


for mode in ["dev", "speed", "size", "interpreter"]:
    for operation in (["source", "build"] if mode != "interpreter" else ["source"]):
        name = f"{mode}-{operation}"
        with tempfile.TemporaryDirectory(prefix="roc-matrix-") as temporary:
            cache = Path(temporary)
            (cache / "roc").mkdir()
            (cache / "roc/packages").symlink_to(packages, target_is_directory=True)
            env = {**os.environ, "XDG_CACHE_HOME": str(cache)}
            output = root / name
            binary = root / f"renderer-{mode}"
            if operation == "source":
                command = [compiler, "run", f"--opt={mode}", "spikes/docs-roc/main.roc", "--", "spikes/docs-roc/chapter.md", str(output)]
            else:
                command = [compiler, "build", f"--opt={mode}", "--timings", "spikes/docs-roc/main.roc", f"--output={binary}"]
            if measure(name, command, env) and operation == "build":
                for repeat in range(3):
                    measure(f"{mode}-native-{repeat + 1}", [str(binary), "spikes/docs-roc/chapter.md", str(root / f"{mode}-native")], env)

hashes = {}
for pdf in sorted(root.glob("*/manual.pdf")):
    hashes[str(pdf.relative_to(root))] = hashlib.sha256(pdf.read_bytes()).hexdigest()
results["pdf_sha256"] = hashes
assert len(set(hashes.values())) <= 1, hashes
(root / "measurements.json").write_text(json.dumps(results, indent=2) + "\n")
print("Completed; successful PDF outputs match byte-for-byte", flush=True)
