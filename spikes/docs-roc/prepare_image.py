"""One-time fixture conversion; the Roc renderer needs no Python or PNG codec.

Supports the five manual screenshots' non-interlaced 8-bit RGB PNG encoding.
Run from the repository root. This is not a production PNG decoder.
"""

import struct
import zlib
from pathlib import Path


def decode(source):
    assert source[:8] == b"\x89PNG\r\n\x1a\n"
    width, height, depth, color, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", source[16:29]
    )
    assert width > 0 and height > 0
    assert (depth, color, compression, filtering, interlace) == (8, 2, 0, 0, 0)
    compressed = bytearray()
    offset = 8
    while offset < len(source):
        length = int.from_bytes(source[offset : offset + 4], "big")
        kind = source[offset + 4 : offset + 8]
        payload = source[offset + 8 : offset + 8 + length]
        assert zlib.crc32(kind + payload) == int.from_bytes(
            source[offset + 8 + length : offset + 12 + length], "big"
        )
        if kind == b"IDAT":
            compressed.extend(payload)
        offset += length + 12

    raw = zlib.decompress(compressed)
    stride = width * 3
    assert len(raw) == height * (stride + 1)
    previous = bytearray(stride)
    pixels = bytearray()
    for row in range(height):
        method = raw[row * (stride + 1)]
        assert method in range(5)
        scan = bytearray(raw[row * (stride + 1) + 1 : (row + 1) * (stride + 1)])
        for x in range(stride):
            left = scan[x - 3] if x >= 3 else 0
            up = previous[x]
            upper_left = previous[x - 3] if x >= 3 else 0
            p = left + up - upper_left
            distances = (abs(p - left), abs(p - up), abs(p - upper_left))
            paeth = (left, up, upper_left)[distances.index(min(distances))]
            predictor = (0, left, up, (left + up) // 2, paeth)[method]
            scan[x] = (scan[x] + predictor) % 256
        pixels.extend(scan)
        previous = scan

    return width, height, bytes(pixels)


for name in ["animals", "colors", "styles", "menu", "piece-table"]:
    width, height, pixels = decode(Path(f"docs/images/{name}.png").read_bytes())
    Path(f"spikes/docs-roc/assets/{name}.rgb").write_bytes(pixels)
    print(f"Wrote {name}: {width}x{height} RGB fixture ({len(pixels)} bytes)")
