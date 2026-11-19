// Compositor.qml — the ONE door to niri.
//
// The shell was born on Hyprland and its ~20k lines of QML were written
// against HyprlandToplevel / HyprlandWorkspace / HyprlandMonitor objects
// (`t.workspace.id`, `t.lastIpcObject.at`, `t.wayland`, `ws.monitor.name`...).
// This singleton builds look-alike objects from niri's event stream, so the
// consumers kept that shape and only talk to named actions (focusWorkspace,
// closeWindow...). glasstty runs on niri only.
//
// Workspace ids: niri's own `id` is a global, ever-growing counter that means
// nothing to a person, while the shell paints workspaces as 1..N. So the
// look-alike `id` is niri's `idx` (position on its output, 1-based) and
// niri's real id travels as `niriId`. Actions resolve idx -> niriId on the
// focused output. With two screens idx repeats per output, which is why
// `output` is exposed.
pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

    // ═══════════════════════════ backend ═══════════════════════════
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET") || ""
    readonly property string backend: root.niriSocket !== "" ? "niri" : "none"
    readonly property bool isNiri: backend === "niri"
    readonly property string displayName: isNiri ? "niri" : "Wayland"

    // Events shaped like Hyprland's: {name, data}. The niri stream is translated
    // into the handful of names the shell listens for ("openwindow",
    // "closewindow", "windowtitle", "activewindow", "workspace", "focusedmon",
    // "monitoradded", "configreloaded", "changefloatingmode", "resizewindow").
    signal rawEvent(var ev)
    // A named shell action: niri has no global-shortcut protocol, so it is
    // emitted here and the component that owns NAME listens for it.
    signal globalRequested(string name)

    // ═══════════════════════════ the model ═════════════════════════
    readonly property var toplevels: root._nWinList
    // niri always keeps one empty workspace at the end of every output, and
    // in-between empties linger until left. The dots and the overview only
    // want workspaces that hold windows or are shown, so they are filtered
    // here. `allWorkspaces` keeps niri's full list.
    readonly property var workspaces: root._nWsList.filter(w => (w.active || (w.activeWindowId !== null && w.activeWindowId !== undefined)))
    readonly property var allWorkspaces: root._nWsList
    readonly property var monitors: root._nMonList
    readonly property var focusedWorkspace: root._nFocusedWs
    // Name of the output with the focus ("eDP-1"), "" while unknown.
    readonly property string focusedOutput: root._nFocusedWs ? root._nFocusedWs.output : ""
    // niri only: whether its own Overview is open.
    property bool overviewOpen: false
    // niri only: the exclusive zone the bar holds at the top (niri does not
    // report it). ShellState keeps it in sync; used to place tile thumbnails.
    property int reservedTop: 0
    onReservedTopChanged: if (root.isNiri) root._nRelinkWindows()

    // Whether the workspace shown on output `name` has any window (niri).
    function outputHasWindows(name) {
        const l = root._nWsList;
        for (let i = 0; i < l.length; i++)
            if (l[i].output === name && l[i].active)
                return l[i].activeWindowId !== null && l[i].activeWindowId !== undefined;
        return true;
    }

    function monitorFor(screen) {
        if (!screen) return null;
        const ms = root.monitors;
        for (let i = 0; i < ms.length; i++)
            if (ms[i] && ms[i].name === screen.name) return ms[i];
        return null;
    }

    // The event stream is always live; kept for the callers written for
    // Hyprland, where the list had to be refreshed by hand.
    function refreshToplevels() {}

    // ═══════════════════════════ actions ═══════════════════════════
    // `addr` is what the consumers carry around: the window id in hex, with or
    // without "0x" (the shape of a Hyprland address); both parse back to the id.
    function _nid(addr) { const n = parseInt(String(addr || ""), 16); return isNaN(n) ? -1 : n; }

    function focusWorkspace(ws) {
        if (root.isNiri) root._send({ Action: { FocusWorkspace: { reference: root._wsRef(ws) } } });
    }
    // dir > 0 = next, dir < 0 = previous.
    function focusWorkspaceRelative(dir) {
        if (!root.isNiri) return;
        root._send({ Action: dir > 0 ? { FocusWorkspaceDown: {} } : { FocusWorkspaceUp: {} } });
    }
    function focusWindow(addr) {
        if (root.isNiri) root._send({ Action: { FocusWindow: { id: root._nid(addr) } } });
    }
    // Selector form ("title:Ajustes", "class:foo"), matched against the live
    // list, which is enough for the one caller.
    function focusWindowMatching(field, value) {
        const ws = root._nWinList;
        for (let i = 0; i < ws.length; i++) {
            const c = ws[i].lastIpcObject;
            if ((field === "title" && ws[i].title === value) || (field === "class" && c && c["class"] === value)) {
                root.focusWindow(ws[i].address);
                return;
            }
        }
    }
    function closeWindow(addr) {
        if (root.isNiri) root._send({ Action: { CloseWindow: { id: root._nid(addr) } } });
    }
    function toggleFloating(addr) {
        if (root.isNiri) root._send({ Action: { ToggleWindowFloating: { id: root._nid(addr) } } });
    }
    function moveToWorkspace(addr, ws, follow) {
        if (root.isNiri) root._send({ Action: { MoveWindowToWorkspace: {
            window_id: root._nid(addr), reference: root._wsRef(ws), focus: !!follow } } });
    }
    // Absolute position in the global layout. niri only moves FLOATING
    // windows, relative to their output.
    function moveFloating(addr, x, y) {
        if (!root.isNiri) return;
        const id = root._nid(addr);
        const w = root._nWins[id];
        const out = w ? root._outputOfWs(w.niriWsId) : null;
        const ox = out ? out.x : 0, oy = out ? out.y : 0;
        root._send({ Action: { MoveFloatingWindow: { id: id,
            x: { SetFixed: Math.round(x - ox) }, y: { SetFixed: Math.round(y - oy) } } } });
    }
    function global(name) {
        root.globalRequested(name);
    }
    function toggleOverview() { if (root.isNiri) root._send({ Action: { ToggleOverview: {} } }); }
    // Shell command line that logs out of the session (for PowerPanel's cmd).
    readonly property string exitCommand: "niri msg action quit --skip-confirmation"
    // The shell's own lock screen (LockScreen.qml, thyx look), with swaylock as
    // the fallback inside the script.
    readonly property string lockCommand: Quickshell.env("HOME") + "/.config/quickshell/scripts/lock.sh"
    readonly property var reloadCommand: ["niri", "msg", "action", "load-config-file"]

    // ═══════════════════════ niri: the event stream ═════════════════
    // `niri msg --json event-stream` gives the complete state up front and then
    // the deltas, one JSON object per line. It is restarted if it ever dies
    // (niri restarting, a parse error on a newer niri, ...).
    Process {
        id: nStream
        running: root.isNiri
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: function (line) {
                let ev;
                try { ev = JSON.parse(line); } catch (e) { return; }
                root._nHandle(ev);
            }
        }
        onExited: if (root.isNiri) nStreamRestart.restart()
    }
    Timer { id: nStreamRestart; interval: 1000; onTriggered: { nStream.running = false; nStream.running = true; } }

    // Plain stores keyed by niri id; the *List properties are what QML binds to.
    property var _nWs: ({})          // niriId -> workspace look-alike
    property var _nWins: ({})        // niriId -> NiriToplevel
    property var _nOutputs: ({})     // name   -> niri output object
    property var _nWsList: []
    property var _nWinList: []
    property var _nMonList: []
    property var _nFocusedWs: null
    property string _nLastFocusedOutput: ""

    function _nHandle(ev) {
        const k = Object.keys(ev)[0];
        const d = ev[k];
        switch (k) {
        case "WorkspacesChanged": {
            const before = Object.keys(root._nOutputsOfWs()).sort().join(",");
            const m = {};
            for (const w of d.workspaces) m[w.id] = root._nMakeWs(w);
            root._nWs = m;
            root._nRebuildWs();
            root._nRelinkWindows();
            const after = Object.keys(root._nOutputsOfWs()).sort().join(",");
            if (before !== after) { root._nRequestOutputs(); root._emit("monitoradded", after); }
            root._emit("workspace", "");
            break;
        }
        case "WorkspaceActivated": {
            const w = root._nWs[d.id];
            if (!w) break;
            for (const id in root._nWs) {
                const o = root._nWs[id];
                if (o.output === w.output) o.active = (o.niriId === d.id);
                if (d.focused) o.focused = (o.niriId === d.id);
            }
            root._nRebuildWs();
            root._emit("workspace", String(w.id));
            break;
        }
        case "WorkspaceActiveWindowChanged": {
            const w = root._nWs[d.workspace_id];
            if (w) { w.activeWindowId = d.active_window_id; root._nRebuildWs(); }
            break;
        }
        case "WindowsChanged": {
            const keep = {};
            for (const w of d.windows) { root._nUpsertWin(w); keep[w.id] = true; }
            for (const id in root._nWins) if (!keep[id]) root._nDropWin(id);
            root._nRebuildWins();
            root._emit("openwindow", "");
            break;
        }
        case "WindowOpenedOrChanged": {
            const isNew = !root._nWins[d.window.id];
            if (d.window.is_focused)
                for (const id in root._nWins) root._nWins[id].focused = (Number(id) === d.window.id);
            const wasFloating = isNew ? null : root._nWins[d.window.id].floating;
            root._nUpsertWin(d.window);
            if (isNew) root._nRebuildWins(); else root._nRankFocus();
            const addr = d.window.id.toString(16);
            if (isNew) root._emit("openwindow", addr);
            else if (wasFloating !== null && wasFloating !== d.window.is_floating) root._emit("changefloatingmode", addr);
            else root._emit("windowtitle", addr);
            break;
        }
        case "WindowClosed":
            root._nDropWin(d.id);
            root._nRebuildWins();
            root._emit("closewindow", d.id.toString(16));
            break;
        case "WindowFocusChanged":
            for (const id in root._nWins) root._nWins[id].focused = (Number(id) === d.id);
            root._emit("activewindow", d.id === null ? "" : d.id.toString(16));
            break;
        case "WindowFocusTimestampChanged": {
            const w = root._nWins[d.id];
            if (w) { w.raw = Object.assign({}, w.raw, { focus_timestamp: d.focus_timestamp }); root._nRankFocus(); }
            break;
        }
        case "WindowLayoutsChanged":
            for (const pair of d.changes) {
                const w = root._nWins[pair[0]];
                if (w) { w.raw = Object.assign({}, w.raw, { layout: pair[1] }); w.rebuildIpc(); }
            }
            root._emit("resizewindow", "");
            break;
        case "OverviewOpenedOrClosed":
            root.overviewOpen = !!d.is_open;
            break;
        case "ConfigLoaded":
            root._nRequestOutputs();
            root._emit("configreloaded", d.failed ? "failed" : "");
            break;
        }
    }

    function _emit(name, data) { root.rawEvent({ name: name, data: data }); }

    function _nMakeWs(w) {
        return {
            id: w.idx, niriId: w.id, idx: w.idx,
            name: w.name || String(w.idx),
            output: w.output || "",
            monitor: { name: w.output || "" },
            active: !!w.is_active, focused: !!w.is_focused, urgent: !!w.is_urgent,
            activeWindowId: w.active_window_id
        };
    }
    function _nOutputsOfWs() {
        const o = {};
        for (const id in root._nWs) if (root._nWs[id].output) o[root._nWs[id].output] = true;
        return o;
    }
    function _nRebuildWs() {
        const l = Object.values(root._nWs).sort((a, b) =>
            a.output === b.output ? a.idx - b.idx : a.output.localeCompare(b.output));
        for (const w of l) w.id = w.idx;
        root._nWsList = l;
        let f = null;
        for (const w of l) if (w.focused) f = w;
        root._nFocusedWs = f;
        if (f && f.output !== root._nLastFocusedOutput) {
            root._nLastFocusedOutput = f.output;
            root._emit("focusedmon", f.output + "," + f.id);
        }
        root._nRebuildMons();
    }
    function _outputOfWs(niriWsId) {
        const w = root._nWs[niriWsId];
        if (!w) return null;
        const o = root._nOutputs[w.output];
        return o && o.logical ? o.logical : null;
    }
    function _wsRef(ws) {
        // `ws` is the look-alike id. Prefer the focused output's workspace.
        const out = root.focusedOutput;
        for (const id in root._nWs) {
            const w = root._nWs[id];
            if (out !== "" && w.output !== out) continue;
            if (w.id === ws) return { Id: w.niriId };
        }
        // Not created yet (beyond the last one): by index.
        return { Index: ws };
    }

    function _nUpsertWin(w) {
        let t = root._nWins[w.id];
        if (!t) {
            t = nToplevel.createObject(root, { niriId: w.id });
            const m = root._nWins;
            m[w.id] = t;
        }
        t.raw = w;
        t.focused = !!w.is_focused;
        t.workspace = root._nWs[w.workspace_id] || null;
        t.rebuildIpc();
    }
    function _nDropWin(id) {
        const t = root._nWins[id];
        if (!t) return;
        delete root._nWins[id];
        t.destroy();
    }
    function _nRelinkWindows() {
        for (const id in root._nWins) {
            const t = root._nWins[id];
            t.workspace = root._nWs[t.raw.workspace_id] || null;
            t.rebuildIpc();
        }
    }
    function _nRebuildWins() {
        root._nRankFocus();
        root._nWinList = Object.values(root._nWins);
    }
    // Hyprland's focusHistoryID: 0 = most recent. niri gives a timestamp.
    function _nRankFocus() {
        const ts = w => { const f = w.raw && w.raw.focus_timestamp; return f ? f.secs * 1e9 + f.nanos : 0; };
        const l = Object.values(root._nWins).sort((a, b) => ts(b) - ts(a));
        for (let i = 0; i < l.length; i++) {
            if (l[i].focusRank !== i) { l[i].focusRank = i; l[i].rebuildIpc(); }
        }
    }

    function _nRebuildMons() {
        const out = [];
        for (const name in root._nOutputs) {
            const o = root._nOutputs[name];
            const lg = o.logical;
            if (!lg) continue;   // off
            let active = null;
            for (const id in root._nWs) {
                const w = root._nWs[id];
                if (w.output === name && w.active) active = w;
            }
            const focused = !!(root._nFocusedWs && root._nFocusedWs.output === name);
            out.push({
                name: name,
                focused: focused,
                activeWorkspace: active ? { id: active.id } : null,
                lastIpcObject: {
                    name: name, x: lg.x, y: lg.y, width: lg.width, height: lg.height,
                    scale: lg.scale, focused: focused,
                    activeWorkspace: active ? { id: active.id } : null
                }
            });
        }
        root._nMonList = out;
    }

    // One window, shaped like a HyprlandToplevel.
    Component {
        id: nToplevel
        QtObject {
            id: tl
            property int niriId: -1
            property var raw: ({})
            property bool focused: false
            property var workspace: null
            property int focusRank: 999
            property var lastIpcObject: ({})
            readonly property string address: tl.niriId.toString(16)
            readonly property string title: tl.raw.title || ""
            readonly property string appId: tl.raw.app_id || ""
            readonly property bool floating: !!tl.raw.is_floating
            readonly property int niriWsId: tl.raw.workspace_id === undefined || tl.raw.workspace_id === null ? -1 : tl.raw.workspace_id
            // The matching Wayland toplevel (for ScreencopyView live thumbnails).
            // niri's IPC and the foreign-toplevel protocol share no id, so it is
            // matched by app id + title, falling back to the app id alone.
            readonly property var wayland: {
                const ts = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
                let best = null;
                for (let i = 0; i < ts.length; i++) {
                    if (ts[i].appId !== tl.appId) continue;
                    if (ts[i].title === tl.title) return ts[i];
                    if (!best) best = ts[i];
                }
                return best;
            }
            function rebuildIpc() {
                const r = tl.raw || {};
                const lay = r.layout || {};
                const size = lay.window_size || lay.tile_size || [800, 600];
                const out = root._outputOfWs(tl.niriWsId);
                const ox = out ? out.x : 0, oy = out ? out.y : 0;
                let at;
                if (lay.tile_pos_in_workspace_view) {
                    const off = lay.window_offset_in_tile || [0, 0];
                    at = [ox + lay.tile_pos_in_workspace_view[0] + off[0], oy + lay.tile_pos_in_workspace_view[1] + off[1]];
                } else if (lay.pos_in_scrolling_layout) {
                    // Tiled windows: niri 26.04 only reports a view position for
                    // floating ones, so tiles are laid out from their column/row
                    // index and tile size, as if the strip started at the left
                    // edge (no scroll offset), and clamped to the output, below
                    // the band the bar reserves (reservedTop, set by ShellState).
                    const gap = 6;
                    const col = lay.pos_in_scrolling_layout[0], row = lay.pos_in_scrolling_layout[1];
                    const tile = lay.tile_size || size;
                    const off = lay.window_offset_in_tile || [0, 0];
                    const ow = out ? out.width : 1920, oh = out ? out.height : 1080;
                    const tx = gap + (col - 1) * (tile[0] + gap);
                    const ty = root.reservedTop + gap + (row - 1) * (tile[1] + gap);
                    at = [ox + Math.min(Math.max(0, ow - tile[0]), tx) + off[0],
                          oy + Math.min(Math.max(0, oh - tile[1]), ty) + off[1]];
                } else {
                    at = [ox + 16, oy + 16];
                }
                tl.lastIpcObject = {
                    address: "0x" + tl.address,
                    "class": r.app_id || "", initialClass: r.app_id || "",
                    title: r.title || "", initialTitle: r.title || "",
                    pid: r.pid || 0,
                    at: [Math.round(at[0]), Math.round(at[1])],
                    size: [Math.round(size[0]), Math.round(size[1])],
                    floating: !!r.is_floating, fullscreen: false,
                    workspace: tl.workspace ? { id: tl.workspace.id, name: tl.workspace.name } : { id: -1 },
                    focusHistoryID: tl.focusRank
                };
            }
        }
    }

    // ═══════════════════════ niri: requests ═════════════════════════
    // The socket answers ONE request per connection (see niri's IPC.md:
    // "write your request ... read the reply ... on a single line"), so
    // requests are queued and each one opens, writes, reads and closes.
    property var _q: []
    property var _cur: null
    function _send(obj) {
        if (!root.isNiri) return;
        root._q.push(obj);
        if (root._cur === null) root._next();
    }
    function _next() {
        if (root._q.length === 0) { root._cur = null; return; }
        root._cur = root._q.shift();
        nReq.connected = true;
    }
    Socket {
        id: nReq
        path: root.niriSocket
        connected: false
        onConnectionStateChanged: {
            if (nReq.connected) {
                nReq.write(JSON.stringify(root._cur) + "\n");
                nReq.flush();
            } else if (root._cur !== null) {
                Qt.callLater(root._next);
            }
        }
        // A failed connect never flips `connected`, so move on or the queue stalls.
        onError: function (e) {
            console.warn("niri socket:", e);
            if (root._cur !== null) Qt.callLater(root._next);
        }
        parser: SplitParser {
            onRead: function (line) {
                let r = null;
                try { r = JSON.parse(line); } catch (e) {}
                if (r && r.Err) console.warn("niri:", r.Err, JSON.stringify(root._cur));
                else if (r && r.Ok && r.Ok.Outputs) {
                    root._nOutputs = r.Ok.Outputs;
                    root._nRebuildMons();
                    root._nRelinkWindows();
                }
                nReq.connected = false;
            }
        }
    }
    function _nRequestOutputs() { root._send("Outputs"); }

    // Debugging / scripting door: `qs ipc call compositor state`.
    IpcHandler {
        target: "compositor"
        function state(): string {
            return JSON.stringify({
                backend: root.backend,
                focusedOutput: root.focusedOutput,
                outputHasWindows: root.outputHasWindows(root.focusedOutput),
                focusedWorkspace: root.focusedWorkspace ? root.focusedWorkspace.id : null,
                workspaces: root.workspaces.map(w => ({ id: w.id, output: w.monitor ? w.monitor.name : "" })),
                monitors: root.monitors.map(m => m.name),
                windows: root.toplevels.map(t => ({ address: t.address, title: t.title,
                    ws: t.workspace ? t.workspace.id : -1, at: t.lastIpcObject ? t.lastIpcObject.at : null,
                    wayland: !!t.wayland }))
            });
        }
        function workspace(ws: int): void { root.focusWorkspace(ws); }
        function window(addr: string): void { root.focusWindow(addr); }
        function close(addr: string): void { root.closeWindow(addr); }
        function float(addr: string): void { root.toggleFloating(addr); }
        function move(addr: string, ws: int): void { root.moveToWorkspace(addr, ws, false); }
        function overview(): void { root.toggleOverview(); }
    }

    Component.onCompleted: if (root.isNiri) root._nRequestOutputs()
}
