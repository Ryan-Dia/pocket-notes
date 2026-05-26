import SwiftUI

struct DragHandle: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    Circle().frame(width: 3, height: 3)
                    Circle().frame(width: 3, height: 3)
                }
            }
        }
        .foregroundStyle(Color.secondary.opacity(0.5))
    }
}

struct FolderRenameRow: View {
    @EnvironmentObject var theme: ThemeStore
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 20))
                .foregroundStyle(theme.accent)
                .frame(width: 28)
            TextField("폴더 이름", text: $text)
                .onSubmit { onCommit() }
                .onExitCommand { onCancel() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
