#!/usr/bin/env python3
"""Compare the C timestamp ABI with Python's independent os.fstat binding."""

import ctypes
import errno
import json
import os
from pathlib import Path
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]
library = ctypes.CDLL(str(ROOT / ".cache/native/fingerprint.so"))
call = library.murmur_fingerprint
call.argtypes = [ctypes.c_int, ctypes.c_void_p]
call.restype = ctypes.c_int


def read(fd):
    storage = ctypes.create_string_buffer(b"\xa5" * 72)
    code = call(fd, ctypes.byref(storage, 8))
    assert storage.raw[:8] == b"\xa5" * 8
    assert storage.raw[64:72] == b"\xa5" * 8
    return code, struct.unpack("=7Q", storage.raw[8:64])


with tempfile.TemporaryFile() as f:
    f.write(b"zero")
    f.flush()
    code, words = read(f.fileno())
    metadata = os.fstat(f.fileno())
    assert code == 0
    assert words[:3] == (metadata.st_dev, metadata.st_ino, metadata.st_size)
    assert words[3] * 10**9 + words[4] == metadata.st_mtime_ns
    assert words[5] * 10**9 + words[6] == metadata.st_ctime_ns
    before = words
    f.seek(0)
    f.write(b"next")
    f.flush()
    assert read(f.fileno())[1] != before
assert read(-1)[0] == errno.EBADF
read_fd, write_fd = os.pipe()
try:
    assert read(read_fd)[0] == errno.EINVAL
finally:
    os.close(read_fd)
    os.close(write_fd)
(ROOT / "build").mkdir(exist_ok=True)
(ROOT / "build/native-abi.json").write_text(
    json.dumps(
        {
            "status": "passed",
            "checks": [
                "timestamps",
                "buffer canaries",
                "changed file",
                "bad fd",
                "nonregular fd",
            ],
        },
        indent=2,
    )
    + "\n"
)
print("native ABI: nanosecond fields, buffer canaries, and error boundaries passed")
