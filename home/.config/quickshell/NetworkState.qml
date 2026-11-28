// NetworkState.qml — Wi-Fi and wired state (NetworkManager): networks,
// connecting, forgetting. Split out of ShellState.qml.
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

    // ═════════════════════ network ═════════════════════
    readonly property var wifiDev: {
        const ds = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wifi) return ds[i];
        return null;
    }
    readonly property var wiredDev: {
        const ds = Networking.devices ? Networking.devices.values : [];
        for (let i = 0; i < ds.length; i++) if (ds[i].type === DeviceType.Wired && ds[i].connected) return ds[i];
        return null;
    }
    readonly property var wifiNet: {
        if (!wifiDev || !wifiDev.networks) return null;
        const ns = wifiDev.networks.values;
        for (let i = 0; i < ns.length; i++) if (ns[i].connected) return ns[i];
        return null;
    }
    readonly property bool online: wiredDev !== null || wifiNet !== null

    // Whether the machine HAS a wifi radio. A tower on a cable has none, and
    // without this the shell could not tell "there is no adapter" from "the
    // adapter is off": it showed a wifi switch that switched nothing on and an
    // empty list captioned "Wi-Fi apagado" (Wi-Fi off), as if pressing it were
    // enough. The device is checked, not wifiEnabled, because NetworkManager
    // reports the radio as disabled also when there simply is none.
    readonly property bool hasWifi: wifiDev !== null

    // ---- wifi list for the network panel ----
    // READ-ONLY mirror of NetworkManager's real state.
    //
    // It used to be a normal property bound to Networking.wifiEnabled PLUS an
    // onWifiOnChanged that rewrote it. Two consequences, both observed live on
    // 2026-08-05:
    //   1. on shell start-up, wifiEnabled reads false before NetworkManager's
    //      data arrives; the handler wrote that false back and THE SHELL
    //      SWITCHED YOUR WIFI OFF BY ITSELF. It is in NM's audit log:
    //      op="radio-control" arg="wireless-enabled:off" pid=<qs's>, with
    //      the off/on/off seesaw of a loop. And since systemd-rfkill persists
    //      the block, the laptop booted WITHOUT WIFI on the following days.
    //   2. assigning to a bound property DESTROYS the binding, so on the first
    //      click the switch stopped reflecting reality for ever.
    // That is why it is now readonly and every change goes through
    // setWifi/toggleWifi, which are only called from an explicit user gesture.
    readonly property bool wifiOn: Networking.wifiEnabled
    function setWifi(on) { Networking.wifiEnabled = on; }
    function toggleWifi() { root.setWifi(!root.wifiOn); }

    // The scanner is only on while the network panel is open: otherwise
    // NetworkManager is sweeping the airwaves all the time for nothing.
    // Scan/discover only while the corresponding panel is open: otherwise
    // NetworkManager and Bluez sweep the airwaves all the time for nothing.
    //
    // A declarative Binding and NOT an onPanelChanged: the imperative handler
    // only fired on a panel change, so if you turned bluetooth on from inside
    // its own panel discovery never started. This way it is also re-evaluated
    // when the adapter's state changes.
    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: ShellState.panel === "network"
        when: root.wifiDev !== null
        restoreMode: Binding.RestoreNone
    }
    // The Bluetooth section of Settings also wants to discover while it is
    // open. It asks through here instead of writing `discovering` by hand: two
    // places writing the same property (one with a Binding and the other
    // imperatively) is a race, and the loser was Settings as soon as the notch
    // panel changed.
    property bool btScanWanted: false
    Binding {
        target: BluetoothState.btAdapter
        property: "discovering"
        value: (ShellState.panel === "bluetooth" || root.btScanWanted) && BluetoothState.btOn
        when: BluetoothState.btAdapter !== null
        restoreMode: Binding.RestoreNone
    }

    // The same SSID can appear several times (several access points): the one
    // with the best signal is kept. Order: connected, then saved, then signal.
    readonly property var wifiNetworks: {
        if (!wifiDev || !wifiDev.networks) return [];
        const ns = wifiDev.networks.values;
        const best = {};
        for (let i = 0; i < ns.length; i++) {
            const n = ns[i];
            const k = n.name || "";
            if (k.length === 0) continue;
            const prev = best[k];
            if (!prev || (n.signalStrength || 0) > (prev.signalStrength || 0)) best[k] = n;
        }
        const out = [];
        for (const k in best) out.push(best[k]);
        out.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        return out;
    }

    // Thresholds squeezed on purpose: in practice signals fall between 30 and
    // 60, and with the "classic" split (75/50/25) they all came out with the
    // same icon.
    function wifiIconFor(s) {
        return s >= 72 ? "󰤨" : s >= 48 ? "󰤥" : s >= 24 ? "󰤢" : "󰤟";
    }
    function isSecured(net) {
        if (!net) return false;
        return net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Unknown;
    }
    function isEnterprise(net) {
        if (!net) return false;
        return net.security === WifiSecurityType.WpaEap
            || net.security === WifiSecurityType.Wpa2Eap
            || net.security === WifiSecurityType.Wpa3SuiteB192
            || net.security === WifiSecurityType.DynamicWep
            || net.security === WifiSecurityType.Leap;
    }
    function editEnterprise(net) {
        if (!net || !net.name) return;
        const known = Boolean(net.known);
        ShellState.closePanel();
        Quickshell.execDetached([
            ShellState.home + "/.config/glasstty/scripts/wifi-enterprise.sh",
            known ? "edit" : "create", String(net.name)
        ]);
        Launcher.toast(Icons.wifiLock, known
            ? I18n.tr("Abriendo credenciales de {0}", String(net.name))
            : I18n.tr("Nueva red empresarial: {0}", String(net.name)));
    }
    function openNetworkProfiles() {
        ShellState.settingsOpen = false;
        ShellState.closePanel();
        Quickshell.execDetached(["nm-connection-editor", "--show"]);
    }
    readonly property string netIcon: {
        if (wiredDev) return "󰈀";
        if (!wifiNet) return "󰤭";
        const s = wifiNet.signalStrength;
        return s >= 75 ? "󰤨" : s >= 50 ? "󰤥" : s >= 25 ? "󰤢" : "󰤟";
    }
}
