import NoGymKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The editor's video part: pick a video, then pick a segment for each exercise.
struct VideoSection: View {
    @Binding var video: WorkoutVideo?
    /// The sequence's exercises, each name once.
    let labels: [String]

    @State private var photoItem: PhotosPickerItem?
    @State private var isPickingPhoto = false
    @State private var isPickingFile = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var trimming: TrimTarget?

    var body: some View {
        Section {
            if isImporting {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Copying video…").foregroundStyle(.secondary)
                }
            } else if let video {
                LabeledContent("Video", value: Format.clock(video.duration))
                    .monospacedDigit()
                ForEach(labels, id: \.self) { label in
                    Button {
                        trimming = TrimTarget(label: label)
                    } label: {
                        HStack {
                            Text(label).foregroundStyle(Color.primary)
                            Spacer()
                            if let segment = video.segment(for: label) {
                                Text("\(Format.timecode(segment.start)) – \(Format.timecode(segment.end))")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No video").foregroundStyle(.tertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Menu("Replace or remove video") {
                    pickers
                    Button("Remove video", systemImage: "trash", role: .destructive) { self.video = nil }
                }
            } else {
                pickers
            }
        } header: {
            Text("Video")
        } footer: {
            Text(video == nil
                 ? "Add a video to show a looping part of it while each exercise runs."
                 : "Tap an exercise to choose its part of the video. Exercises with the same name share it, in every round. Exercises without a part show only the timer.")
        }
        .photosPicker(isPresented: $isPickingPhoto, selection: $photoItem, matching: .videos,
                      preferredItemEncoding: .current)
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.movie]) { result in
            guard case .success(let url) = result else { return }
            load { try await VideoLibrary.importFile(url) }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            load {
                guard let picked = try await item.loadTransferable(type: PickedVideo.self) else {
                    throw VideoLibrary.ImportError.unreadable
                }
                return try await VideoLibrary.makeVideo(fromCopyAt: picked.url)
            }
        }
        .sheet(item: $trimming) { target in
            if let video {
                VideoTrimmerView(video: video, label: target.label) { segment in
                    self.video?.setSegment(segment, for: target.label)
                }
                .interactiveDismissDisabled()
            }
        }
        .alert("Can't use that video", isPresented: Binding(get: { importError != nil },
                                                             set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    @ViewBuilder private var pickers: some View {
        Button("Choose from Photos", systemImage: "photo.on.rectangle") { isPickingPhoto = true }
        Button("Choose from Files", systemImage: "folder") { isPickingFile = true }
    }

    /// Copies the picked video in and swaps it for the current one. Segments start
    /// empty, because times in the old video mean nothing in the new one.
    private func load(_ work: @escaping () async throws -> WorkoutVideo) {
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                video = try await work()
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}

private struct TrimTarget: Identifiable {
    let label: String
    var id: String { label }
}
