import SwiftUI
import UIKit

/// The system share sheet, presented for an already-written file.
///
/// Not `ShareLink`: that evaluates its item when the *view* is built, so the
/// whole export would run on every re-render of the screen it sits on. The
/// export is built when the user asks for it, then handed to this.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    /// Called once the activity has finished with the file; `true` when an
    /// action completed (saved, sent, copied), `false` on Cancel. A completed
    /// action is what counts as an export (Floodlight ticket 09, decision 1).
    var onFinish: (_ completed: Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onFinish(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
