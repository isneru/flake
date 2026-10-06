pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "root:/singletons"

Singleton {
    id: root

    property var current: null
    property var daily: []
    property var hourly: []
    property string error: ""
    property double updated: 0

    property var places: []
    property bool searching: false

    readonly property bool configured: Config.weatherPlace !== ""
    readonly property bool ready: current !== null

    readonly property string url: "https://api.open-meteo.com/v1/forecast"
        + "?latitude=" + Config.weatherLat
        + "&longitude=" + Config.weatherLon
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
        + "&hourly=temperature_2m,weather_code,is_day"
        + "&timezone=auto&forecast_days=5"

    readonly property var codes: [
        { from: 0, to: 0, icon: "sunny", night: "clear_night", label: "Clear" },
        { from: 1, to: 1, icon: "sunny", night: "clear_night", label: "Mainly clear" },
        { from: 2, to: 2, icon: "partly_cloudy_day", night: "partly_cloudy_night", label: "Partly cloudy" },
        { from: 3, to: 3, icon: "cloud", label: "Overcast" },
        { from: 45, to: 45, icon: "foggy", label: "Fog" },
        { from: 48, to: 48, icon: "foggy", label: "Fog" },
        { from: 51, to: 57, icon: "rainy", label: "Drizzle" },
        { from: 61, to: 67, icon: "rainy", label: "Rain" },
        { from: 71, to: 77, icon: "weather_snowy", label: "Snow" },
        { from: 80, to: 82, icon: "rainy", label: "Showers" },
        { from: 85, to: 86, icon: "weather_snowy", label: "Snow showers" },
        { from: 95, to: Infinity, icon: "thunderstorm", label: "Thunderstorm" }
    ]

    function codeInfo(code, day) {
        const c = code === null ? null : codes.find(r => code >= r.from && code <= r.to);
        if (!c)
            return { icon: "cloud", label: "Unknown" };
        return { icon: day === 0 && c.night ? c.night : c.icon, label: c.label };
    }

    function hourLabel(t) {
        return Qt.formatDateTime(new Date(t), "HH") + "h";
    }
    function dayLabel(t) {
        return Qt.formatDateTime(new Date(t), "dddd");
    }

    readonly property var info: current ? codeInfo(current.code, current.isDay) : ({ icon: "cloud", label: "" })
    readonly property string temp: current ? Math.round(current.temp) + "°" : ""

    Process {
        id: fetcher
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = "could not reach open-meteo"
        }
    }

    function refresh() {
        if (!configured || fetcher.running)
            return;
        error = "";
        fetcher.command = ["curl", "-fsS", "--max-time", "12", url];
        fetcher.running = true;
    }

    function parse(txt) {
        try {
            const j = JSON.parse(txt);
            const c = j.current;
            current = {
                temp: c.temperature_2m,
                feels: c.apparent_temperature,
                humidity: c.relative_humidity_2m,
                wind: c.wind_speed_10m,
                code: c.weather_code,
                isDay: c.is_day
            };

            const d = j.daily;
            daily = d.time.map((t, i) => ({
                date: t,
                code: d.weather_code[i],
                max: d.temperature_2m_max[i],
                min: d.temperature_2m_min[i]
            }));

            const h = j.hourly;
            const now = Date.now();
            hourly = h.time
                .map((t, i) => ({ time: t, temp: h.temperature_2m[i], code: h.weather_code[i], isDay: h.is_day[i] }))
                .filter(e => new Date(e.time).getTime() >= now - 3600000)
                .slice(0, 24);

            updated = Date.now();
            error = "";
        } catch (e) {
            error = "unreadable response";
        }
    }

    Process {
        id: geocoder
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.places = (j.results ?? []).map(r => ({
                        name: r.name,
                        detail: [r.admin1, r.country].filter(x => x).join(", "),
                        lat: r.latitude,
                        lon: r.longitude
                    }));
                } catch (e) {
                    root.places = [];
                }
                root.searching = false;
            }
        }
    }

    function search(q) {
        const query = q.trim();
        if (query.length < 2) {
            places = [];
            searching = false;
            return;
        }
        searching = true;
        geocoder.running = false;
        geocoder.command = ["curl", "-fsS", "--max-time", "10",
            "https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&format=json&name=" + encodeURIComponent(query)];
        geocoder.running = true;
    }

    function pick(p) {
        Config.setWeather(p.name + (p.detail ? ", " + p.detail : ""), p.lat, p.lon);
        places = [];
        current = null;
        daily = [];
        hourly = [];
        refresh();
    }

    function forget() {
        Config.setWeather("", 0, 0);
        current = null;
        daily = [];
        hourly = [];
        error = "";
    }

    onConfiguredChanged: if (configured) refresh()

    Timer {
        interval: 15 * 60 * 1000
        running: root.configured
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
