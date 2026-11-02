import SwiftUI
import Observation
import AyatDesign

/// Editor settings kept with a project so it can be reopened and changed (docs/APP_ARCHITECTURE.md:
/// ProjectSettings). Unknown ids fall back to defaults when an editor opens them.
struct EditorSettings: Codable, Equatable, Hashable {
    var surah: Int
    var from: Int
    var to: Int
    var ratio: String
    var background: String        // still or motion background id, or "photo"
    var fontScale: Double
    var template: String
    var name: String
    var reciter: String?
}

struct Project: Codable, Identifiable, Equatable, Hashable {
    enum Kind: String, Codable { case clip, card, status, hadithCard }
    let id: UUID
    var kind: Kind
    var title: String
    var createdAt: Date
    var ratio: String
    var file: String              // in the projects folder
    var thumbnail: String
    var settings: EditorSettings?

    var kindName: String {
        switch kind {
        case .clip: "مقطع"
        case .card: "بطاقة"
        case .status: "حالة"
        case .hadithCard: "بطاقة حديث"
        }
    }

    /// "مقطع · ٩:١٦"
    var subtitle: String { "\(kindName) · \(Num.digits(ratio))" }
}

/// Projects saved on the device (Application Support/Projects): the exported file, a thumbnail and
/// the editor settings, listed newest first in Library and on Home.
@Observable
final class ProjectStore {
    static let shared = ProjectStore()

    private(set) var projects: [Project] = []
    let dir: URL

    init(dir: URL? = nil) {
        let base = dir ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Projects", isDirectory: true)
        self.dir = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: indexURL), let list = try? JSONDecoder().decode([Project].self, from: d) {
            projects = list.filter { FileManager.default.fileExists(atPath: base.appendingPathComponent($0.file).path) }
        }
    }

    private var indexURL: URL { dir.appendingPathComponent("index.json") }

    func url(_ p: Project) -> URL { dir.appendingPathComponent(p.file) }
    func thumbnailURL(_ p: Project) -> URL { dir.appendingPathComponent(p.thumbnail) }

    /// Copies `file` into the projects folder and records it. Returns the new project.
    @discardableResult
    func add(kind: Project.Kind, title: String, file: URL, thumbnail: UIImage?, ratio: String,
             settings: EditorSettings?) throws -> Project {
        let id = UUID()
        let name = "\(id.uuidString).\(file.pathExtension.isEmpty ? "bin" : file.pathExtension)"
        try FileManager.default.copyItem(at: file, to: dir.appendingPathComponent(name))
        let thumb = "\(id.uuidString)-thumb.jpg"
        if let data = thumbnail?.preparingThumbnail(of: CGSize(width: 360, height: 640))?.jpegData(compressionQuality: 0.8)
            ?? thumbnail?.jpegData(compressionQuality: 0.6) {
            try? data.write(to: dir.appendingPathComponent(thumb))
        }
        let p = Project(id: id, kind: kind, title: title, createdAt: Date(), ratio: ratio, file: name, thumbnail: thumb, settings: settings)
        projects.insert(p, at: 0)
        save()
        return p
    }

    /// Saves an image (card, status) as a PNG project.
    @discardableResult
    func addImage(_ image: UIImage, kind: Project.Kind, title: String, ratio: String, settings: EditorSettings?) throws -> Project {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        guard let png = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try add(kind: kind, title: title, file: tmp, thumbnail: image, ratio: ratio, settings: settings)
    }

    func delete(_ p: Project) {
        try? FileManager.default.removeItem(at: url(p))
        try? FileManager.default.removeItem(at: thumbnailURL(p))
        projects.removeAll { $0.id == p.id }
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(projects) { try? d.write(to: indexURL, options: .atomic) }
    }
}
