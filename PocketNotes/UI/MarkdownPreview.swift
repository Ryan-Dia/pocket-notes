import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let text: String
    let accentColor: Color
    var onTap: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        let tap = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        webView.addGestureRecognizer(tap)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onTap = onTap
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    // MARK: - HTML

    private var htmlContent: String {
        let accent = accentColor.toHexString()
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="color-scheme" content="light dark">
        <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            font-size: 14px;
            color: canvastext;
            background: transparent;
            padding: 10px 16px;
            line-height: 1.6;
            word-wrap: break-word;
        }
        h1 { font-size: 1.35em; font-weight: 700; margin: 10px 0 4px; }
        h2 { font-size: 1.15em; font-weight: 600; margin: 8px 0 4px; }
        h3 { font-size: 1.0em;  font-weight: 600; margin: 6px 0 2px; }
        p  { margin: 4px 0; }
        ul, ol { padding-left: 20px; margin: 4px 0; }
        li { margin: 2px 0; }
        code {
            font-family: 'SF Mono', Menlo, Consolas, monospace;
            font-size: 0.85em;
            background: rgba(128,128,128,0.15);
            padding: 1px 5px;
            border-radius: 3px;
        }
        pre {
            background: rgba(128,128,128,0.1);
            border: 1px solid rgba(128,128,128,0.2);
            border-radius: 6px;
            padding: 10px 12px;
            margin: 6px 0;
            overflow-x: auto;
        }
        pre code { background: none; padding: 0; }
        blockquote {
            border-left: 3px solid \(accent);
            padding-left: 12px;
            margin: 6px 0;
            opacity: 0.75;
        }
        hr  { border: none; border-top: 1px solid rgba(128,128,128,0.25); margin: 10px 0; }
        a   { color: \(accent); text-decoration: none; }
        a:hover { text-decoration: underline; }
        strong { font-weight: 600; }
        em     { font-style: italic; }
        del    { text-decoration: line-through; opacity: 0.7; }
        </style>
        </head>
        <body>\(parseMarkdown(text))</body>
        </html>
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var onTap: (() -> Void)?

        @objc func handleTap(_ gesture: NSClickGestureRecognizer) {
            onTap?()
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated,
               let url = action.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - Markdown → HTML

private func parseMarkdown(_ input: String) -> String {
    var output = ""
    let lines = input.components(separatedBy: "\n")
    var i = 0

    while i < lines.count {
        let line = lines[i]

        // Fenced code block
        if line.hasPrefix("```") {
            var codeLines: [String] = []
            i += 1
            while i < lines.count && !lines[i].hasPrefix("```") {
                codeLines.append(lines[i].htmlEscaped)
                i += 1
            }
            output += "<pre><code>\(codeLines.joined(separator: "\n"))</code></pre>\n"
            i += 1
            continue
        }

        // Headings
        if line.hasPrefix("### ") {
            output += "<h3>\(inlineMarkdown(String(line.dropFirst(4))))</h3>\n"
        } else if line.hasPrefix("## ") {
            output += "<h2>\(inlineMarkdown(String(line.dropFirst(3))))</h2>\n"
        } else if line.hasPrefix("# ") {
            output += "<h1>\(inlineMarkdown(String(line.dropFirst(2))))</h1>\n"
        }
        // Horizontal rule
        else if line == "---" || line == "***" || line == "___" {
            output += "<hr>\n"
        }
        // Blockquote
        else if line.hasPrefix("> ") {
            output += "<blockquote><p>\(inlineMarkdown(String(line.dropFirst(2))))</p></blockquote>\n"
        }
        // Unordered list — consecutive items
        else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            var items: [String] = []
            while i < lines.count,
                  lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ") || lines[i].hasPrefix("+ ") {
                items.append("<li>\(inlineMarkdown(String(lines[i].dropFirst(2))))</li>")
                i += 1
            }
            output += "<ul>\(items.joined())</ul>\n"
            continue
        }
        // Ordered list — consecutive items
        else if line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
            var items: [String] = []
            while i < lines.count,
                  lines[i].range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                let content = lines[i].replacingOccurrences(
                    of: #"^\d+\. "#, with: "", options: .regularExpression
                )
                items.append("<li>\(inlineMarkdown(content))</li>")
                i += 1
            }
            output += "<ol>\(items.joined())</ol>\n"
            continue
        }
        // Empty line
        else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            output += "<br>\n"
        }
        // Paragraph
        else {
            output += "<p>\(inlineMarkdown(line))</p>\n"
        }

        i += 1
    }
    return output
}

private func inlineMarkdown(_ text: String) -> String {
    var s = text.htmlEscaped
    // Inline code first (protect content from other patterns)
    s = s.replacingOccurrences(of: #"`([^`]+)`"#,
        with: "<code>$1</code>", options: .regularExpression)
    // Bold + italic
    s = s.replacingOccurrences(of: #"\*\*\*(.+?)\*\*\*"#,
        with: "<strong><em>$1</em></strong>", options: .regularExpression)
    // Bold
    s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#,
        with: "<strong>$1</strong>", options: .regularExpression)
    // Italic (* and _)
    s = s.replacingOccurrences(of: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#,
        with: "<em>$1</em>", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(?<!_)_([^_\n]+)_(?!_)"#,
        with: "<em>$1</em>", options: .regularExpression)
    // Strikethrough
    s = s.replacingOccurrences(of: #"~~(.+?)~~"#,
        with: "<del>$1</del>", options: .regularExpression)
    // Links [text](url)
    s = s.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#,
        with: "<a href=\"$2\">$1</a>", options: .regularExpression)
    return s
}

// MARK: - Extensions

extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&",  with: "&amp;")
            .replacingOccurrences(of: "<",  with: "&lt;")
            .replacingOccurrences(of: ">",  with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

extension Color {
    func toHexString() -> String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .systemBlue
        let r = Int((ns.redComponent   * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent  * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
