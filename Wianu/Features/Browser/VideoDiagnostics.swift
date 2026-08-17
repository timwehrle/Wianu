import Foundation
import Observation
import WebKit

struct VideoDiagnostic: Decodable, Identifiable {
    let id: String
    let videoWidth: Int
    let videoHeight: Int
    let displayWidth: Double
    let displayHeight: Double
    let paused: Bool
    let ended: Bool
    let seeking: Bool
    let readyState: Int
    let currentTime: Double
    let duration: Double?
    let bufferedAhead: Double
    let droppedFrames: Int?
    let totalFrames: Int?
    let sourceDescription: String?
    let sourceType: String?

    var playbackState: String {
        if ended {
            return "Ended"
        }
        if seeking || (!paused && readyState < 3) {
            return "Buffering"
        }
        return paused ? "Paused" : "Playing"
    }

    var isPlaying: Bool {
        !paused && !ended
    }

    var decodedArea: Int {
        videoWidth * videoHeight
    }

    var displayArea: Double {
        displayWidth * displayHeight
    }
}

private struct VideoFrameReport: Decodable {
    let frameID: String
    let videos: [VideoDiagnostic]
}

@MainActor
@Observable
final class VideoDiagnosticsController: NSObject, WKScriptMessageHandler {
    private struct FrameVideos {
        let videos: [VideoDiagnostic]
        let receivedAt: Date
    }

    private static let handlerName = "videoDiagnostics"
    private static let staleInterval: TimeInterval = 3
    private static let contentWorld = WKContentWorld.world(
        name: "WianuVideoDiagnostics"
    )

    private var frames: [String: FrameVideos] = [:]

    var videos: [VideoDiagnostic] {
        frames.values.flatMap(\.videos)
    }

    var selectedVideo: VideoDiagnostic? {
        videos.max { lhs, rhs in
            let lhsRank = (
                lhs.isPlaying ? 1 : 0,
                lhs.decodedArea,
                lhs.displayArea
            )
            let rhsRank = (
                rhs.isPlaying ? 1 : 0,
                rhs.decodedArea,
                rhs.displayArea
            )
            return lhsRank < rhsRank
        }
    }

    func install(in userContentController: WKUserContentController) {
        userContentController.add(
            self,
            contentWorld: Self.contentWorld,
            name: Self.handlerName
        )
        userContentController.addUserScript(
            WKUserScript(
                source: Self.observerScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false,
                in: Self.contentWorld
            )
        )
    }

    func clear() {
        frames.removeAll()
    }

    func removeStaleReports(now: Date = Date()) {
        frames = frames.filter {
            now.timeIntervalSince($0.value.receivedAt) < Self.staleInterval
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard
            message.name == Self.handlerName,
            message.world == Self.contentWorld,
            let json = message.body as? String
        else { return }

        receive(json: json)
    }

    func receive(json: String, now: Date = Date()) {
        guard
            json.utf8.count <= 64000,
            let data = json.data(using: .utf8),
            let report = try? JSONDecoder().decode(
                VideoFrameReport.self,
                from: data
            ),
            report.frameID.count <= 100,
            report.videos.count <= 50
        else { return }

        frames[report.frameID] = FrameVideos(
            videos: report.videos,
            receivedAt: now
        )
        removeStaleReports(now: now)
    }

    private static let observerScript = #"""
    (() => {
        if (globalThis.__wianuVideoDiagnosticsInstalled) return;
        globalThis.__wianuVideoDiagnosticsInstalled = true;

        const frameID = globalThis.crypto?.randomUUID?.()
            ?? `${Date.now()}-${Math.random()}`;
        const ids = new WeakMap();
        let nextID = 0;

        const finiteNumber = (value, fallback = 0) =>
            Number.isFinite(value) ? value : fallback;

        const videoID = (video) => {
            if (!ids.has(video)) ids.set(video, `${frameID}-${nextID++}`);
            return ids.get(video);
        };

        const sourceInfo = (video) => {
            const source = video.currentSrc || video.src || "";
            let sourceDescription = null;
            if (source.startsWith("blob:")) {
                sourceDescription = "Media Source (blob)";
            } else if (source) {
                try {
                    const url = new URL(source, document.baseURI);
                    sourceDescription = url.host || url.protocol.replace(":", "");
                } catch (_) {}
            }

            let sourceType = null;
            const candidates = Array.from(video.querySelectorAll("source"));
            const selected = candidates.find((candidate) =>
                candidate.src && candidate.src === video.currentSrc
            ) ?? candidates.find((candidate) => candidate.type);
            if (selected?.type) sourceType = selected.type.slice(0, 200);

            return {
                sourceDescription: sourceDescription?.slice(0, 200) ?? null,
                sourceType
            };
        };

        const bufferedAhead = (video) => {
            for (let index = 0; index < video.buffered.length; index++) {
                if (video.buffered.start(index) <= video.currentTime
                    && video.buffered.end(index) >= video.currentTime) {
                    return video.buffered.end(index) - video.currentTime;
                }
            }
            return 0;
        };

        const describe = (video) => {
            const rect = video.getBoundingClientRect();
            const quality = video.getVideoPlaybackQuality?.();
            const droppedFrames = quality?.droppedVideoFrames
                ?? video.webkitDroppedFrameCount;
            const totalFrames = quality?.totalVideoFrames
                ?? video.webkitDecodedFrameCount;

            return {
                id: videoID(video),
                videoWidth: Math.max(0, Math.round(finiteNumber(video.videoWidth))),
                videoHeight: Math.max(0, Math.round(finiteNumber(video.videoHeight))),
                displayWidth: Math.max(0, finiteNumber(rect.width)),
                displayHeight: Math.max(0, finiteNumber(rect.height)),
                paused: video.paused,
                ended: video.ended,
                seeking: video.seeking,
                readyState: video.readyState,
                currentTime: Math.max(0, finiteNumber(video.currentTime)),
                duration: Number.isFinite(video.duration) ? video.duration : null,
                bufferedAhead: Math.max(0, finiteNumber(bufferedAhead(video))),
                droppedFrames: Number.isFinite(droppedFrames)
                    ? Math.max(0, Math.round(droppedFrames)) : null,
                totalFrames: Number.isFinite(totalFrames)
                    ? Math.max(0, Math.round(totalFrames)) : null,
                ...sourceInfo(video)
            };
        };

        const send = () => {
            const json = JSON.stringify({
                frameID,
                videos: Array.from(document.querySelectorAll("video")).map(describe)
            });
            globalThis.webkit?.messageHandlers?.videoDiagnostics?.postMessage(json);
        };

        const events = [
            "durationchange", "emptied", "ended", "loadedmetadata", "pause",
            "play", "playing", "progress", "resize", "seeking", "waiting"
        ];
        for (const event of events) {
            document.addEventListener(event, send, true);
        }

        new MutationObserver(send).observe(document.documentElement, {
            childList: true,
            subtree: true
        });
        setInterval(send, 1000);
        send();
    })();
    """#
}
