import os
import shutil
import struct
import sys
import zlib

CELL_CURSOR = 47562
PAKS = (("qtwebengine_resources_100p.pak", 1), ("qtwebengine_resources_200p.pak", 2))


def read_pak(path):
    """Return (encoding, {id: bytes}, [(alias id, entry index)]) for a v5 pak."""
    data = open(path, "rb").read()
    version, encoding, count, alias_count = struct.unpack_from("<IBxxxHH", data)
    assert version == 5, f"{path}: pak version {version}"
    entries = [struct.unpack_from("<HI", data, 12 + 6 * i) for i in range(count + 1)]
    aliases_at = 12 + 6 * (count + 1)
    aliases = [
        struct.unpack_from("<HH", data, aliases_at + 4 * i) for i in range(alias_count)
    ]
    resources = {
        entries[i][0]: data[entries[i][1] : entries[i + 1][1]] for i in range(count)
    }
    return encoding, resources, aliases


def write_pak(path, encoding, resources, aliases):
    ids = sorted(resources)
    body_at = 12 + 6 * (len(ids) + 1) + 4 * len(aliases)
    head = struct.pack("<IBxxxHH", 5, encoding, len(ids), len(aliases))
    body = b""
    for rid in ids:
        head += struct.pack("<HI", rid, body_at + len(body))
        body += resources[rid]
    head += struct.pack("<HI", 0, body_at + len(body))
    for alias in aliases:
        head += struct.pack("<HH", *alias)
    open(path, "wb").write(head + body)


def plus_png(scale):
    size, arm, width = 24 * scale, 9 * scale, scale
    centre = size // 2 - scale // 2

    def within(x, y, grow):
        dx, dy = abs(x - centre), abs(y - centre)
        return (dx < width + grow and dy <= arm + grow) or (
            dy < width + grow and dx <= arm + grow
        )

    rows = b""
    for y in range(size):
        rows += b"\0"
        for x in range(size):
            if within(x, y, 0):
                rows += b"\xff\xff\xff\xff"
            elif within(x, y, scale):
                rows += b"\0\0\0\xff"
            else:
                rows += b"\0\0\0\0"

    def chunk(kind, payload):
        crc = zlib.crc32(kind + payload)
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )


def main(source, target):
    shutil.copytree(source, target)
    for name, scale in PAKS:
        path = os.path.join(target, name)
        os.chmod(path, 0o644)
        encoding, resources, aliases = read_pak(path)
        assert CELL_CURSOR not in resources, f"{name} already has {CELL_CURSOR}"
        old_ids = sorted(resources)
        resources[CELL_CURSOR] = plus_png(scale)
        new_index = {rid: i for i, rid in enumerate(sorted(resources))}
        aliases = [(alias, new_index[old_ids[index]]) for alias, index in aliases]
        write_pak(path, encoding, resources, aliases)
        assert read_pak(path) == (encoding, resources, aliases)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
