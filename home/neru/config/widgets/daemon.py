import importlib
import io
import os
import socket
import sys
import threading
from pathlib import Path

DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(DIR))

RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))

from widgets import WIDGETS


def _handle_connection(conn: socket.socket, module, width: int, height: int) -> None:
    fd = conn.fileno()
    stdin = os.fdopen(os.dup(fd), "rb", buffering=0)
    stdout = io.TextIOWrapper(
        os.fdopen(os.dup(fd), "wb", buffering=0),
        encoding="utf-8",
        write_through=True,
    )
    try:
        module.run(stdin, stdout, width, height)
    except (BrokenPipeError, ConnectionResetError, OSError):
        pass
    except Exception:
        import traceback

        traceback.print_exc(file=sys.stderr)
    finally:
        for s in (stdin, stdout):
            try:
                s.close()
            except Exception:
                pass
        try:
            conn.close()
        except Exception:
            pass


def _serve(name: str, module_name: str, width: int, height: int) -> None:
    module = importlib.import_module(module_name)
    sock_path = RUNTIME / f"drift-{name}.sock"
    if sock_path.exists():
        sock_path.unlink()
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(sock_path))
    server.listen(4)
    while True:
        conn, _ = server.accept()
        threading.Thread(
            target=_handle_connection,
            args=(conn, module, width, height),
            daemon=True,
        ).start()


def main() -> None:
    for name, module_name, width, height in WIDGETS:
        threading.Thread(
            target=_serve,
            args=(name, module_name, width, height),
            daemon=True,
        ).start()
    threading.Event().wait()


if __name__ == "__main__":
    main()
