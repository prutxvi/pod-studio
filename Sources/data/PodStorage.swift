// Pod Studio private application storage. Added 2026-11-15, GPL-3.0.
import Foundation
enum PodStorage {
    static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let url = base.appendingPathComponent("Pod Studio", isDirectory: true)
        do { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
        catch { return nil }
    }
}
