import SwiftUI

@main
struct PocketNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene은 AppDelegate에서 직접 NSWindow로 관리
        Settings { EmptyView() }
    }
}
