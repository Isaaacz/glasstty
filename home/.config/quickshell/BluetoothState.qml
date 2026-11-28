// BluetoothState.qml — Bluetooth devices: power, scanning, connecting, battery
// levels. Split out of ShellState.qml.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root

    // ═══════════════════════ bluetooth ═══════════════════════
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property int btConnected: {
        const ds = Bluetooth.devices ? Bluetooth.devices.values : [];
        let n = 0;
        for (let i = 0; i < ds.length; i++) if (ds[i].connected) n++;
        return n;
    }
    readonly property string btIcon: btBlocked ? "󰂲" : !btOn ? "󰂲" : (btConnected > 0 ? "󰂱" : "󰂯")

    // Blocked by rfkill: the switch can do nothing and that has to be said,
    // instead of pressing it coming to nothing with no explanation.
    readonly property bool btBlocked: btAdapter !== null && btAdapter.state === BluetoothAdapterState.Blocked

    // connected ones first, then the rest of the paired ones
    readonly property var btPaired: {
        const vs = Bluetooth.devices ? Bluetooth.devices.values : [];
        const out = [];
        for (let i = 0; i < vs.length; i++) if (vs[i].paired || vs[i].bonded) out.push(vs[i]);
        out.sort(function (a, b) { return (b.connected ? 1 : 0) - (a.connected ? 1 : 0); });
        return out;
    }
    readonly property var btNearby: {
        const vs = Bluetooth.devices ? Bluetooth.devices.values : [];
        const out = [];
        for (let i = 0; i < vs.length; i++) if (!vs[i].paired && !vs[i].bonded) out.push(vs[i]);
        return out;
    }
    function btLabel(d) {
        if (!d) return "";
        return d.deviceName || d.name || d.address || "";
    }
    // Pending intent: `rfkill unblock` is asynchronous, so the adapter is not
    // ready at the same instant. We store that the user wanted it on and switch
    // it on as soon as it stops being blocked.
    property bool btPendingOn: false

    // 2026-09-14: this used to be a single line that only did
    //     btAdapter.enabled = !btAdapter.enabled
    // and with an rfkill soft-block Bluez IGNORES that `enabled`, so the notch
    // switch did absolutely nothing. And that is the NORMAL state at boot: TLP
    // blocks the radio on every boot
    // (DEVICES_TO_DISABLE_ON_STARTUP="bluetooth" in /etc/tlp.d/01-diego.conf).
    // So switching off was automatic and switching on, impossible from where
    // you would expect. That breaks the house rule —the same as for wifi—:
    // switching on has to be as easy as switching off. TLP's own comment
    // promised that "the notch switch turns it back on with one click".
    // No sudo is needed: diego has a write ACL on /dev/rfkill.
    // SettingsBluetooth.qml already had this same unblock on a separate button;
    // here it is unified into the switch, which is where you look for it.
    function toggleBt() {
        if (!btAdapter) return;
        if (btBlocked) {
            btPendingOn = true;
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
            return;
        }
        btAdapter.enabled = !btAdapter.enabled;
    }

    // One-shot: as soon as the radio is unblocked, the intent is carried out.
    onBtBlockedChanged: {
        if (!btBlocked && btPendingOn) {
            btPendingOn = false;
            if (btAdapter) btAdapter.enabled = true;
        }
    }
}
