import SwiftUI
import UIKit

enum SinfoniaNavigationAppearance {
    static func configure() {
        #if os(iOS)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()

        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
        ]

        let backButtonAppearance = UIBarButtonItemAppearance(style: .plain)
        let backAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
        ]
        backButtonAppearance.normal.titleTextAttributes = backAttributes
        backButtonAppearance.highlighted.titleTextAttributes = backAttributes
        backButtonAppearance.disabled.titleTextAttributes = backAttributes
        backButtonAppearance.focused.titleTextAttributes = backAttributes
        appearance.backButtonAppearance = backButtonAppearance

        let navigationBar = UINavigationBar.appearance()
        navigationBar.tintColor = .white
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = appearance
        }
        #endif
    }
}

private final class SinfoniaNavigationControllerBridgeController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureNavigationController()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureNavigationController()
    }

    func configureNavigationController() {
        guard let navigationController else { return }
        navigationController.interactivePopGestureRecognizer?.delegate = nil
        navigationController.interactivePopGestureRecognizer?.isEnabled = navigationController.viewControllers.count > 1
    }
}

private struct SinfoniaNavigationControllerBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SinfoniaNavigationControllerBridgeController {
        SinfoniaNavigationControllerBridgeController()
    }

    func updateUIViewController(
        _ uiViewController: SinfoniaNavigationControllerBridgeController,
        context: Context
    ) {
        uiViewController.configureNavigationController()
    }
}

private struct SinfoniaEdgeSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 18, coordinateSpace: .local)
                .onEnded { value in
                    let startedFromLeadingEdge = value.startLocation.x <= 32
                    let horizontalTravel = value.translation.width
                    let verticalTravel = abs(value.translation.height)
                    let mostlyHorizontal = horizontalTravel > (verticalTravel * 1.35)

                    guard startedFromLeadingEdge,
                          horizontalTravel > 82,
                          mostlyHorizontal else {
                        return
                    }

                    dismiss()
                }
        )
    }
}

private struct SinfoniaBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.trailing, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sinfoniaInteractiveBackSupport()
    }
}

extension View {
    func sinfoniaNavigationRoot() -> some View {
        background(SinfoniaNavigationControllerBridge())
    }

    func sinfoniaInteractiveBackSupport() -> some View {
        background(SinfoniaNavigationControllerBridge())
            .modifier(SinfoniaEdgeSwipeBackModifier())
    }

    func sinfoniaBackNavigation() -> some View {
        modifier(SinfoniaBackButtonModifier())
    }
}
