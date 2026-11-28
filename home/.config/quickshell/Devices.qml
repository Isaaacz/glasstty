// Devices.qml — what you plug in, and the battery of what is connected.
//
// · Plugging: USB devices (udev, no root needed: `udevadm monitor` only
//   listens) and Bluetooth devices connecting or dropping. Each one puts a
//   short "device" face on the notch (NotchContent.qml) with its icon, name
//   and, when it reports one, its battery.
// · Batteries: every connected device that reports a charge — Bluetooth ones
//   through BlueZ, wired / dongle ones (a wireless mouse's receiver) through
//   UPower — for the bar's "devices" module.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    // What the notch face shows: { icon, name, plugged, dev } — `dev` is the
    // Bluetooth device, so its battery stays live while the face is up.
    property var last: null

    function announce(icon, name, plugged, dev) {
        if (!ShellState.armed || name === "") return;
        root.last = { icon: icon, name: name, plugged: plugged, dev: dev || null };
        ShellState.flash("device");
    }

    // ───────── batteries ─────────
    readonly property var batteries: {
        const out = [];
        const bs = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (let i = 0; i < bs.length; i++) {
            const d = bs[i];
            if (d && d.connected && d.batteryAvailable)
                out.push({ icon: root.btIcon(d.icon), name: d.deviceName || d.name || "", pct: Math.round(d.battery * 100) });
        }
        const us = UPower.devices ? UPower.devices.values : [];
        for (let i = 0; i < us.length; i++) {
            const d = us[i];
            // the laptop's own battery and the charger are the bar's battery module;
            // BlueZ devices are already listed above
            if (!d || !d.ready || !d.isPresent || d.isLaptopBattery || d.powerSupply) continue;
            if ((d.nativePath || "").indexOf("bluez") >= 0) continue;
            const p = d.percentage > 1 ? d.percentage : d.percentage * 100;
            out.push({ icon: root.upIcon(d.type), name: d.model || "", pct: Math.round(p) });
        }
        return out;
    }

    function btIcon(i) {
        i = i || "";
        return i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0 || i.indexOf("audio") >= 0 ? "󰋋"
            : i.indexOf("mouse") >= 0 ? "󰍽"
            : i.indexOf("keyboard") >= 0 ? "󰌌"
            : i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0 ? "󰊴"
            : i.indexOf("phone") >= 0 ? "󰄜"
            : i.indexOf("watch") >= 0 ? "󰖉"
            : "󰂯";
    }
    function upIcon(t) {
        return t === UPowerDeviceType.Mouse ? "󰍽"
            : t === UPowerDeviceType.Keyboard ? "󰌌"
            : t === UPowerDeviceType.GamingInput ? "󰊴"
            : t === UPowerDeviceType.Headset || t === UPowerDeviceType.Headphones ? "󰋋"
            : t === UPowerDeviceType.Phone ? "󰄜"
            : "󰂄";
    }

    // ───────── Bluetooth: connected / dropped ─────────
    Instantiator {
        model: Bluetooth.devices
        delegate: QtObject {
            required property var modelData
            readonly property bool on: modelData ? modelData.connected : false
            onOnChanged: root.announce(root.btIcon(modelData.icon),
                modelData.deviceName || modelData.name || "", on, modelData)
        }
    }

    // ───────── USB: udev events ─────────
    // `--property` prints each event as KEY=VALUE lines ending in a blank one.
    property var block: ({})
    property var seen: ({})           // DEVPATH -> { icon, name }, for the removal
    Process {
        id: udev
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb", "--property"]
        stdout: SplitParser {
            onRead: function (line) {
                if (line === "") { root.usbEvent(root.block); root.block = {}; return; }
                const eq = line.indexOf("=");
                if (eq > 0) root.block[line.slice(0, eq)] = line.slice(eq + 1);
            }
        }
        // udevadm should never end; if it does, start it again a bit later
        onExited: restartUdev.start()
    }
    Timer { id: restartUdev; interval: 5000; onTriggered: udev.running = true }

    function usbKind(ifs) {
        ifs = ifs || "";
        return ifs.indexOf(":030101") >= 0 ? "󰌌"
            : ifs.indexOf(":030102") >= 0 ? "󰍽"
            : ifs.indexOf(":08") >= 0 ? "󰋊"
            : ifs.indexOf(":01") >= 0 ? "󰋋"
            : ifs.indexOf(":0e") >= 0 ? "󰄀"
            : ifs.indexOf(":06") >= 0 || ifs.indexOf(":ff42") >= 0 ? "󰄜"
            : ifs.indexOf(":03") >= 0 ? "󰊴"
            : "󰕓";
    }
    function usbEvent(e) {
        if (e.DEVTYPE !== "usb_device") return;
        const path = e.DEVPATH || "";
        if (e.ACTION === "add") {
            // hubs are plumbing, not something you plugged in to use
            if ((e.ID_USB_INTERFACES || "").indexOf(":09") >= 0) return;
            const name = (e.ID_MODEL_FROM_DATABASE || (e.ID_MODEL || "").replace(/_/g, " ")
                || e.ID_VENDOR_FROM_DATABASE || I18n.tr("Dispositivo USB")).trim();
            const info = { icon: root.usbKind(e.ID_USB_INTERFACES), name: name };
            root.seen[path] = info;
            root.announce(info.icon, info.name, true, null);
        } else if (e.ACTION === "remove") {
            const info = root.seen[path];
            if (!info) return;
            delete root.seen[path];
            root.announce(info.icon, info.name, false, null);
        }
    }
}
