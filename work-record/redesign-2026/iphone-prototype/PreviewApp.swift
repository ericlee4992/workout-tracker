// Throwaway simulator shell for the design study. No production data or services.
import UIKit
import WebKit

@main
final class PreviewApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Preview", sessionRole: session.role)
        configuration.delegateClass = PreviewScene.self
        return configuration
    }
}

final class PreviewScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = PreviewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class PreviewController: UIViewController {
    private let browser = WKWebView(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 17/255, green: 22/255, blue: 16/255, alpha: 1)
        let toolbar = UIStackView()
        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.distribution = .equalSpacing
        let title = UILabel()
        title.text = "DESIGN PREVIEW"
        title.font = .systemFont(ofSize: 10, weight: .semibold)
        title.textColor = .secondaryLabel
        toolbar.addArrangedSubview(title)
        let layouts = UIButton(type: .system)
        layouts.setTitle("Layout ⌄", for: .normal)
        layouts.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        layouts.menu = UIMenu(children: [("Focus", "home"), ("Library", "library"), ("Journal", "journal")].map { name, screen in
            UIAction(title: name) { [weak self] _ in self?.navigate(screen) }
        })
        layouts.showsMenuAsPrimaryAction = true
        toolbar.addArrangedSubview(layouts)
        let screens = UIButton(type: .system)
        screens.setTitle("Explore ⌄", for: .normal)
        screens.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        screens.menu = UIMenu(children: [
            ("Workout", "home"), ("Active workout", "active"), ("Rest", "rest"),
            ("Cardio", "cardioSetup"), ("Finish receipt", "finish"),
            ("Templates", "templates"), ("Ask AI for Templates", "ai"),
            ("Gyms", "gyms"), ("Scan Machine", "scan"), ("Exercises", "exercises"),
            ("History", "history"), ("Progress", "progress"), ("Settings", "settings"),
            ("First workout", "empty"), ("Connection error", "error"),
            ("Lock Screen concept", "live")
        ].map { name, screen in
            UIAction(title: name) { [weak self] _ in self?.navigate(screen) }
        })
        screens.showsMenuAsPrimaryAction = true
        toolbar.addArrangedSubview(screens)
        toolbar.tintColor = .secondaryLabel
        for child in [toolbar, browser] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            toolbar.heightAnchor.constraint(equalToConstant: 38),
            browser.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            browser.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            browser.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            browser.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        browser.isOpaque = false
        browser.backgroundColor = view.backgroundColor
        browser.scrollView.contentInsetAdjustmentBehavior = .never
        browser.isInspectable = true
        if let page = Bundle.main.url(forResource: "prototype", withExtension: "html") {
            browser.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
    }

    private func navigate(_ screen: String) {
        browser.evaluateJavaScript("const p=document.getElementById('wt-screen');p.value='\(screen)';p.dispatchEvent(new Event('change'));")
    }
}
