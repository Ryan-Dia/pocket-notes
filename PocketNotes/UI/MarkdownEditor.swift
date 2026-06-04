import SwiftUI
import AppKit

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let accentColor: Color
    var onFocusChange: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? NSTextView else { return scrollView }
        tv.delegate = context.coordinator
        tv.isRichText = true
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 4, height: 8)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.string = text
        applyStyles(to: tv.textStorage!, cursorAt: 0)
        tv.typingAttributes = baseAttributes
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scrollView.documentView as? NSTextView else { return }
        guard tv.string != text else { return }
        let sel = tv.selectedRanges
        tv.string = text
        tv.selectedRanges = sel
        let cursor = tv.selectedRange().location
        applyStyles(to: tv.textStorage!, cursorAt: cursor)
    }

    // MARK: - Base

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: 14),
         .foregroundColor: NSColor.labelColor]
    }

    // MARK: - Style Engine

    func applyStyles(to storage: NSTextStorage, cursorAt cursor: Int) {
        guard storage.length > 0 else { return }
        let str = storage.string as NSString
        let full = NSRange(location: 0, length: storage.length)

        storage.beginEditing()
        storage.setAttributes(baseAttributes, range: full)

        // Block styles — line by line
        var pos = 0
        while pos < storage.length {
            var lineEnd = pos, contentsEnd = pos
            str.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd,
                             for: NSRange(location: pos, length: 0))
            let lineRange  = NSRange(location: pos, length: lineEnd - pos)
            let onThisLine = cursor >= pos && cursor <= lineEnd

            let contentStr = str.substring(with: NSRange(location: pos, length: contentsEnd - pos))

            if contentStr.hasPrefix("# "), contentStr.count > 2 {
                storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 22), range: lineRange)
                let mr = NSRange(location: pos, length: 2)
                onThisLine ? dim(storage, mr) : hide(storage, mr)

            } else if contentStr.hasPrefix("## "), contentStr.count > 3 {
                storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 18), range: lineRange)
                let mr = NSRange(location: pos, length: 3)
                onThisLine ? dim(storage, mr) : hide(storage, mr)

            } else if contentStr.hasPrefix("### "), contentStr.count > 4 {
                storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 15), range: lineRange)
                let mr = NSRange(location: pos, length: 4)
                onThisLine ? dim(storage, mr) : hide(storage, mr)

            } else if contentStr.hasPrefix("> "), contentStr.count > 2 {
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: lineRange)
                let mr = NSRange(location: pos, length: 2)
                onThisLine ? dim(storage, mr) : hide(storage, mr)
            }

            pos = lineEnd
        }

        // Inline styles
        inline(#"\*\*\*(.+?)\*\*\*"#, str, storage, cursor) { c, ms, onLine in
            let f = font(storage, c)
            storage.addAttribute(.font, value: boldItalic(f), range: c)
            ms.forEach { onLine ? dim(storage, $0) : hide(storage, $0) }
        }
        inline(#"\*\*(.+?)\*\*"#, str, storage, cursor) { c, ms, onLine in
            let f = font(storage, c)
            storage.addAttribute(.font, value: NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask), range: c)
            ms.forEach { onLine ? dim(storage, $0) : hide(storage, $0) }
        }
        inline(#"(?<!\*)\*([^*\n]+)\*(?!\*)"#, str, storage, cursor) { c, ms, onLine in
            let f = font(storage, c)
            storage.addAttribute(.font, value: NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask), range: c)
            ms.forEach { onLine ? dim(storage, $0) : hide(storage, $0) }
        }
        inline(#"(?<!_)_([^_\n]+)_(?!_)"#, str, storage, cursor) { c, ms, onLine in
            let f = font(storage, c)
            storage.addAttribute(.font, value: NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask), range: c)
            ms.forEach { onLine ? dim(storage, $0) : hide(storage, $0) }
        }
        inline(#"`([^`\n]+)`"#, str, storage, cursor) { c, ms, onLine in
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: c)
            storage.addAttribute(.backgroundColor, value: NSColor.tertiarySystemFill, range: c)
            ms.forEach { onLine ? dim(storage, $0) : hide(storage, $0) }
        }
        inline(#"~~(.+?)~~"#, str, storage, cursor) { c, ms, onLine in
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: c)
            ms.forEach { onLine ? dim(storage, $0) : hide(storage, $0) }
        }

        storage.endEditing()
    }

    // MARK: - Helpers

    private func dim(_ s: NSTextStorage, _ r: NSRange) {
        guard r.length > 0 else { return }
        s.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: r)
    }

    private func hide(_ s: NSTextStorage, _ r: NSRange) {
        guard r.length > 0 else { return }
        s.addAttribute(.foregroundColor, value: NSColor.clear, range: r)
        s.addAttribute(.font, value: NSFont.systemFont(ofSize: 0.1), range: r)
    }

    private func font(_ s: NSTextStorage, _ r: NSRange) -> NSFont {
        (s.attribute(.font, at: max(0, r.location), effectiveRange: nil) as? NSFont)
            ?? NSFont.systemFont(ofSize: 14)
    }

    private func boldItalic(_ f: NSFont) -> NSFont {
        let b = NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask)
        return NSFontManager.shared.convert(b, toHaveTrait: .italicFontMask)
    }

    private func inline(_ pattern: String, _ str: NSString, _ storage: NSTextStorage,
                        _ cursor: Int,
                        _ apply: (NSRange, [NSRange], Bool) -> Void) {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return }
        for m in re.matches(in: str as String, range: NSRange(location: 0, length: str.length)) {
            let whole = m.range(at: 0), content = m.range(at: 1)
            guard content.location != NSNotFound, content.length > 0 else { continue }

            // Check if cursor is on the same line as this match
            var lineStart = whole.location, lineEnd = whole.location
            str.getLineStart(&lineStart, end: &lineEnd, contentsEnd: nil,
                             for: NSRange(location: whole.location, length: 0))
            let onLine = cursor >= lineStart && cursor <= lineEnd

            let lead = content.location - whole.location
            let trail = whole.length - lead - content.length
            var markers: [NSRange] = []
            if lead > 0  { markers.append(NSRange(location: whole.location, length: lead)) }
            if trail > 0 { markers.append(NSRange(location: content.location + content.length, length: trail)) }
            apply(content, markers, onLine)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor

        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) { parent.onFocusChange?(true) }
        func textDidEndEditing(_ notification: Notification)   { parent.onFocusChange?(false) }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let cursor = tv.selectedRange().location
            parent.text = tv.string
            parent.applyStyles(to: tv.textStorage!, cursorAt: cursor)
            tv.typingAttributes = parent.baseAttributes
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let cursor = tv.selectedRange().location
            parent.applyStyles(to: tv.textStorage!, cursorAt: cursor)
        }
    }
}
