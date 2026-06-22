#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
gi.require_version('NM', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell, GLib, Pango, NM

CSS = b"""
window {
    background-color: #1e1e2e;
    border: 1px solid #45475a;
    border-radius: 12px;
}
.applet-box {
    padding: 14px 16px 16px;
    min-width: 320px;
}
.applet-header {
    margin-bottom: 4px;
}
.applet-title {
    color: #cdd6f4;
    font-size: 15px;
    font-weight: bold;
}
.section-label {
    color: #6c7086;
    font-size: 10px;
    font-weight: bold;
    margin-top: 10px;
    margin-bottom: 2px;
}
.net-row {
    border-radius: 8px;
    padding: 6px 8px;
}
.net-row:hover {
    background-color: #313244;
}
.net-ssid {
    color: #cdd6f4;
    font-size: 13px;
}
.net-active .net-ssid {
    color: #cba6f7;
}
.net-signal {
    color: #89b4fa;
    font-size: 14px;
    min-width: 20px;
}
.net-lock {
    color: #6c7086;
    font-size: 11px;
}
.net-active-dot {
    color: #cba6f7;
    font-size: 12px;
}
.action-btn {
    background-color: transparent;
    color: #6c7086;
    border: none;
    border-radius: 6px;
    padding: 2px 6px;
    font-size: 12px;
    min-width: 0;
}
.action-btn:hover {
    background-color: #313244;
    color: #cdd6f4;
}
.disconnect-btn {
    background-color: transparent;
    color: #f38ba8;
    border: 1px solid #f38ba8;
    border-radius: 6px;
    padding: 2px 8px;
    font-size: 12px;
}
.disconnect-btn:hover {
    background-color: rgba(243, 139, 168, 0.1);
}
.pw-row {
    padding: 4px 8px 4px 28px;
}
entry {
    background-color: #313244;
    color: #cdd6f4;
    border: 1px solid #45475a;
    border-radius: 6px;
    padding: 4px 8px;
    font-size: 13px;
}
entry:focus {
    border-color: #cba6f7;
}
.connect-btn {
    background-color: #cba6f7;
    color: #1e1e2e;
    border: none;
    border-radius: 6px;
    padding: 4px 10px;
    font-size: 12px;
    font-weight: bold;
}
.connect-btn:hover {
    background-color: #d4b8f8;
}
"""

SIGNAL_ICONS = ['\U000f092f', '\U000f091f', '\U000f0922', '\U000f0925', '\U000f0928']
LOCK_ICON    = '\U000f033e'
WIFI_OFF     = '\U000f05aa'


def signal_icon(strength: int) -> str:
    idx = min(int(strength / 25), 3) + 1 if strength > 0 else 0
    return SIGNAL_ICONS[idx]


def ssid_str(ap) -> str:
    raw = ap.get_ssid()
    if raw is None:
        return '(hidden)'
    return raw.get_data().decode('utf-8', errors='replace')


def is_secured(ap) -> bool:
    return ap.get_wpa_flags() != 0 or ap.get_rsn_flags() != 0


class WifiApplet(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, decorated=False)
        self._client   = None
        self._wifi     = None
        self._pw_bssid = None
        self._updating = False

        self._load_css()
        self._setup_layer_shell()
        self._build_ui()

        key_ctrl = Gtk.EventControllerKey.new()
        key_ctrl.connect('key-pressed', self._on_key)
        self.add_controller(key_ctrl)

        NM.Client.new_async(None, self._on_client_ready, None)

    # -- setup ----------------------------------------------------------------

    def _on_client_ready(self, _source, result, _data):
        try:
            self._client = NM.Client.new_finish(result)
        except Exception as e:
            print(f'NM init failed: {e}')
            return
        self._wifi = self._find_wifi_device()
        self._refresh()
        if self._wifi:
            self._wifi.request_scan_async(None, None, None)
        GLib.timeout_add(5000, self._tick)

    def _find_wifi_device(self):
        for dev in self._client.get_devices():
            if dev.get_device_type() == NM.DeviceType.WIFI:
                return dev
        return None

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
        hdr.add_css_class('applet-header')
        title = Gtk.Label(label='Wi-Fi', xalign=0, hexpand=True)
        title.add_css_class('applet-title')
        hdr.append(title)
        self._toggle = Gtk.Switch()
        self._toggle.connect('state-set', self._on_toggle)
        hdr.append(self._toggle)
        outer.append(hdr)

        self._content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        outer.append(self._content)

        self.set_child(outer)

    # -- data helpers ---------------------------------------------------------

    def _find_connection(self, ap):
        ap_ssid = ap.get_ssid()
        if ap_ssid is None:
            return None
        data = ap_ssid.get_data()
        for conn in self._client.get_connections():
            s = conn.get_setting_wireless()
            if s:
                csid = s.get_ssid()
                if csid and csid.get_data() == data:
                    return conn
        return None

    def _get_unique_aps(self):
        if not self._wifi:
            return []
        seen = {}
        for ap in sorted(self._wifi.get_access_points(),
                         key=lambda a: a.get_strength(), reverse=True):
            raw = ap.get_ssid()
            if not raw:
                continue
            key = raw.get_data()
            if key not in seen:
                seen[key] = ap
        return list(seen.values())

    # -- refresh --------------------------------------------------------------

    def _refresh(self):
        if self._client is None:
            return
        self._updating = True
        self._toggle.set_active(self._client.wireless_get_enabled())
        self._updating = False

        while (c := self._content.get_first_child()):
            self._content.remove(c)

        if not self._client.wireless_get_enabled() or not self._wifi:
            return

        active_ap = self._wifi.get_active_access_point()
        unique_aps = self._get_unique_aps()

        connected = [a for a in unique_aps if active_ap and a.get_bssid() == active_ap.get_bssid()]
        others    = [a for a in unique_aps if not (active_ap and a.get_bssid() == active_ap.get_bssid())]
        others.sort(key=lambda a: a.get_strength(), reverse=True)

        if connected:
            hdr = Gtk.Label(label='CONNECTED', xalign=0)
            hdr.add_css_class('section-label')
            self._content.append(hdr)
            self._content.append(self._build_ap_row(connected[0], True, self._find_connection(connected[0])))

        if others:
            hdr2 = Gtk.Label(label='AVAILABLE', xalign=0)
            hdr2.add_css_class('section-label')
            self._content.append(hdr2)
            for ap in others:
                self._content.append(self._build_ap_row(ap, False, self._find_connection(ap)))

    def _build_ap_row(self, ap, active, conn):
        wrapper = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        row.add_css_class('net-row')
        if active:
            row.add_css_class('net-active')

        sig = Gtk.Label(label=signal_icon(ap.get_strength()))
        sig.add_css_class('net-signal')
        row.append(sig)

        ssid = Gtk.Label(label=ssid_str(ap), xalign=0, hexpand=True)
        ssid.set_ellipsize(Pango.EllipsizeMode.END)
        ssid.add_css_class('net-ssid')
        row.append(ssid)

        if is_secured(ap):
            lock = Gtk.Label(label=LOCK_ICON)
            lock.add_css_class('net-lock')
            row.append(lock)

        if active:
            dot = Gtk.Label(label='•')
            dot.add_css_class('net-active-dot')
            row.append(dot)
            disc = Gtk.Button(label='Disconnect')
            disc.add_css_class('disconnect-btn')
            disc.connect('clicked', self._on_disconnect)
            row.append(disc)
        elif conn:
            forget = Gtk.Button(label='×')
            forget.add_css_class('action-btn')
            forget.connect('clicked', self._on_forget, conn)
            row.append(forget)

        wrapper.append(row)

        # Inline password row (shown when clicking an unknown/open AP)
        pw_row = self._build_pw_row(ap)
        pw_row.set_visible(self._pw_bssid == ap.get_bssid())
        wrapper.append(pw_row)

        gesture = Gtk.GestureClick.new()
        gesture.connect('released', self._on_row_click, ap, active, conn, pw_row)
        row.add_controller(gesture)

        return wrapper

    def _build_pw_row(self, ap):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        row.add_css_class('pw-row')

        entry = Gtk.Entry()
        entry.set_visibility(False)
        entry.set_placeholder_text('Password')
        entry.set_hexpand(True)
        row.append(entry)

        btn = Gtk.Button(label='Connect')
        btn.add_css_class('connect-btn')
        btn.connect('clicked', self._on_connect_new, ap, entry)
        entry.connect('activate', self._on_connect_new, ap, entry)
        row.append(btn)

        return row

    # -- actions --------------------------------------------------------------

    def _on_toggle(self, switch, state):
        if self._updating or self._client is None:
            return False
        self._client.set_property('wireless-enabled', state)
        GLib.timeout_add(500, self._refresh)
        return False

    def _on_row_click(self, gesture, n, x, y, ap, active, conn, pw_row):
        if active:
            return
        if conn:
            self._client.activate_connection_async(
                conn, self._wifi, ap.get_path(), None, self._on_activate_done, None)
        elif is_secured(ap):
            visible = not pw_row.get_visible()
            self._pw_bssid = ap.get_bssid() if visible else None
            pw_row.set_visible(visible)
            if visible:
                entry = pw_row.get_first_child()
                if isinstance(entry, Gtk.PasswordEntry):
                    entry.grab_focus()
        else:
            self._connect_open(ap)

    def _connect_open(self, ap):
        s_con  = NM.SettingConnection.new()
        s_con.set_property(NM.SETTING_CONNECTION_ID, ssid_str(ap))
        s_con.set_property(NM.SETTING_CONNECTION_TYPE, '802-11-wireless')
        s_wifi = NM.SettingWireless.new()
        s_wifi.set_property(NM.SETTING_WIRELESS_SSID, ap.get_ssid())
        conn = NM.SimpleConnection.new()
        conn.add_setting(s_con)
        conn.add_setting(s_wifi)
        self._client.add_and_activate_connection_async(
            conn, self._wifi, ap.get_path(), None, self._on_add_activate_done, None)

    def _on_connect_new(self, widget, ap, entry):
        password = entry.get_text()
        if not password:
            return
        s_con  = NM.SettingConnection.new()
        s_con.set_property(NM.SETTING_CONNECTION_ID, ssid_str(ap))
        s_con.set_property(NM.SETTING_CONNECTION_TYPE, '802-11-wireless')
        s_wifi = NM.SettingWireless.new()
        s_wifi.set_property(NM.SETTING_WIRELESS_SSID, ap.get_ssid())
        s_wsec = NM.SettingWirelessSecurity.new()
        s_wsec.set_property(NM.SETTING_WIRELESS_SECURITY_KEY_MGMT, 'wpa-psk')
        s_wsec.set_property(NM.SETTING_WIRELESS_SECURITY_PSK, password)
        conn = NM.SimpleConnection.new()
        conn.add_setting(s_con)
        conn.add_setting(s_wifi)
        conn.add_setting(s_wsec)
        self._pw_bssid = None
        self._client.add_and_activate_connection_async(
            conn, self._wifi, ap.get_path(), None, self._on_add_activate_done, None)

    def _on_activate_done(self, client, result, _data):
        try:
            client.activate_connection_finish(result)
        except Exception:
            pass
        GLib.timeout_add(1000, self._refresh)

    def _on_add_activate_done(self, client, result, _data):
        try:
            client.add_and_activate_connection_finish(result)
        except Exception:
            pass
        GLib.timeout_add(1000, self._refresh)

    def _on_disconnect(self, _btn):
        active = self._wifi.get_active_connection() if self._wifi else None
        if active:
            self._client.deactivate_connection_async(active, None, None, None)
        GLib.timeout_add(500, self._refresh)

    def _on_forget(self, _btn, conn):
        conn.delete_async(None, None, None)
        GLib.timeout_add(300, self._refresh)

    def _tick(self):
        self._refresh()
        return GLib.SOURCE_CONTINUE

    def do_close_request(self):
        self.hide()
        return True

    def _on_key(self, _ctrl, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            self.hide()
        return False


class WifiApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='sh.neru.WifiApplet')
        self._window = None
        self.hold()

    def do_activate(self):
        if self._window is None:
            self._window = WifiApplet(self)
        if self._window.is_visible():
            self._window.hide()
        else:
            self._window._refresh()
            self._window.present()


if __name__ == '__main__':
    WifiApp().run(None)
