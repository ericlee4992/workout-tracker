import SwiftUI
import UIKit

/// The system share sheet, presented for an already-written file.
///
/// Not `ShareLink`: that evaluates its item when the *view* is built, so the
/// whole export would run on every re-render of the screen it sits on. The
/// export is built when the user asks for it, then handed to this.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    /// Called once the activity has finished with the file (shared, saved, or
    /// cancelled) — the staged copy can be deleted only then.
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
