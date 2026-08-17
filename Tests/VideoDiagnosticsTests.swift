import Foundation
import Testing
@testable import Wianu

@MainActor
struct VideoDiagnosticsTests {
    @Test
    func `Playing video is preferred over a larger paused video`() {
        let controller = VideoDiagnosticsController()
        controller.receive(json: reportJSON(videos: [
            videoJSON(id: "large", width: 3840, height: 2160, paused: true),
            videoJSON(id: "playing", width: 1920, height: 1080, paused: false)
        ]))

        #expect(controller.videos.count == 2)
        #expect(controller.selectedVideo?.id == "playing")
    }

    @Test
    func `Largest decoded video is preferred when playback state matches`() {
        let controller = VideoDiagnosticsController()
        controller.receive(json: reportJSON(videos: [
            videoJSON(id: "small", width: 640, height: 360, paused: true),
            videoJSON(id: "large", width: 1920, height: 1080, paused: true)
        ]))

        #expect(controller.selectedVideo?.id == "large")
    }

    @Test
    func `Stale frame reports expire`() {
        let controller = VideoDiagnosticsController()
        let receivedAt = Date(timeIntervalSince1970: 100)
        controller.receive(
            json: reportJSON(videos: [videoJSON(id: "video")]),
            now: receivedAt
        )

        controller.removeStaleReports(
            now: receivedAt.addingTimeInterval(4)
        )

        #expect(controller.videos.isEmpty)
        #expect(controller.selectedVideo == nil)
    }

    @Test
    func `Malformed reports are ignored`() {
        let controller = VideoDiagnosticsController()
        controller.receive(json: "not json")

        #expect(controller.videos.isEmpty)
    }

    private func reportJSON(videos: [String]) -> String {
        """
        {"frameID":"frame","videos":[\(videos.joined(separator: ","))]}
        """
    }

    private func videoJSON(
        id: String,
        width: Int = 1280,
        height: Int = 720,
        paused: Bool = false
    ) -> String {
        """
        {
          "id":"\(id)",
          "videoWidth":\(width),
          "videoHeight":\(height),
          "displayWidth":640,
          "displayHeight":360,
          "paused":\(paused),
          "ended":false,
          "seeking":false,
          "readyState":4,
          "currentTime":30,
          "duration":120,
          "bufferedAhead":10,
          "droppedFrames":1,
          "totalFrames":900,
          "sourceDescription":"media.example.com",
          "sourceType":"video/mp4"
        }
        """
    }
}
