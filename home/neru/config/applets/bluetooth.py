#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell, GLib, Gio

BLUEZ      = 'org.bluez'
ADAPTER_IF = 'org.bluez.Adapter1'
DEVICE_IF  = 'org.bluez.Device1'
BATTERY_IF = 'org.bluez.Battery1'
OBJMGR_IF  = 'org.freedesktop.DBus.ObjectManager'
PROPS_IF   = 'org.freedesktop.DBus.Properties'

ICONS = {
    'audio-headset':   '\U000f02cb',
    'audio-headphones':'\U000f02cb',
    'audio-card':      '\U000f02cb',
    'phone':           '\U000f011c',
    'computer':        '\U000f0322',
    'keyboard':        '\U000f030c',
    'mouse':           '\U000f037e',
    'input-gaming':    '\U000f0335',
}

def device_icon(icon_name):
    if icon_name:
        for key, ico in ICONS.items():
            if key in icon_name:
                return ico
    return '\U000f00af'


CSS = b"""
window {
    background-color: #1e1e2e;
    border: 1px solid #45475a;
    border-radius: 12px;
}
.applet-box {
    padding: 14px 16px 16px;
    min-width: 300px;
}
.header-row {
    margin-bottom: 4px;
}
.header-label {
    color: #cdd6f4;
    font-size: 13px;
    font-weight: bold;
}
.section-label {
    color: #6c7086;
    font-size: 10px;
    font-weight: bold;
    margin-top: 10px;
    margin-bottom: 2px;
}
.device-row {
    border-radius: 8px;
    padding: 6px 8px;
}
.device-row:hover {
    background-color: #313244;
}
.device-icon {
    color: #89b4fa;
    font-size: 16px;
    min-width: 22px;
}
.device-name {
    color: #cdd6f4;
    font-size: 13px;
}
.connected .device-name {
    color: #a6e3a1;
}
.device-status {
    color: #6c7086;
    font-size: 11px;
}
.connected .device-status {
    color: #a6e3a1;
}
.action-btn {
    background-color: transparent;
    color: #89b4fa;
    border: 1px solid #45475a;
    border-radius: 6px;
    padding: 2px 10px;
    font-size: 11px;
    min-width: 80px;
}
.action-btn:hover {
    background-color: #313244;
}
.action-btn.disconnect {
    color: #f38ba8;
    border-color: #f38ba8;
}
.no-devices {
    color: #6c7086;
    font-size: 12px;
    margin-top: 8px;
}
"""


class BluetoothApplet(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, decorated=False)
        self._bus          = None
        self._adapter_path = None
        self._updating     = False

        self._load_css()
        self._setup_layer_shell()
        self._build_ui()

        key_ctrl = Gtk.EventControllerKey.new()
        key_ctrl.connect('key-pressed', self._on_key)
        self.add_controller(key_ctrl)

        Gio.bus_get(Gio.BusType.SYSTEM, None, self._on_bus_ready, None)

    # -- setup ----------------------------------------------------------------

    def _on_bus_ready(self, _src, result, _data):
        try:
            self._bus = Gio.bus_get_finish(result)
        except Exception as e:
            print(f'D-Bus error: {e}')
            return
        self._bus.signal_subscribe(
            BLUEZ, PROPS_IF, 'PropertiesChanged', None, None,
            Gio.DBusSignalFlags.NONE, self._on_props_changed, None)
        self._refresh()
        GLib.timeout_add(5000, self._tick)

    def _get_objects(self):
        mgr = Gio.DBusProxy.new_sync(
            self._bus, Gio.DBusProxyFlags.NONE, None,
            BLUEZ, '/', OBJMGR_IF, None)
        result = mgr.call_sync('GetManagedObjects', None,
            Gio.DBusCallFlags.NONE, -1, None)
        return result.unpack()[0]

    def _load_css(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def _setup_layer_shell(self):
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.RIGHT, 16)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.BOTTOM, 16)
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)

    def _build_ui(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        outer.add_css_class('applet-box')

        hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        hdr.add_css_class('header-row')
        lbl = Gtk.Label(label='Bluetooth', xalign=0, hexpand=True)
        lbl.add_css_class('header-label')
        hdr.append(lbl)
        self._toggle = Gtk.Switch()
        self._toggle.connect('state-set', self._on_toggle)
        hdr.append(self._toggle)
        outer.append(hdr)

        dev_hdr = Gtk.Label(label='DEVICES', xalign=0)
        dev_hdr.add_css_class('section-label')
        outer.append(dev_hdr)

        self._content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        outer.append(self._content)

        self.set_child(outer)

    # -- refresh --------------------------------------------------------------

    def _refresh(self):
        if not self._bus:
            return

        try:
            objects = self._get_objects()
        except Exception as e:
            print(f'refresh error: {e}')
            return

        self._adapter_path = None
        powered = False
        for path, ifaces in objects.items():
            if ADAPTER_IF in ifaces:
                self._adapter_path = path
                powered = bool(ifaces[ADAPTER_IF].get('Powered', False))
                break

        self._updating = True
        self._toggle.set_active(powered)
        self._updating = False

        while (c := self._content.get_first_child()):
            self._content.remove(c)

        if not powered or not self._adapter_path:
            return

        devices = []
        for path, ifaces in objects.items():
            if DEVICE_IF not in ifaces:
                continue
            props = ifaces[DEVICE_IF]
            if not props.get('Paired', False):
                continue
            battery = ifaces.get(BATTERY_IF, {}).get('Percentage')
            devices.append((path, props, battery))

        devices.sort(key=lambda d: (
            not d[1].get('Connected', False),
            d[1].get('Alias', d[1].get('Name', ''))
        ))

        if not devices:
            lbl = Gtk.Label(label='No paired devices', xalign=0)
            lbl.add_css_class('no-devices')
            self._content.append(lbl)
            return

        for path, props, battery in devices:
            self._content.append(self._build_row(path, props, battery))

    def _build_row(self, path, props, battery):
        connected = bool(props.get('Connected', False))
        name      = props.get('Alias', props.get('Name', props.get('Address', '?')))
        icon      = device_icon(props.get('Icon', ''))

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        row.add_css_class('device-row')
        if connected:
            row.add_css_class('connected')

        icon_lbl = Gtk.Label(label=icon)
        icon_lbl.add_css_class('device-icon')
        icon_lbl.set_valign(Gtk.Align.CENTER)
        row.append(icon_lbl)

        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        info.set_hexpand(True)
        info.set_valign(Gtk.Align.CENTER)
        name_lbl = Gtk.Label(label=name, xalign=0)
        name_lbl.add_css_class('device-name')
        info.append(name_lbl)
        if connected:
            parts = ['Connected']
            if battery is not None:
                parts.append(f'{battery}%')
            status = Gtk.Label(label=' · '.join(parts), xalign=0)
            status.add_css_class('device-status')
            info.append(status)
        row.append(info)

        if connected:
            btn = Gtk.Button(label='Disconnect')
            btn.add_css_class('action-btn')
            btn.add_css_class('disconnect')
            btn.connect('clicked', self._on_disconnect, path)
        else:
            btn = Gtk.Button(label='Connect')
            btn.add_css_class('action-btn')
            btn.connect('clicked', self._on_connect, path)
        btn.set_valign(Gtk.Align.CENTER)
        row.append(btn)

        return row

    def _tick(self):
        self._refresh()
        return GLib.SOURCE_CONTINUE

    def _on_props_changed(self, _conn, _sender, _path, iface, _sig, _params, _data):
        if iface in (ADAPTER_IF, DEVICE_IF, BATTERY_IF):
            GLib.idle_add(self._refresh)

    # -- actions --------------------------------------------------------------

    def _on_toggle(self, _switch, state):
        if self._updating or not self._adapter_path or not self._bus:
            return False
        try:
            proxy = Gio.DBusProxy.new_sync(
                self._bus, Gio.DBusProxyFlags.NONE, None,
                BLUEZ, self._adapter_path, PROPS_IF, None)
            proxy.call_sync('Set',
                GLib.Variant('(ssv)', (ADAPTER_IF, 'Powered', GLib.Variant('b', state))),
                Gio.DBusCallFlags.NONE, -1, None)
        except Exception as e:
            print(f'BT toggle error: {e}')
        GLib.timeout_add(300, self._refresh)
        return False

    def _on_connect(self, _btn, path):
        try:
            proxy = Gio.DBusProxy.new_sync(
                self._bus, Gio.DBusProxyFlags.NONE, None,
                BLUEZ, path, DEVICE_IF, None)
            proxy.call('Connect', None, Gio.DBusCallFlags.NONE, 25000, None,
                self._on_action_done, None)
        except Exception as e:
            print(f'BT connect error: {e}')

    def _on_disconnect(self, _btn, path):
        try:
            proxy = Gio.DBusProxy.new_sync(
                self._bus, Gio.DBusProxyFlags.NONE, None,
                BLUEZ, path, DEVICE_IF, None)
            proxy.call('Disconnect', None, Gio.DBusCallFlags.NONE, -1, None,
                self._on_action_done, None)
        except Exception as e:
            print(f'BT disconnect error: {e}')

    def _on_action_done(self, proxy, result, _data):
        try:
            proxy.call_finish(result)
        except Exception as e:
            print(f'BT action error: {e}')
        GLib.timeout_add(500, self._refresh)

    def do_close_request(self):
        self.hide()
        return True

    def _on_key(self, _ctrl, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            self.hide()
        return False


class BluetoothApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='sh.neru.BluetoothApplet')
        self._window = None
        self.hold()

    def do_activate(self):
        if self._window is None:
            self._window = BluetoothApplet(self)
            self._window.present()
        elif self._window.is_visible():
            self._window.hide()
        else:
            self._window._refresh()
            self._window.present()


if __name__ == '__main__':
    BluetoothApp().run(None)
