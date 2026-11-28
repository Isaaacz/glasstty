// Audio.qml — output volume and mute (Pipewire), and the volume OSD when they
// change from outside the shell. Split out of ShellState.qml.
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

    // ═══════════════════════ audio (Pipewire) ═══════════════════════
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int vol: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false

    // THE OSD MUST NOT APPEAR BECAUSE OF AN OUTPUT CHANGE.
    //
    // `vol` is derived from `sink`, so plugging in headphones, switching off the
    // radio or choosing another output in Settings made `vol` jump without
    // anybody having touched the volume, and an OSD you had not asked for
    // appeared.
    //
    // Listening to onSinkChanged and lowering a flag is not enough: the order in
    // which QML notifies `sink` and the `vol` that depends on it is not
    // guaranteed, and if `vol` arrived first the notice would appear anyway.
    // Comparing the sink against the last one we saw makes the result
    // independent of the order. The grace window covers the burst of changes
    // that arrives while the new output settles. It is what impasto calls
    // suppressAudio() (OsdService.qml:33-35, called from
    // ControlsService.qml:164-165).
    property var _sinkVisto: null
    Timer { id: sinkGracia; interval: 500 }

    // The two paths, and both are needed. This one seeds the reference as soon
    // as the output changes, so that the FIRST volume change after a shell
    // reload does not swallow the notice. And the comparison in _audioEsTuyo()
    // is the safety net in case QML notified `vol` before `sink`, which is an
    // order that is not guaranteed.
    onSinkChanged: {
        root._sinkVisto = root.sink;
        sinkGracia.restart();
    }

    function _audioEsTuyo() {
        if (root.sink !== root._sinkVisto) {
            root._sinkVisto = root.sink;
            sinkGracia.restart();
            return false;
        }
        return !sinkGracia.running;
    }

    onVolChanged: if (ShellState.armed && _audioEsTuyo()) ShellState.flash("volume")
    onMutedChanged: if (ShellState.armed && _audioEsTuyo()) ShellState.flash("volume")

    function setVolume(pct) {
        if (!sink || !sink.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1.4, pct / 100));
    }
    function nudgeVolume(dir) {
        if (!sink || !sink.audio) return;
        // Unmutes, same as setVolume. Without this, the wheel over the notch
        // with the sound muted left the bar pinned at 0 while the real level
        // climbed behind its back up to 140%: you unmuted and got slapped in
        // the face. Moving the volume IS asking to hear.
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1.4, sink.audio.volume + dir * 0.02));
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; }
}
