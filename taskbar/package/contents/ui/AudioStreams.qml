/*
 * Playback streams from PipeWire/PulseAudio (plasma-pa), matched to tasks by
 * process id, Flatpak app id or application name.
 */
import QtQuick
import org.kde.plasma.private.volume

Item {
    id: audio

    property bool active: true
    // Bumped whenever a stream appears, disappears or changes state, so
    // bindings that call streamsFor() re-evaluate
    property int revision: 0

    function streamsFor(pid, appName, appId) {
        const name = String(appName || "").toLowerCase()
        const id = String(appId || "").toLowerCase()
        const result = []
        for (let i = 0; i < streams.count; i++) {
            const s = streams.objectAt(i)
            if (!s || !s.stream) continue
            if ((pid > 0 && s.pid === pid)
                    || (id.length > 0 && s.portalAppId === id)
                    || (name.length > 0 && s.appName === name)) {
                result.push(s)
            }
        }
        return result
    }

    Instantiator {
        id: streams
        active: audio.active

        model: PulseObjectFilterModel {
            filters: [{ role: "VirtualStream", value: false }]
            sourceModel: SinkInputModel {}
        }

        delegate: QtObject {
            required property var model

            readonly property var stream: model.PulseObject
            readonly property var props: stream && stream.properties ? stream.properties : ({})
            readonly property int pid: Number(props["application.process.id"] || 0)
            readonly property string appName: String(props["application.name"] || "").toLowerCase()
            readonly property string portalAppId: String(props["pipewire.access.portal.app_id"] || "").toLowerCase()
            readonly property bool muted: stream ? stream.muted : false
            readonly property bool corked: stream ? stream.corked : true

            function setMuted(value) {
                if (stream) stream.muted = value
            }

            onMutedChanged: audio.revision++
            onCorkedChanged: audio.revision++
        }

        onObjectAdded: audio.revision++
        onObjectRemoved: audio.revision++
    }
}
