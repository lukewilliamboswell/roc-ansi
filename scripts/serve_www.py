#!/usr/bin/env python3
"""Generate and locally preview the complete roc-ansi Pages site."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import webbrowser
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / ".roc-ansi-tmp" / "www-preview"


BASE_PATH = "/roc-ansi"


class Handler(SimpleHTTPRequestHandler):
    """Serve the site under the same base path GitHub Pages uses.

    Generated documentation embeds `<base href="/roc-ansi/...">`, so previewing
    from the server root leaves every archived version's assets unresolved.
    """

    def do_GET(self) -> None:
        if self.path == "/":
            self.send_response(302)
            self.send_header("Location", f"{BASE_PATH}/")
            self.end_headers()
            return
        super().do_GET()

    def translate_path(self, path: str) -> str:
        if path == BASE_PATH:
            path = f"{BASE_PATH}/"
        if path.startswith(f"{BASE_PATH}/"):
            path = path[len(BASE_PATH):]
        return super().translate_path(path)

    def log_message(self, format: str, *args: object) -> None:
        print(f"HTTP: {format % args}")


def executable(command: str) -> str:
    path = Path(command)
    if path.is_absolute() or path.parent != Path("."):
        candidate = path if path.is_absolute() else ROOT / path
        resolved = str(candidate.resolve()) if candidate.is_file() else None
    else:
        resolved = shutil.which(command)
    if resolved is None:
        raise SystemExit(f"Could not find Roc executable {command!r}. Use --roc or add roc to PATH.")
    return resolved


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--roc", default=os.environ.get("ROC", "roc"))
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=0, help="Port to listen on; 0 chooses a free port")
    parser.add_argument("--no-open", action="store_true")
    parser.add_argument("--no-serve", action="store_true")
    args = parser.parse_args()

    if not 0 <= args.port <= 65535:
        raise SystemExit("--port must be between 0 and 65535")
    roc = executable(args.roc)
    output = args.output.resolve()
    subprocess.run(
        [
            "python3",
            "scripts/assemble_www.py",
            "--roc",
            roc,
            "--output",
            str(output),
        ],
        cwd=ROOT,
        check=True,
    )
    if args.no_serve:
        return

    handler = partial(Handler, directory=str(output))
    server = ThreadingHTTPServer((args.host, args.port), handler)
    server.daemon_threads = True
    host, port = server.server_address[:2]
    display_host = "127.0.0.1" if host in {"0.0.0.0", "::"} else host
    url = f"http://{display_host}:{port}{BASE_PATH}/"
    print(f"Serving complete site at {url}", flush=True)
    if not args.no_open and not webbrowser.open(url):
        print("Could not open a browser automatically; open the URL above.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server.")
    finally:
        server.server_close()


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode) from None
