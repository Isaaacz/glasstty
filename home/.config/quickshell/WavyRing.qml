// WavyRing.qml — circular progress drawn as a wavy line (media cover art).
//
// A faint full circle is the track; the played part is a sine-modulated arc
// starting at 12 o'clock and going clockwise. While `live` (playing) the wave
// slides along the arc, so a paused song looks still and a playing one moves.
import QtQuick

Canvas {
    id: ring
    property real progress: 0          // 0..1
    property color color: Colors.accent
    property color track: Qt.rgba(color.r, color.g, color.b, 0.18)
    property real lineWidth: 4
    property real amplitude: 3.2       // px, radial wobble of the played arc
    property int waves: 14             // waves around the whole circle
    property bool live: false
    property real phase: 0

    onProgressChanged: requestPaint()
    onColorChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onWidthChanged: requestPaint()

    NumberAnimation on phase {
        running: ring.live && ring.visible
        from: 0; to: Math.PI * 2
        duration: 2200
        loops: Animation.Infinite
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2, cy = height / 2;
        const r = Math.min(width, height) / 2 - ring.lineWidth - ring.amplitude;
        ctx.lineCap = "round";
        ctx.lineWidth = ring.lineWidth;

        ctx.strokeStyle = ring.track;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.stroke();

        const p = Math.max(0, Math.min(1, ring.progress));
        if (p <= 0.002) return;
        const start = -Math.PI / 2, end = start + p * Math.PI * 2;
        const steps = Math.max(24, Math.round(240 * p));
        ctx.strokeStyle = ring.color;
        ctx.beginPath();
        for (let i = 0; i <= steps; i++) {
            const a = start + (end - start) * i / steps;
            // Taper the wave at both ends so the line starts and lands cleanly.
            const t = i / steps, taper = Math.min(1, t * 6, (1 - t) * 6);
            const rr = r + Math.sin((a - start) * ring.waves + ring.phase) * ring.amplitude * taper;
            const x = cx + rr * Math.cos(a), y = cy + rr * Math.sin(a);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
}
