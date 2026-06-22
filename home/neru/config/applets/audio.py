#!/usr/bin/env python3
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gdk, Gtk4LayerShell, GLib, Pango
import pulsectl

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
.section-label {
    color: #6c7086;
    font-size: 10px;
    font-weight: bold;
    margin-top: 10px;
    margin-bottom: 2px;
}
.volume-icon {
    color: #cba6f7;
    font-size: 16px;
}
.volume-pct {
    color: #6c7086;
    font-size: 12px;
    min-width: 38px;
}
scale {
    padding: 0;
    margin: 0 4px;
}
scale trough {
    background-color: #313244;
    border-radius: 4px;
    min-height: 4px;
    border: none;
}
scale trough highlight {
    background-color: #cba6f7;
    border-radius: 4px;
}
scale slider {
    background-color: #cba6f7;
    border-radius: 50%;
}
scale slider:hover {
    background-color: #d4b8f8;
}
.mute-btn {
    background-color: transparent;
    color: #cdd6f4;
    border: 1px solid #45475a;
    border-radius: 8px;
    padding: 2px 10px;
    font-size: 12px;
    min-width: 52px;
}
.mute-btn:hover {
    background-color: #313244;
}
.mute-btn.muted {
    color: #f38ba8;
    border-color: #f38ba8;
}
.device-row {
    border-radius: 8px;
    padding: 6px 8px;
}
.device-row:hover {
    background-color: #313244;
}
.device-name {
    color: #cdd6f4;
    font-size: 13px;
}
.device-active .device-name {
    color: #cba6f7;
}
.device-check {
    color: #cba6f7;
    font-size: 12px;
}
"""

ICON_VOL      = '\U000f057e'
ICON_VOL_MUTE = '\U000f0581'
ICON_CHECK    = '•'  # bullet to mark active device


def vol_icon(pct: int, muted: bool) -> str:
    return ICON_VOL_MUTE if muted else ICON_VOL


class AudioApplet(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, decorated=False)
        self._updating = False
        self._load_css()
        self._setup_layer_shell()
        self._build_ui()
        self._refresh()
        key_ctrl = Gtk.EventControllerKey.new()
        key_ctrl.connect('key-pressed', self._on_key)
        self.add_controller(key_ctrl)
        GLib.timeout_add(2000, self._tick)

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

        vol_hdr = Gtk.Label(label='OUTPUT VOLUME', xalign=0)
        vol_hdr.add_css_class('section-label')
        outer.append(vol_hdr)

        vol_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)

        self._vol_icon = Gtk.Label(label=ICON_VOL)
        self._vol_icon.add_css_class('volume-icon')
        vol_row.append(self._vol_icon)

        self._vol_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 150, 1)
        self._vol_scale.set_hexpand(True)
        self._vol_scale.set_draw_value(False)
        self._vol_scale.connect('value-changed', self._on_volume_changed)
        vol_row.append(self._vol_scale)

        self._vol_pct = Gtk.Label(label='0%', xalign=1)
        self._vol_pct.add_css_class('volume-pct')
        vol_row.append(self._vol_pct)

        self._mute_btn = Gtk.Button(label='Mute')
        self._mute_btn.add_css_class('mute-btn')
        self._mute_btn.connect('clicked', self._on_mute)
        vol_row.append(self._mute_btn)

        outer.append(vol_row)

        dev_hdr = Gtk.Label(label='OUTPUT DEVICE', xalign=0)
        dev_hdr.add_css_class('section-label')
        outer.append(dev_hdr)

        self._devices_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        outer.append(self._devices_box)

        self.set_child(outer)

    def _pulse_state(self):
        with pulsectl.Pulse('audio-applet') as pulse:
            info = pulse.server_info()
            sinks = pulse.sink_list()
        return info.default_sink_name, sinks

    def _refresh(self):
        default_name, sinks = self._pulse_state()
        default_sink = next((s for s in sinks if s.name == default_name), None)

        self._updating = True

        if default_sink:
            vol = int(default_sink.volume.value_flat * 100)
            muted = bool(default_sink.mute)
            self._vol_scale.set_value(vol)
            self._vol_pct.set_text(f'{vol}%')
            self._vol_icon.set_text(vol_icon(vol, muted))
            if muted:
                self._mute_btn.add_css_class('muted')
                self._mute_btn.set_label('Unmute')
            else:
                self._mute_btn.remove_css_class('muted')
                self._mute_btn.set_label('Mute')

        while (child := self._devices_box.get_first_child()):
            self._devices_box.remove(child)

        for sink in sinks:
            active = sink.name == default_name
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            row.add_css_class('device-row')
            if active:
                row.add_css_class('device-active')

            name_label = Gtk.Label(label=sink.description, xalign=0, hexpand=True)
            name_label.set_ellipsize(Pango.EllipsizeMode.END)
            name_label.add_css_class('device-name')
            row.append(name_label)

            if active:
                check = Gtk.Label(label=ICON_CHECK)
                check.add_css_class('device-check')
                row.append(check)

            gesture = Gtk.GestureClick.new()
            gesture.connect('released', self._on_sink_select, sink.name)
            row.add_controller(gesture)

            self._devices_box.append(row)

        self._updating = False

    def _tick(self):
        self._refresh()
        return GLib.SOURCE_CONTINUE

    def _on_volume_changed(self, scale):
        if self._updating:
            return
        vol = scale.get_value() / 100.0
        self._vol_pct.set_text(f'{int(scale.get_value())}%')
        with pulsectl.Pulse('audio-applet') as pulse:
            sink = pulse.get_sink_by_name(pulse.server_info().default_sink_name)
            pulse.volume_set_all_chans(sink, vol)

    def _on_mute(self, _btn):
        with pulsectl.Pulse('audio-applet') as pulse:
            sink = pulse.get_sink_by_name(pulse.server_info().default_sink_name)
            pulse.mute(sink, not sink.mute)
        self._refresh()

    def _on_sink_select(self, _gesture, _n, _x, _y, name):
        with pulsectl.Pulse('audio-applet') as pulse:
            pulse.sink_default_set(name)
        self._refresh()

    def do_close_request(self):
        self.hide()
        return True

    def _on_key(self, _ctrl, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            self.hide()
        return False


class AudioApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='sh.neru.AudioApplet')
        self._window = None
        self.hold()

    def do_activate(self):
        if self._window is None:
            self._window = AudioApplet(self)
        if self._window.is_visible():
            self._window.hide()
        else:
            self._window._refresh()
            self._window.present()


if __name__ == '__main__':
    AudioApp().run(None)
