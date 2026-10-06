#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import sys
import threading
import time

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib, GLibUnix

BLUEZ = "org.bluez"
AGENT_IFACE = "org.bluez.Agent1"
DEVICE_IFACE = "org.bluez.Device1"
MANAGER_IFACE = "org.bluez.AgentManager1"
PROPS_IFACE = "org.freedesktop.DBus.Properties"

AGENT_PATH = "/org/quickshell/notch/BtAgent"
CAPABILITY = "KeyboardDisplay"
TIMEOUT = 120
RETRY = 5

ASK_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "quickshell", "ask")
CAPTION = "BLUETOOTH PAIRING"
FOOTER = "bluetooth - nothing pairs unless you approve it"

SERVICES = {
    "1105": "OBEX object push",
    "1106": "OBEX file transfer",
    "110a": "Audio source",
    "110b": "Audio sink",
    "110c": "Remote control target",
    "110e": "Remote control",
    "1112": "Headset audio gateway",
    "1115": "Personal area network",
    "1116": "Network access",
    "111e": "Hands-free",
    "111f": "Hands-free audio gateway",
    "1124": "Human interface device",
    "112f": "Phone book access",
    "1132": "Message access",
    "1200": "Device identification",
    "1800": "Generic access",
    "1812": "Human interface device",
}


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, file=sys.stderr, flush=True)


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


def ipc(*args):
    """True when the quickshell ipc call printed the expected answer."""
    try:
        out = subprocess.run(
            ["quickshell", "ipc", "call", *args],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return out.stdout.strip()


def service_name(uuid):
    """A readable name for a Bluetooth service UUID, else the UUID itself."""
    short = str(uuid).lower()
    if len(short) == 36 and short.endswith("-0000-1000-8000-00805f9b34fb"):
        return SERVICES.get(short[4:8], short)
    return SERVICES.get(short, short)


class Prompt:
    def __init__(self, fifo_id, spec, finished):
        self.id = fifo_id
        self.fifo = os.path.join(ASK_DIR, fifo_id)
        self.spec = spec
        self.finished = finished
        self.done = False
        self.timer = 0

    def publish(self):
        os.makedirs(ASK_DIR, exist_ok=True)
        os.chmod(ASK_DIR, 0o700)
        umask = os.umask(0o077)
        try:
            os.mkfifo(self.fifo)
        except OSError:
            os.umask(umask)
            return False
        os.umask(umask)
        req = dict(
            self.spec,
            id=self.id,
            fifo=self.fifo,
            source="bluetooth",
            caption=CAPTION,
            icon="bluetooth",
            footer=FOOTER,
            detailLabel="DEVICE",
            remember=False,
        )
        if ipc("ask", "request", json.dumps(req)) != "queued":
            self.unlink()
            return False
        threading.Thread(target=self._read, daemon=True).start()
        self.timer = GLib.timeout_add_seconds(TIMEOUT, self.abort)
        return True

    def _read(self):
        try:
            with open(self.fifo, "rb") as handle:
                data = handle.read()
        except OSError:
            data = b""
        GLib.idle_add(self._delivered, data.decode("utf-8", "replace"))

    def _delivered(self, text):
        if self.done:
            return False
        status, _, payload = text.partition("\n")
        self.settle()
        self.finished(status.strip(), payload)
        return False

    def abort(self):
        if self.done:
            return False
        self.settle()
        ipc("ask", "request", json.dumps({"withdraw": self.id}))
        self.unblock()
        self.finished("aborted", "")
        return False

    def settle(self):
        self.done = True
        if self.timer:
            GLib.source_remove(self.timer)
            self.timer = 0

    def unblock(self):
        for _ in range(RETRY):
            try:
                fd = os.open(self.fifo, os.O_WRONLY | os.O_NONBLOCK)
            except OSError:
                time.sleep(0.02)
                continue
            try:
                os.write(fd, b"cancel\n")
            finally:
                os.close(fd)
            break
        self.unlink()

    def unlink(self):
        try:
            os.unlink(self.fifo)
        except OSError:
            pass


class Agent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.bus = bus
        self.prompts = {}
        self.displays = {}
        self.serial = 0

    def ask(self, spec, finished, device=None):
        self.serial += 1
        fifo_id = "bt-%d-%d" % (os.getpid(), self.serial)
        prompt = Prompt(
            fifo_id, spec, lambda s, p: self._finished(fifo_id, device, s, p, finished)
        )
        self.prompts[fifo_id] = prompt
        if device is not None:
            self.displays[device] = prompt
        if not prompt.publish():
            self._forget(fifo_id, device)
            finished("unavailable", "")

    def _finished(self, fifo_id, device, status, payload, finished):
        self._forget(fifo_id, device)
        finished(status, payload)

    def _forget(self, fifo_id, device):
        self.prompts.pop(fifo_id, None)
        if device is not None and self.displays.get(device) is not None:
            if self.displays[device].id == fifo_id:
                self.displays.pop(device, None)

    def abort_all(self, device=None):
        for prompt in list(self.prompts.values()):
            if device is None or self.displays.get(device) is prompt:
                prompt.abort()

    def describe(self, path):
        """The device's (display name, address) pair, falling back to its object path."""
        address = str(path).rsplit("/", 1)[-1][4:].replace("_", ":")
        alias = ""
        try:
            props = dbus.Interface(self.bus.get_object(BLUEZ, path), PROPS_IFACE)
            address = str(props.Get(DEVICE_IFACE, "Address")) or address
            alias = str(props.Get(DEVICE_IFACE, "Alias"))
        except dbus.DBusException:
            pass
        if not alias or alias.replace("-", ":").upper() == address.upper():
            alias = "Unknown device"
        return alias, address

    def detail(self, path):
        name, address = self.describe(path)
        return name, "%s (%s)" % (name, address)

    def cancel_pairing(self, path):
        try:
            dbus.Interface(
                self.bus.get_object(BLUEZ, path), DEVICE_IFACE
            ).CancelPairing()
        except dbus.DBusException:
            pass

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self):
        log("released by bluez")
        self.abort_all()

    @dbus.service.method(
        AGENT_IFACE,
        in_signature="o",
        out_signature="s",
        async_callbacks=("reply", "error"),
    )
    def RequestPinCode(self, device, reply, error):
        name, detail = self.detail(device)

        def finished(status, payload):
            if status.startswith("ok") and payload:
                reply(dbus.String(payload))
            elif status == "aborted":
                error(Canceled())
            else:
                error(Rejected())

        self.ask(
            {
                "kind": "password",
                "message": "Enter the PIN that %s is showing." % name,
                "detail": detail,
                "prompt": "PIN",
                "echo": True,
            },
            finished,
        )

    @dbus.service.method(
        AGENT_IFACE,
        in_signature="o",
        out_signature="u",
        async_callbacks=("reply", "error"),
    )
    def RequestPasskey(self, device, reply, error):
        name, detail = self.detail(device)

        def finished(status, payload):
            digits = "".join(c for c in payload if c.isdigit())
            if status.startswith("ok") and digits:
                reply(dbus.UInt32(int(digits) % 1000000))
            elif status == "aborted":
                error(Canceled())
            else:
                error(Rejected())

        self.ask(
            {
                "kind": "password",
                "message": "Enter the passkey that %s is showing." % name,
                "detail": detail,
                "prompt": "Passkey",
                "echo": True,
            },
            finished,
        )

    @dbus.service.method(
        AGENT_IFACE,
        in_signature="ou",
        out_signature="",
        async_callbacks=("reply", "error"),
    )
    def RequestConfirmation(self, device, passkey, reply, error):
        name, detail = self.detail(device)

        def finished(status, payload):
            if status.startswith("ok"):
                reply()
            elif status == "aborted":
                error(Canceled())
            else:
                error(Rejected())

        self.ask(
            {
                "kind": "confirm",
                "message": "Confirm that %s is showing %06u." % (name, int(passkey)),
                "detail": detail,
            },
            finished,
        )

    @dbus.service.method(
        AGENT_IFACE,
        in_signature="o",
        out_signature="",
        async_callbacks=("reply", "error"),
    )
    def RequestAuthorization(self, device, reply, error):
        name, detail = self.detail(device)

        def finished(status, payload):
            if status.startswith("ok"):
                reply()
            elif status == "aborted":
                error(Canceled())
            else:
                error(Rejected())

        self.ask(
            {
                "kind": "confirm",
                "message": "Pair with %s? It shows no code to compare." % name,
                "detail": detail,
            },
            finished,
        )

    @dbus.service.method(
        AGENT_IFACE,
        in_signature="os",
        out_signature="",
        async_callbacks=("reply", "error"),
    )
    def AuthorizeService(self, device, uuid, reply, error):
        name, detail = self.detail(device)

        def finished(status, payload):
            if status.startswith("ok"):
                reply()
            elif status == "aborted":
                error(Canceled())
            else:
                error(Rejected())

        self.ask(
            {
                "kind": "confirm",
                "message": "Allow %s to use %s?" % (name, service_name(uuid)),
                "detail": detail,
            },
            finished,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        self.display(device, "Enter %s on %%s, then confirm there." % str(pincode))

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        self.display(device, "Enter %06u on %%s, then confirm there." % int(passkey))

    def display(self, device, template):
        if device in self.displays:
            return
        name, detail = self.detail(device)

        def finished(status, payload):
            if not status.startswith("ok") and status != "aborted":
                self.cancel_pairing(device)

        self.ask(
            {
                "kind": "display",
                "message": template % name,
                "detail": detail,
            },
            finished,
            device=device,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self):
        log("cancelled by bluez")
        self.abort_all()


class Registration:
    def __init__(self, bus, agent):
        self.bus = bus
        self.agent = agent
        self.registered = False

    def manager(self):
        return dbus.Interface(self.bus.get_object(BLUEZ, "/org/bluez"), MANAGER_IFACE)

    def register(self):
        try:
            self.manager().RegisterAgent(AGENT_PATH, CAPABILITY)
            self.manager().RequestDefaultAgent(AGENT_PATH)
        except dbus.DBusException as exc:
            log("register failed:", exc.get_dbus_name())
            self.registered = False
            return False
        self.registered = True
        log("registered", AGENT_PATH, "as", CAPABILITY)
        return True

    def unregister(self):
        if not self.registered:
            return
        self.registered = False
        try:
            self.manager().UnregisterAgent(AGENT_PATH)
            log("unregistered", AGENT_PATH)
        except dbus.DBusException as exc:
            log("unregister failed:", exc.get_dbus_name())

    def owner_changed(self, name, old, new):
        if name != BLUEZ:
            return
        self.agent.abort_all()
        self.registered = False
        if new:
            GLib.timeout_add_seconds(1, self.register)


def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    agent = Agent(bus)
    registration = Registration(bus, agent)

    bus.add_signal_receiver(
        registration.owner_changed,
        dbus_interface="org.freedesktop.DBus",
        signal_name="NameOwnerChanged",
        arg0=BLUEZ,
    )

    def paired(interface, changed, invalidated, path=None):
        if interface == DEVICE_IFACE and changed.get("Paired"):
            agent.abort_all(device=path)

    bus.add_signal_receiver(
        paired,
        dbus_interface=PROPS_IFACE,
        signal_name="PropertiesChanged",
        path_keyword="path",
    )

    if not registration.register() and not bus.name_has_owner(BLUEZ):
        log("bluez is not on the bus")
        return 1

    loop = GLib.MainLoop()

    def stop(*_):
        agent.abort_all()
        registration.unregister()
        loop.quit()
        return False

    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, stop)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, stop)

    try:
        loop.run()
    finally:
        agent.abort_all()
        registration.unregister()
    return 0


if __name__ == "__main__":
    sys.exit(main())
