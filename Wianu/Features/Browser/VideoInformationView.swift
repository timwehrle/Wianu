import SwiftUI

struct VideoInformationView: View {
    let diagnostics: VideoDiagnosticsController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Video Information", systemImage: "info.bubble")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            if let video = diagnostics.selectedVideo {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    row("Stream Resolution", resolution(video))
                    row("Player Size", playerSize(video))
                    row("Status", video.playbackState)
                    row("Position", position(video))
                    row("Buffered Ahead", duration(video.bufferedAhead))
                    row("Video Frames", frames(video))
                    row("Source", video.sourceDescription ?? "Unavailable")
                    row("Media Type", video.sourceType ?? "Unavailable")
                    row("Videos Detected", String(diagnostics.videos.count))
                }
            } else {
                ContentUnavailableView(
                    "No Video Detected",
                    systemImage: "video.slash",
                    description: Text(
                        "Start a video on the current page and keep this window open."
                    )
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .padding(24)
        .frame(width: 460)
        .task {
            while !Task.isCancelled {
                diagnostics.removeStaleReports()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    private func resolution(_ video: VideoDiagnostic) -> String {
        guard video.videoWidth > 0, video.videoHeight > 0 else {
            return "Waiting for metadata"
        }
        return "\(video.videoWidth) × \(video.videoHeight)"
    }

    private func playerSize(_ video: VideoDiagnostic) -> String {
        "\(Int(video.displayWidth.rounded())) × \(Int(video.displayHeight.rounded()))"
    }

    private func position(_ video: VideoDiagnostic) -> String {
        guard let total = video.duration else {
            return duration(video.currentTime)
        }
        return "\(duration(video.currentTime)) / \(duration(total))"
    }

    private func frames(_ video: VideoDiagnostic) -> String {
        guard let total = video.totalFrames else { return "Unavailable" }
        if let dropped = video.droppedFrames {
            return "\(total) decoded, \(dropped) dropped"
        }
        return "\(total) decoded"
    }

    private func duration(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded(.down)))
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let remainingSeconds = value % 60
        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours,
                minutes,
                remainingSeconds
            )
        }
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
