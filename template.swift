import Cocoa

// Non-activating panel: never activates the app (e.g. Brave stays focused in the menu bar),
// and becomes key ONLY when the user explicitly clicks inside the editable text area.
class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return false }
}

class SharpBackgroundView: NSView {
    var headerHeight: CGFloat = 30 {
        didSet {
            if oldValue != headerHeight { needsDisplay = true }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Translucent neutral grey background with 100% sharp 90-degree corners
        let bg = NSColor(calibratedWhite: 0.10, alpha: 0.86)
        bg.setFill()
        let path = NSBezierPath(rect: bounds)
        path.fill()
        
        // 1px subtle neutral grey border
        let border = NSColor(calibratedWhite: 0.26, alpha: 0.55)
        border.setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        // Header separator line
        let sepY = bounds.height - headerHeight
        let sepPath = NSBezierPath()
        sepPath.move(to: NSPoint(x: 0, y: sepY))
        sepPath.line(to: NSPoint(x: bounds.width, y: sepY))
        let sepColor = NSColor(calibratedWhite: 0.22, alpha: 0.50)
        sepColor.setStroke()
        sepPath.lineWidth = 1.0
        sepPath.stroke()
    }
}

// Custom 100% monochrome, sharp-cornered opacity slider (no blue system accent)
class MonochromeOpacitySlider: NSView {
    var value: CGFloat = 1.0 {
        didSet { needsDisplay = true }
    }
    let minValue: CGFloat = 0.15
    let maxValue: CGFloat = 1.0
    var onChange: ((CGFloat) -> Void)?

    override var mouseDownCanMoveWindow: Bool { return false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let padX: CGFloat = 4
        let trackW = bounds.width - padX * 2
        guard trackW > 0 else { return }

        let midY = bounds.height / 2.0
        let trackRect = NSRect(x: padX, y: midY - 1.0, width: trackW, height: 2.0)

        // Background track
        NSColor(calibratedWhite: 0.28, alpha: 0.85).setFill()
        NSBezierPath(rect: trackRect).fill()

        // Active track
        let norm = max(0, min(1, (value - minValue) / (maxValue - minValue)))
        let fillRect = NSRect(x: padX, y: midY - 1.0, width: trackW * norm, height: 2.0)
        NSColor(calibratedWhite: 0.62, alpha: 0.90).setFill()
        NSBezierPath(rect: fillRect).fill()

        // Sharp rectangular thumb
        let thumbW: CGFloat = 5
        let thumbH: CGFloat = 11
        let thumbX = padX + trackW * norm - thumbW / 2.0
        let thumbRect = NSRect(x: thumbX, y: midY - thumbH / 2.0, width: thumbW, height: thumbH)
        NSColor(calibratedWhite: 0.88, alpha: 0.95).setFill()
        NSBezierPath(rect: thumbRect).fill()
    }

    private func updateValue(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let padX: CGFloat = 4
        let trackW = bounds.width - padX * 2
        guard trackW > 0 else { return }
        let norm = max(0, min(1, (loc.x - padX) / trackW))
        value = minValue + norm * (maxValue - minValue)
        onChange?(value)
    }

    override func mouseDown(with event: NSEvent) {
        updateValue(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateValue(with: event)
    }
}

// Custom 100% monochrome, sharp-cornered header button
class MonochromeHeaderButton: NSView {
    var title: String
    var isActive: Bool = false {
        didSet { needsDisplay = true }
    }
    var isBusy: Bool = false {
        didSet { needsDisplay = true }
    }
    var onClick: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { return false }

    init(frame: NSRect, title: String) {
        self.title = title
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)

        if isActive {
            NSColor(calibratedWhite: 0.84, alpha: 0.92).setFill()
            NSBezierPath(rect: rect).fill()
        } else {
            NSColor(calibratedWhite: 0.16, alpha: 0.85).setFill()
            NSBezierPath(rect: rect).fill()
            NSColor(calibratedWhite: 0.34, alpha: 0.70).setStroke()
            let p = NSBezierPath(rect: rect)
            p.lineWidth = 1.0
            p.stroke()
        }

        let textColor = isActive
            ? NSColor(calibratedWhite: 0.08, alpha: 1.0)
            : (isBusy ? NSColor(calibratedWhite: 0.92, alpha: 0.95) : NSColor(calibratedWhite: 0.66, alpha: 0.90))

        let label = isBusy ? "..." : title
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .bold),
            .foregroundColor: textColor
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        let pt = NSPoint(x: (bounds.width - size.width) / 2.0, y: (bounds.height - size.height) / 2.0)
        (label as NSString).draw(at: pt, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

// MARK: - External Antigravity CLI Client (gemini-4-hydrogen, medium effort)
enum AgyClient {
    static let binaryPaths = [
        "/opt/homebrew/bin/agy",
        "/usr/local/bin/agy"
    ]

    static func resolveBinary() -> String? {
        let fm = FileManager.default
        for p in binaryPaths where fm.isExecutableFile(atPath: p) {
            return p
        }
        return nil
    }

    static func askText(_ pastedText: String, completion: @escaping (String) -> Void) {
        let prompt = """
        Answer or respond to the following pasted content in the most concise way possible. Direct answer only, no filler, no preamble. If it is a multiple-choice or multiple-options question (or multiple questions), reply ONLY with the question number(s) and option letter(s)/number(s) (e.g. `1. B`, `2. A, C`, or `B`). If it is code or a command with an issue, give the fix concisely.

        ---
        \(pastedText)
        """
        runAgy(prompt: prompt, extraArgs: [], timeoutSec: 45, completion: completion)
    }

    static func askScreen(imagePath: String, completion: @escaping (String?) -> Void) {
        let prompt = """
        Inspect the screenshot image at \(imagePath). If there is a question, quiz, problem, error, or prompt to answer visible on screen, answer it in the most concise way possible (direct answer only, no filler, no preamble). If it is a multiple-choice or multiple-options question (or multiple questions), reply ONLY with the question number(s) and option letter(s)/number(s) (e.g. `1. B`, `2. A, C`, or `B`). If there is nothing to answer, reply with exactly: NO_ANSWER
        """
        let extra = ["--add-dir", "/tmp", "--dangerously-skip-permissions"]
        runAgy(prompt: prompt, extraArgs: extra, timeoutSec: 60) { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "NO_ANSWER" || trimmed.isEmpty {
                completion(nil)
            } else {
                completion(trimmed)
            }
        }
    }

    private static func runAgy(prompt: String, extraArgs: [String], timeoutSec: Int, completion: @escaping (String) -> Void) {
        guard let bin = resolveBinary() else {
            DispatchQueue.main.async {
                completion("[agy binary not found at /opt/homebrew/bin/agy]")
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: bin)
            var args = [
                "-p", prompt,
                "--model", "gemini-4-hydrogen",
                "--effort", "medium",
                "--disable-slash-commands",
                "--output-format", "text",
                "--print-timeout", "\(timeoutSec)s"
            ]
            args.append(contentsOf: extraArgs)
            proc.arguments = args

            var env = ProcessInfo.processInfo.environment
            let existingPath = env["PATH"] ?? "/usr/bin:/bin"
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + existingPath
            proc.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            proc.standardOutput = stdoutPipe
            proc.standardError = stderrPipe
            proc.standardInput = FileHandle.nullDevice

            let lock = NSLock()
            var outputData = Data()
            var errorData = Data()
            var authRequired = false

            let checkAuth: (Data) -> Void = { chunk in
                guard let s = String(data: chunk, encoding: .utf8) else { return }
                if s.contains("Authentication required") || s.contains("Please sign in") {
                    lock.lock()
                    authRequired = true
                    lock.unlock()
                    if proc.isRunning { proc.terminate() }
                }
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let d = handle.availableData
                if !d.isEmpty {
                    lock.lock()
                    outputData.append(d)
                    lock.unlock()
                    checkAuth(d)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let d = handle.availableData
                if !d.isEmpty {
                    lock.lock()
                    errorData.append(d)
                    lock.unlock()
                    checkAuth(d)
                }
            }

            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async {
                    completion("[agy error: \(error.localizedDescription)]")
                }
                return
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            lock.lock()
            let wasAuthRequired = authRequired
            let outStr = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errStr = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            lock.unlock()

            let finalResult: String
            if wasAuthRequired || outStr.contains("Authentication required") || errStr.contains("Please sign in") {
                finalResult = "[agy: sign in required — run 'agy' in Terminal once]"
            } else if !outStr.isEmpty {
                finalResult = outStr
            } else if !errStr.isEmpty {
                finalResult = "[agy: \(errStr)]"
            } else {
                finalResult = "[agy: empty response]"
            }

            DispatchQueue.main.async {
                completion(finalResult)
            }
        }
    }
}

// MARK: - Monochrome Markdown -> Nice Print Formatter
struct MarkdownTheme {
    static let bodyFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    static let boldFont = NSFont.systemFont(ofSize: 11, weight: .bold)
    static let italicFont: NSFont = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
    static let monoFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
    static let monoBoldFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
    static let h1Font = NSFont.systemFont(ofSize: 14, weight: .bold)
    static let h2Font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .bold)
    static let h3Font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)

    static let textBright = NSColor(calibratedWhite: 0.94, alpha: 0.98)
    static let textBody = NSColor(calibratedWhite: 0.78, alpha: 0.92)
    static let textMuted = NSColor(calibratedWhite: 0.62, alpha: 0.88)
    static let textSubtle = NSColor(calibratedWhite: 0.74, alpha: 0.90)
    static let codeBg = NSColor(calibratedWhite: 0.18, alpha: 0.85)

    static func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 2.5
        p.paragraphSpacing = 4
        return [
            .font: bodyFont,
            .foregroundColor: textBody,
            .paragraphStyle: p
        ]
    }
}

enum MarkdownFormatter {
    static func paragraphStyle(top: CGFloat = 0, bottom: CGFloat = 4, firstIndent: CGFloat = 0, headIndent: CGFloat = 0, lineSpacing: CGFloat = 2.5) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacingBefore = top
        p.paragraphSpacing = bottom
        p.firstLineHeadIndent = firstIndent
        p.headIndent = headIndent
        p.lineSpacing = lineSpacing
        return p
    }

    static func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var inCodeBlock = false
        var tableRowIndex = 0

        for (index, rawLine) in lines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let isLast = (index == lines.count - 1)
            let suffix = isLast ? "" : "\n"

            // Fenced code blocks ```
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }

            if inCodeBlock {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: MarkdownTheme.monoFont,
                    .foregroundColor: MarkdownTheme.textBright,
                    .backgroundColor: MarkdownTheme.codeBg,
                    .paragraphStyle: paragraphStyle(top: 1, bottom: 1, firstIndent: 14, headIndent: 14)
                ]
                result.append(NSAttributedString(string: rawLine + suffix, attributes: attrs))
                continue
            }

            // Horizontal rule --- or ***
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                    .foregroundColor: NSColor(calibratedWhite: 0.30, alpha: 0.70),
                    .paragraphStyle: paragraphStyle(top: 6, bottom: 6)
                ]
                result.append(NSAttributedString(string: "────────────────────────────────────────" + suffix, attributes: attrs))
                tableRowIndex = 0
                continue
            }

            // Markdown Table | col1 | col2 |
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 2 {
                let inner = String(trimmed.dropFirst().dropLast())
                let cells = inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }

                // Skip separator row | --- | --- |
                let isSeparator = cells.allSatisfy { cell in
                    let stripped = cell.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
                    return stripped.isEmpty
                }
                if isSeparator {
                    continue
                }

                if cells.count == 2 {
                    let c1 = cells[0]
                    let c2 = cells[1]
                    if tableRowIndex == 0 && (c1.lowercased() == "comandos" || c1.lowercased() == "comando") {
                        tableRowIndex += 1
                        continue
                    }
                    tableRowIndex += 1

                    let cmdText = stripInlineMarkers(c1)
                    let cmdAttrs: [NSAttributedString.Key: Any] = [
                        .font: MarkdownTheme.monoBoldFont,
                        .foregroundColor: MarkdownTheme.textBright,
                        .paragraphStyle: paragraphStyle(top: 3, bottom: 1, firstIndent: 12, headIndent: 12)
                    ]
                    result.append(NSAttributedString(string: cmdText + "\n", attributes: cmdAttrs))

                    let descAttr = renderInline(c2, baseFont: MarkdownTheme.bodyFont, baseColor: MarkdownTheme.textMuted, pStyle: paragraphStyle(top: 0, bottom: 5, firstIndent: 22, headIndent: 22))
                    result.append(descAttr)
                    if !isLast {
                        result.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.bodyFont]))
                    }
                    continue
                } else {
                    let joined = cells.joined(separator: "  ·  ")
                    let rowAttr = renderInline(joined, baseFont: MarkdownTheme.bodyFont, baseColor: MarkdownTheme.textBody, pStyle: paragraphStyle(top: 2, bottom: 2, firstIndent: 10, headIndent: 10))
                    result.append(rowAttr)
                    if !isLast {
                        result.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.bodyFont]))
                    }
                    continue
                }
            } else {
                tableRowIndex = 0
            }

            // Headings #, ##, ###
            if trimmed.hasPrefix("### ") {
                let content = String(trimmed.dropFirst(4))
                let attr = renderInline(content, baseFont: MarkdownTheme.h3Font, baseColor: MarkdownTheme.textSubtle, pStyle: paragraphStyle(top: 7, bottom: 3, firstIndent: 6, headIndent: 6))
                result.append(attr)
                if !isLast { result.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.h3Font])) }
                continue
            }
            if trimmed.hasPrefix("## ") {
                let content = String(trimmed.dropFirst(3))
                let attr = renderInline(content, baseFont: MarkdownTheme.h2Font, baseColor: MarkdownTheme.textBright, pStyle: paragraphStyle(top: 14, bottom: 5, firstIndent: 0, headIndent: 0))
                result.append(attr)
                if !isLast { result.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.h2Font])) }
                continue
            }
            if trimmed.hasPrefix("# ") {
                let content = String(trimmed.dropFirst(2))
                let attr = renderInline(content, baseFont: MarkdownTheme.h1Font, baseColor: MarkdownTheme.textBright, pStyle: paragraphStyle(top: 16, bottom: 6, firstIndent: 0, headIndent: 0))
                result.append(attr)
                if !isLast { result.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.h1Font])) }
                continue
            }

            // Blockquote > text
            if trimmed.hasPrefix("> ") {
                let content = String(trimmed.dropFirst(2))
                let attr = renderInline(content, baseFont: MarkdownTheme.monoBoldFont, baseColor: MarkdownTheme.textBright, pStyle: paragraphStyle(top: 3, bottom: 2, firstIndent: 14, headIndent: 14))
                result.append(attr)
                if !isLast { result.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.monoBoldFont])) }
                continue
            }

            // Bullet list - item or * item
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                let bulletP = paragraphStyle(top: 1, bottom: 3, firstIndent: 10, headIndent: 22)
                let bulletAttr = NSMutableAttributedString(string: "• ", attributes: [
                    .font: MarkdownTheme.boldFont,
                    .foregroundColor: MarkdownTheme.textSubtle,
                    .paragraphStyle: bulletP
                ])
                bulletAttr.append(renderInline(content, baseFont: MarkdownTheme.bodyFont, baseColor: MarkdownTheme.textBody, pStyle: bulletP))
                result.append(bulletAttr)
                if !isLast { result.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.bodyFont])) }
                continue
            }

            // Empty line
            if trimmed.isEmpty {
                result.append(NSAttributedString(string: suffix, attributes: MarkdownTheme.defaultTypingAttributes()))
                continue
            }

            // Regular paragraph with inline markdown
            let leadingSpaces = rawLine.prefix(while: { $0 == " " }).count
            let indent: CGFloat = leadingSpaces >= 2 ? 22 : 0
            let color = leadingSpaces >= 2 ? MarkdownTheme.textMuted : MarkdownTheme.textBody
            let attr = renderInline(trimmed, baseFont: MarkdownTheme.bodyFont, baseColor: color, pStyle: paragraphStyle(top: 0, bottom: 4, firstIndent: indent, headIndent: indent))
            result.append(attr)
            if !isLast { result.append(NSAttributedString(string: "\n", attributes: MarkdownTheme.defaultTypingAttributes())) }
        }

        return result
    }

    static func stripInlineMarkers(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "`", with: "")
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")
        return s
    }

    static func renderInline(_ text: String, baseFont: NSFont, baseColor: NSColor, pStyle: NSParagraphStyle) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: pStyle
        ]

        // Tokenize `code`, **bold**, *italic*
        let pattern = "(`[^`]+`|\\*\\*[^*]+\\*\\*|\\*[^*]+\\*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return NSAttributedString(string: text, attributes: baseAttrs)
        }

        let nsText = text as NSString
        var cursor = 0
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            if match.range.location > cursor {
                let plain = nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                out.append(NSAttributedString(string: plain, attributes: baseAttrs))
            }

            let token = nsText.substring(with: match.range)
            if token.hasPrefix("`") && token.hasSuffix("`") && token.count >= 2 {
                let inner = String(token.dropFirst().dropLast())
                var attrs = baseAttrs
                attrs[.font] = MarkdownTheme.monoFont
                attrs[.foregroundColor] = MarkdownTheme.textBright
                attrs[.backgroundColor] = MarkdownTheme.codeBg
                out.append(NSAttributedString(string: inner, attributes: attrs))
            } else if token.hasPrefix("**") && token.hasSuffix("**") && token.count >= 4 {
                let inner = String(token.dropFirst(2).dropLast(2))
                var attrs = baseAttrs
                attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                attrs[.foregroundColor] = MarkdownTheme.textBright
                out.append(NSAttributedString(string: inner, attributes: attrs))
            } else if token.hasPrefix("*") && token.hasSuffix("*") && token.count >= 2 {
                let inner = String(token.dropFirst().dropLast())
                var attrs = baseAttrs
                attrs[.font] = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                out.append(NSAttributedString(string: inner, attributes: attrs))
            } else {
                out.append(NSAttributedString(string: token, attributes: baseAttrs))
            }

            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            let tail = nsText.substring(from: cursor)
            out.append(NSAttributedString(string: tail, attributes: baseAttrs))
        }

        return out
    }
}

// MARK: - Editable TextView with Smart Markdown Paste & Live Formatting
private let pendingAIKey = NSAttributedString.Key("CoreAudioPendingAIID")

class MarkdownTextView: NSTextView {
    private var isApplyingFormat = false
    var pasteAIMode = false
    var onPasteAIRequest: ((String) -> Void)?
    var onTogglePasteAI: (() -> Void)?
    var onTriggerScreenCapture: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "v": paste(nil); return true
            case "c": copy(nil); return true
            case "x": cut(nil); return true
            case "a": selectAll(nil); return true
            case "z": undoManager?.undo(); return true
            default: break
            }
        } else if flags == [.command, .shift], let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "z": undoManager?.redo(); return true
            case "p": onTogglePasteAI?(); return true
            case "s": onTriggerScreenCapture?(); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string), !str.isEmpty {
            let rendered = MarkdownFormatter.render(str)
            let range = selectedRange()
            if shouldChangeText(in: range, replacementString: rendered.string) {
                textStorage?.replaceCharacters(in: range, with: rendered)
                didChangeText()
                setSelectedRange(NSRange(location: range.location + rendered.length, length: 0))
                typingAttributes = MarkdownTheme.defaultTypingAttributes()
            }
            if pasteAIMode {
                onPasteAIRequest?(str)
            }
            return
        }
        super.paste(sender)
    }

    func insertPendingAIBlock(label: String) -> String {
        let token = UUID().uuidString
        let loc = min(selectedRange().location, textStorage?.length ?? 0)
        let prefixNewline = (loc > 0 && ((textStorage?.string as NSString?)?.character(at: loc - 1) != 10)) ? "\n" : ""

        let block = NSMutableAttributedString()
        let diffAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor(calibratedWhite: 0.56, alpha: 0.85),
            .paragraphStyle: MarkdownFormatter.paragraphStyle(top: 4, bottom: 2, firstIndent: 4, headIndent: 4),
            pendingAIKey: token
        ]
        block.append(NSAttributedString(string: "\(prefixNewline)// ↳ \(label)\n", attributes: diffAttrs))

        let insertRange = NSRange(location: loc, length: 0)
        textStorage?.replaceCharacters(in: insertRange, with: block)
        didChangeText()
        setSelectedRange(NSRange(location: loc + block.length, length: 0))
        scrollRangeToVisible(NSRange(location: loc + block.length, length: 0))
        typingAttributes = MarkdownTheme.defaultTypingAttributes()
        return token
    }

    func resolvePendingAIBlock(id: String, answer: String?) {
        guard let storage = textStorage else { return }
        var foundRange = NSRange(location: NSNotFound, length: 0)
        storage.enumerateAttribute(pendingAIKey, in: NSRange(location: 0, length: storage.length), options: []) { val, range, stop in
            if let s = val as? String, s == id {
                foundRange = range
                stop.pointee = true
            }
        }
        guard foundRange.location != NSNotFound else { return }

        guard let answer = answer, !answer.isEmpty else {
            storage.replaceCharacters(in: foundRange, with: NSAttributedString(string: ""))
            didChangeText()
            return
        }

        let out = NSMutableAttributedString()
        let badgeParagraph = MarkdownFormatter.paragraphStyle(top: 6, bottom: 2, firstIndent: 4, headIndent: 4)
        let badgeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .bold),
            .foregroundColor: NSColor(calibratedWhite: 0.08, alpha: 1.0),
            .backgroundColor: NSColor(calibratedWhite: 0.84, alpha: 0.94),
            .paragraphStyle: badgeParagraph
        ]
        out.append(NSAttributedString(string: "\n", attributes: MarkdownTheme.defaultTypingAttributes()))
        out.append(NSAttributedString(string: " agent-response: ", attributes: badgeAttrs))
        out.append(NSAttributedString(string: "\n", attributes: [
            .font: MarkdownTheme.bodyFont,
            .paragraphStyle: badgeParagraph
        ]))

        let rendered = MarkdownFormatter.render(answer)
        let mutableRendered = NSMutableAttributedString(attributedString: rendered)
        mutableRendered.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: mutableRendered.length), options: []) { val, r, _ in
            let p = ((val as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            p.firstLineHeadIndent = max(p.firstLineHeadIndent, 8)
            p.headIndent = max(p.headIndent, 8)
            mutableRendered.addAttribute(.paragraphStyle, value: p, range: r)
        }
        out.append(mutableRendered)
        out.append(NSAttributedString(string: "\n", attributes: MarkdownTheme.defaultTypingAttributes()))

        storage.replaceCharacters(in: foundRange, with: out)
        didChangeText()
        let endLoc = foundRange.location + out.length
        setSelectedRange(NSRange(location: endLoc, length: 0))
        scrollRangeToVisible(NSRange(location: endLoc, length: 0))
        typingAttributes = MarkdownTheme.defaultTypingAttributes()
    }

    override func insertNewline(_ sender: Any?) {
        super.insertNewline(sender)
        typingAttributes = MarkdownTheme.defaultTypingAttributes()
    }

    func applyLiveMarkdownAtCursor() {
        guard !isApplyingFormat, let storage = textStorage else { return }
        let cursorLoc = selectedRange().location
        let fullStr = storage.string as NSString
        guard cursorLoc <= fullStr.length else { return }

        let lineRange = fullStr.lineRange(for: NSRange(location: max(0, cursorLoc - 1), length: 0))
        let lineText = fullStr.substring(with: lineRange)
        let cleanLine = lineText.replacingOccurrences(of: "\n", with: "")

        // 1. Live block prefix triggers (only when cursor is right after prefix)
        let blockTriggers: [(String, NSFont, NSColor, NSParagraphStyle, String)] = [
            ("### ", MarkdownTheme.h3Font, MarkdownTheme.textSubtle, MarkdownFormatter.paragraphStyle(top: 7, bottom: 3, firstIndent: 6, headIndent: 6), ""),
            ("## ", MarkdownTheme.h2Font, MarkdownTheme.textBright, MarkdownFormatter.paragraphStyle(top: 14, bottom: 5), ""),
            ("# ", MarkdownTheme.h1Font, MarkdownTheme.textBright, MarkdownFormatter.paragraphStyle(top: 16, bottom: 6), ""),
            ("> ", MarkdownTheme.monoBoldFont, MarkdownTheme.textBright, MarkdownFormatter.paragraphStyle(top: 3, bottom: 2, firstIndent: 14, headIndent: 14), ""),
            ("- ", MarkdownTheme.bodyFont, MarkdownTheme.textBody, MarkdownFormatter.paragraphStyle(top: 1, bottom: 3, firstIndent: 10, headIndent: 22), "• "),
            ("* ", MarkdownTheme.bodyFont, MarkdownTheme.textBody, MarkdownFormatter.paragraphStyle(top: 1, bottom: 3, firstIndent: 10, headIndent: 22), "• ")
        ]

        for (prefix, font, color, pStyle, replacement) in blockTriggers {
            if cleanLine == prefix && cursorLoc == lineRange.location + prefix.count {
                isApplyingFormat = true
                let prefixRange = NSRange(location: lineRange.location, length: prefix.count)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: pStyle
                ]
                if shouldChangeText(in: prefixRange, replacementString: replacement) {
                    storage.replaceCharacters(in: prefixRange, with: NSAttributedString(string: replacement, attributes: attrs))
                    didChangeText()
                    setSelectedRange(NSRange(location: lineRange.location + replacement.count, length: 0))
                    typingAttributes = attrs
                }
                isApplyingFormat = false
                return
            }
        }

        // 2. Live inline **bold** and `code` triggers on current line
        let lineBeforeCursorLen = cursorLoc - lineRange.location
        guard lineBeforeCursorLen >= 3 else { return }
        let beforeCursor = fullStr.substring(with: NSRange(location: lineRange.location, length: lineBeforeCursorLen))

        let inlinePatterns: [(String, Bool)] = [
            ("\\*\\*([^*]+)\\*\\*$", false),
            ("`([^`]+)`$", true)
        ]

        for (pattern, isCode) in inlinePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: beforeCursor, options: [], range: NSRange(location: 0, length: (beforeCursor as NSString).length)) {
                let inner = (beforeCursor as NSString).substring(with: match.range(at: 1))
                let replaceRange = NSRange(location: lineRange.location + match.range.location, length: match.range.length)

                var attrs = typingAttributes
                if isCode {
                    attrs[.font] = MarkdownTheme.monoFont
                    attrs[.foregroundColor] = MarkdownTheme.textBright
                    attrs[.backgroundColor] = MarkdownTheme.codeBg
                } else {
                    let curFont = (attrs[.font] as? NSFont) ?? MarkdownTheme.bodyFont
                    attrs[.font] = NSFontManager.shared.convert(curFont, toHaveTrait: .boldFontMask)
                    attrs[.foregroundColor] = MarkdownTheme.textBright
                }

                isApplyingFormat = true
                if shouldChangeText(in: replaceRange, replacementString: inner) {
                    storage.replaceCharacters(in: replaceRange, with: NSAttributedString(string: inner, attributes: attrs))
                    didChangeText()
                    setSelectedRange(NSRange(location: replaceRange.location + (inner as NSString).length, length: 0))
                    typingAttributes = MarkdownTheme.defaultTypingAttributes()
                }
                isApplyingFormat = false
                return
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate {
    var panel: OverlayPanel!
    var bgView: SharpBackgroundView!
    var headerLabel: NSTextField!
    var scrollView: NSScrollView!
    var textView: MarkdownTextView!
    var hintLabel: NSTextField!
    var opacitySlider: MonochromeOpacitySlider!
    var pasteModeButton: MonochromeHeaderButton!
    var screenCapButton: MonochromeHeaderButton!
    var pasteMenuItem: NSMenuItem?
    var autoWatchMenuItem: NSMenuItem?
    var autoWatchTimer: Timer?
    var isCapturingScreen = false
    var statusItem: NSStatusItem?
    var globalFlagsMonitor: Any?
    var localFlagsMonitor: Any?
    var optionDownAlone = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let defaultW: CGFloat = 780
        let defaultH: CGFloat = 480
        let defaultFrame = NSRect(
            x: screenRect.maxX - defaultW - 30,
            y: screenRect.maxY - defaultH - 30,
            width: defaultW,
            height: defaultH
        )
        let initialFrame = loadSavedPanelFrame() ?? defaultFrame
        let winW = initialFrame.width
        let winH = initialFrame.height
        let mask: NSWindow.StyleMask = [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable]

        panel = OverlayPanel(
            contentRect: initialFrame,
            styleMask: mask,
            backing: .buffered,
            defer: false
        )

        // Sharp corners & hidden titlebar
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 150, height: 150)
        panel.delegate = self

        // Invisible to all screen captures, CleanShot, Zoom, OBS
        panel.sharingType = .none

        bgView = SharpBackgroundView(frame: NSRect(x: 0, y: 0, width: winW, height: winH))
        bgView.autoresizingMask = [.width, .height]
        panel.contentView = bgView

        // Monochrome grey header
        headerLabel = NSTextField(labelWithString: "__HEADER_TITLE__")
        headerLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        headerLabel.textColor = NSColor(calibratedWhite: 0.72, alpha: 0.90)
        headerLabel.lineBreakMode = .byTruncatingTail
        headerLabel.sizeToFit()
        let titleW = min(headerLabel.frame.width, 160)
        headerLabel.frame = NSRect(x: 12, y: winH - 23, width: titleW, height: 16)
        headerLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        bgView.addSubview(headerLabel)

        // Monochrome opacity slider right next to the window title
        let savedOpacity = loadSavedOpacity()
        panel.alphaValue = savedOpacity
        let sliderX = headerLabel.frame.maxX + 10
        opacitySlider = MonochromeOpacitySlider(frame: NSRect(x: sliderX, y: winH - 23, width: 58, height: 16))
        opacitySlider.value = savedOpacity
        opacitySlider.autoresizingMask = [.maxXMargin, .minYMargin]
        opacitySlider.onChange = { [weak self] newAlpha in
            self?.panel.alphaValue = newAlpha
            self?.saveOpacity(newAlpha)
        }
        bgView.addSubview(opacitySlider)

        // Monochrome mode toggles: PASTE (auto-answer pastes) & OCR (stealth screen capture)
        let pasteX = opacitySlider.frame.maxX + 8
        pasteModeButton = MonochromeHeaderButton(frame: NSRect(x: pasteX, y: winH - 23, width: 46, height: 16), title: "PASTE")
        pasteModeButton.autoresizingMask = [.maxXMargin, .minYMargin]
        pasteModeButton.onClick = { [weak self] in
            self?.togglePasteAIMode()
        }
        bgView.addSubview(pasteModeButton)

        let scrX = pasteModeButton.frame.maxX + 5
        screenCapButton = MonochromeHeaderButton(frame: NSRect(x: scrX, y: winH - 23, width: 34, height: 16), title: "OCR")
        screenCapButton.autoresizingMask = [.maxXMargin, .minYMargin]
        screenCapButton.onClick = { [weak self] in
            self?.triggerStealthScreenCapture()
        }
        bgView.addSubview(screenCapButton)

        hintLabel = NSTextField(labelWithString: "[⌥: toggle]")
        hintLabel.frame = NSRect(x: winW - 140, y: winH - 23, width: 128, height: 16)
        hintLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        hintLabel.textColor = NSColor(calibratedWhite: 0.50, alpha: 0.85)
        hintLabel.alignment = .right
        hintLabel.autoresizingMask = [.minXMargin, .minYMargin]
        bgView.addSubview(hintLabel)

        // ScrollView + Editable MarkdownTextView
        let scrollRect = NSRect(x: 8, y: 8, width: winW - 16, height: winH - 40)
        scrollView = NSScrollView(frame: scrollRect)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let contentSize = scrollView.contentSize
        textView = MarkdownTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.insertionPointColor = NSColor(calibratedWhite: 0.88, alpha: 0.95)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = self
        textView.onTogglePasteAI = { [weak self] in
            self?.togglePasteAIMode()
        }
        textView.onTriggerScreenCapture = { [weak self] in
            self?.triggerStealthScreenCapture()
        }
        textView.onPasteAIRequest = { [weak self] pastedText in
            self?.handlePasteAI(pastedText)
        }

        let initialAttr = loadSavedNotes() ?? MarkdownFormatter.render(defaultCheatSheetMarkdown())
        textView.textStorage?.setAttributedString(initialAttr)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.sizeToFit()
        textView.typingAttributes = MarkdownTheme.defaultTypingAttributes()

        scrollView.documentView = textView
        bgView.addSubview(scrollView)

        registerOptionMonitor()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "//"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "__TOOLTIP__"
        }

        updateHeaderLayout()
        panel.orderFrontRegardless()
    }

    func textDidChange(_ notification: Notification) {
        textView.applyLiveMarkdownAtCursor()
        saveNotes()
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveNotes()
        savePanelFrame()
        saveOpacity(panel.alphaValue)
    }

    private let savedNotesKey = "SavedNotesRTF_v1"
    private let savedFrameKey = "SavedPanelFrame_v1"
    private let savedOpacityKey = "SavedOpacity_v1"

    func savePanelFrame() {
        guard panel != nil else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: savedFrameKey)
    }

    func loadSavedPanelFrame() -> NSRect? {
        guard let str = UserDefaults.standard.string(forKey: savedFrameKey) else { return nil }
        let rect = NSRectFromString(str)
        guard rect.width >= 150, rect.height >= 150 else { return nil }
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
        return onScreen ? rect : nil
    }

    func saveOpacity(_ alpha: CGFloat) {
        UserDefaults.standard.set(Double(alpha), forKey: savedOpacityKey)
    }

    func loadSavedOpacity() -> CGFloat {
        guard UserDefaults.standard.object(forKey: savedOpacityKey) != nil else { return 1.0 }
        let val = CGFloat(UserDefaults.standard.double(forKey: savedOpacityKey))
        return max(0.15, min(1.0, val))
    }

    func updateHeaderLayout() {
        let wPanel = panel.frame.width
        let hPanel = panel.frame.height
        let isCompact = wPanel < 275

        bgView.headerHeight = isCompact ? 52 : 30
        hintLabel.isHidden = wPanel < 360
        opacitySlider.isHidden = false
        pasteModeButton.isHidden = false
        screenCapButton.isHidden = false

        let titleW = min(headerLabel.frame.width, 160)
        if isCompact {
            headerLabel.frame = NSRect(x: 10, y: hPanel - 23, width: titleW, height: 16)
            let sliderX = headerLabel.frame.maxX + 8
            let sliderW = max(36, min(58, wPanel - sliderX - 10))
            opacitySlider.frame = NSRect(x: sliderX, y: hPanel - 23, width: sliderW, height: 16)

            let btnW = max(44, floor((wPanel - 26) / 2.0))
            pasteModeButton.frame = NSRect(x: 10, y: hPanel - 45, width: btnW, height: 16)
            screenCapButton.frame = NSRect(x: 10 + btnW + 6, y: hPanel - 45, width: btnW, height: 16)

            scrollView.frame = NSRect(x: 8, y: 8, width: wPanel - 16, height: max(40, hPanel - 60))
        } else {
            headerLabel.frame = NSRect(x: 12, y: hPanel - 23, width: titleW, height: 16)
            let sliderX = headerLabel.frame.maxX + 10
            opacitySlider.frame = NSRect(x: sliderX, y: hPanel - 23, width: 58, height: 16)

            let pasteX = opacitySlider.frame.maxX + 8
            pasteModeButton.frame = NSRect(x: pasteX, y: hPanel - 23, width: 46, height: 16)

            let ocrX = pasteModeButton.frame.maxX + 5
            screenCapButton.frame = NSRect(x: ocrX, y: hPanel - 23, width: 34, height: 16)

            hintLabel.frame = NSRect(x: wPanel - 140, y: hPanel - 23, width: 128, height: 16)
            scrollView.frame = NSRect(x: 8, y: 8, width: wPanel - 16, height: max(40, hPanel - 40))
        }
    }

    func windowDidMove(_ notification: Notification) {
        savePanelFrame()
    }

    func saveNotes() {
        guard let storage = textView?.textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        if let data = try? storage.data(from: fullRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            UserDefaults.standard.set(data, forKey: savedNotesKey)
        }
    }

    func loadSavedNotes() -> NSAttributedString? {
        guard let data = UserDefaults.standard.data(forKey: savedNotesKey),
              let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else {
            return nil
        }
        return attr
    }

    func registerOptionMonitor() {
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
        }

        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.processEvent(event)
            }
        }

        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.processEvent(event)
            return event
        }
    }

    func processEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            optionDownAlone = false
            return
        }
        if event.type == .flagsChanged {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .option {
                optionDownAlone = true
            } else if flags.isEmpty && optionDownAlone {
                optionDownAlone = false
                toggleVisibility()
            } else {
                optionDownAlone = false
            }
        }
    }

    func windowDidResize(_ notification: Notification) {
        updateHeaderLayout()
        savePanelFrame()

        let w = scrollView.contentSize.width
        textView.textContainer?.containerSize = NSSize(width: w, height: CGFloat.greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.sizeToFit()
    }

    @objc func statusItemClicked() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Toggle (⌥)", action: #selector(toggleFromMenu), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())

            let pasteItem = NSMenuItem(title: "Paste AI Mode (⌘⇧P)", action: #selector(togglePasteAIMode), keyEquivalent: "")
            pasteItem.state = textView.pasteAIMode ? .on : .off
            menu.addItem(pasteItem)

            menu.addItem(NSMenuItem(title: "Stealth Screen Capture (⌘⇧S)", action: #selector(triggerStealthScreenCapture), keyEquivalent: ""))

            let watchItem = NSMenuItem(title: "Auto Screen Watch (12s)", action: #selector(toggleAutoScreenWatch), keyEquivalent: "")
            watchItem.state = (autoWatchTimer != nil) ? .on : .off
            menu.addItem(watchItem)

            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            toggleVisibility()
        }
    }

    @objc func togglePasteAIMode() {
        textView.pasteAIMode.toggle()
        pasteModeButton.isActive = textView.pasteAIMode
    }

    @objc func toggleAutoScreenWatch() {
        if let timer = autoWatchTimer {
            timer.invalidate()
            autoWatchTimer = nil
        } else {
            performStealthScreenCapture(silentIfEmpty: false)
            autoWatchTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { [weak self] _ in
                self?.performStealthScreenCapture(silentIfEmpty: true)
            }
        }
    }

    func handlePasteAI(_ pastedText: String) {
        let token = textView.insertPendingAIBlock(label: "thinking…")
        AgyClient.askText(pastedText) { [weak self] answer in
            self?.textView.resolvePendingAIBlock(id: token, answer: answer)
        }
    }

    @objc func triggerStealthScreenCapture() {
        performStealthScreenCapture(silentIfEmpty: false)
    }

    func performStealthScreenCapture(silentIfEmpty: Bool) {
        guard !isCapturingScreen else { return }
        isCapturingScreen = true
        screenCapButton.isBusy = true

        let tmpPath = "/tmp/ca_scr_\(UUID().uuidString).png"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cap = Process()
            if geteuid() == 0 {
                // Delegate capture through LaunchServices as the console user so TCC
                // attributes Screen Recording to coreaudio.app instead of "sudo".
                let consoleUID = ProcessInfo.processInfo.environment["SUDO_UID"] ?? "501"
                let appURL = Bundle.main.bundleURL.path.hasSuffix(".app")
                    ? Bundle.main.bundleURL.path
                    : "/Applications/coreaudio.app"
                cap.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                cap.arguments = ["asuser", consoleUID, "/usr/bin/open", "-g", "-n", "-W", appURL, "--args", "--capture", tmpPath]
            } else {
                cap.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                cap.arguments = ["-x", "-t", "png", tmpPath]
            }
            cap.standardOutput = FileHandle.nullDevice
            cap.standardError = FileHandle.nullDevice

            do {
                try cap.run()
                cap.waitUntilExit()
            } catch {
                DispatchQueue.main.async {
                    self?.isCapturingScreen = false
                    self?.screenCapButton.isBusy = false
                }
                return
            }

            guard cap.terminationStatus == 0, FileManager.default.fileExists(atPath: tmpPath) else {
                DispatchQueue.main.async {
                    self?.isCapturingScreen = false
                    self?.screenCapButton.isBusy = false
                }
                return
            }

            var pendingToken: String?
            if !silentIfEmpty {
                DispatchQueue.main.sync {
                    pendingToken = self?.textView.insertPendingAIBlock(label: "scanning screen…")
                }
            }

            AgyClient.askScreen(imagePath: tmpPath) { [weak self] answer in
                try? FileManager.default.removeItem(atPath: tmpPath)
                self?.isCapturingScreen = false
                self?.screenCapButton.isBusy = false

                if let token = pendingToken {
                    self?.textView.resolvePendingAIBlock(id: token, answer: answer)
                } else if let answer = answer {
                    let token = self?.textView.insertPendingAIBlock(label: "screen")
                    if let t = token {
                        self?.textView.resolvePendingAIBlock(id: t, answer: answer)
                    }
                }
            }
        }
    }

    @objc func toggleFromMenu() {
        toggleVisibility()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func toggleVisibility() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }
}

func defaultCheatSheetMarkdown() -> String {
    return """
## 1. GESTION DE USUARIOS Y GRUPOS LOCALES
### WINDOWS
> net user ana Clave123 /add
  Crea un usuario nuevo. Si pones * en lugar de la contraseña, te la pide oculta al escribir.
> net localgroup <grupo> <usuario> /add
  Mete a un usuario dentro de un grupo (ej. Administradores). Con /delete lo saca.
> net localgroup <grupo> /add
  Crea un grupo local nuevo para asignar permisos en bloque.
### UBUNTU
> sudo adduser ana  /  sudo useradd -m -s /bin/bash ana
  Crean usuarios. adduser es guiado; useradd es manual (sin -m no crea /home).
> sudo usermod -aG <grupo> ana
  Añade usuario a grupo sin sacarlo de los anteriores (sin -a borra todos sus grupos).
> sudo groupadd <grupo>  /  sudo gpasswd -d ana <grupo>
  Crea un grupo nuevo  /  saca a un usuario de un grupo concreto.
> id ana  /  getent group <grupo>
  Muestra UID y grupos del usuario  /  lista quién pertenece a un grupo.

## 2. POLITICAS DE CONTRASENAS, BLOQUEO Y CADUCIDAD
### WINDOWS
> net user ana /logonpasswordchg:yes
  Obliga al usuario a cambiar su contraseña provisional en el primer inicio de sesión.
> net user ana /active:no
  Deshabilita la cuenta (impide entrar, conserva archivos). Con /active:yes la reactivas.
> net user ana /delete
  Elimina la cuenta de usuario de forma definitiva.
> net accounts /minpwlen:12 /maxpwage:90 /minpwage:1 /uniquepw:5
  Reglas de passwords: mín 12 car., caduca 90d, mín 1d, recuerda 5 (funciona en Home).
> net accounts /lockoutthreshold:5 /lockoutduration:15 /lockoutwindow:15
  Bloquea cuenta 15 min si alguien falla la contraseña 5 veces seguidas.
### UBUNTU
> sudo passwd -e ana  (o  sudo chage -d 0 ana)
  Obliga al usuario a cambiar su contraseña la próxima vez que inicie sesión.
> sudo chage -M 90 -m 1 -W 7 ana
  Caducidad de cuenta: caduca a los 90d, mín 1d para cambiar, avisa 7d antes (-l lista).
> sudo usermod -L ana  (y  -U)
  Bloquea (-L) o desbloquea (-U) una cuenta para impedir acceso sin borrar archivos.
> sudo userdel -r ana
  Elimina el usuario y borra también su carpeta personal (/home/ana).
> sudo faillock --user ana --reset
  Desbloquea una cuenta bloqueada tras fallar demasiadas veces la contraseña.

## 3. PRIVILEGIOS Y ELEVACION
### WINDOWS
> whoami /groups  y  whoami /priv
  Muestra a qué grupos perteneces y qué privilegios de seguridad tienes activos.
> runas /user:admin cmd
  Abre un programa ejecutándolo con permisos de otro usuario.
### UBUNTU
> sudo visudo
  Abre /etc/sudoers de forma segura para gestionar sudo (valida sintaxis antes de guardar).

## 4. RED, DNS Y CONECTIVIDAD
### WINDOWS
> ipconfig /all
  Toda la configuración de red: IP, máscara, puerta de enlace, DNS y MAC.
> ipconfig /flushdns
  Borra caché DNS local (si cambiaste hosts o web cambió de IP). /displaydns ve guardado.
> ipconfig /release  y  ipconfig /renew
  Suelta la IP asignada por DHCP y pide una nueva.
> New-NetIPAddress  y  Set-DnsClientServerAddress
  PowerShell para configurar IP estática, máscara (/24), gateway y DNS.
> nslookup <dominio>
  Pregunta directamente al DNS cuál es la IP de un dominio (ignora hosts).
> Test-NetConnection <web> -Port 443
  Comprueba en PowerShell si un puerto está abierto (cuando bloquean ping).
> tracert <destino>
  Muestra todos los routers por los que pasa tu conexión hasta destino.
> netstat -ano
  Lista los puertos abiertos en tu equipo y el PID del programa que los usa.
> Set-NetConnectionProfile -InterfaceAlias Wi-Fi -NetworkCategory Public
  Cambia perfil a Público (firewall estricto, obligatorio en wifis públicas).
### UBUNTU
> ip -br a  y  ip r
  ip -br a muestra interfaces e IPs resumidas; ip r enseña la puerta de enlace (router).
> sudo netplan try  y  sudo netplan apply
  Prueban y aplican la red fija de /etc/netplan/*.yaml. try revierte si te quedas sin red.
> ping -c 3 <destino>
  Envía 3 paquetes de prueba de conectividad (en Linux sin -c sigue sin parar).
> dig <dominio> +short  y  nslookup <dominio>
  Preguntan directamente al DNS (ignoran /etc/hosts). Con dig -x <IP> hace inversa.
> resolvectl status  y  sudo resolvectl flush-caches
  Muestra servidores DNS en uso y vacía la caché DNS local.
> ss -tulpn
  Enseña qué puertos están escuchando en tu máquina y qué proceso los tiene abiertos.
> curl -I <url>
  Comprueba si una web responde leyendo cabeceras HTTP/HTTPS (aunque bloquee ping).
> tracepath <destino>
  Muestra los saltos de routers por los que viajan tus paquetes hasta llegar a destino.
> sudo ufw default deny incoming  y  sudo ufw enable
  Bloquea por defecto las conexiones entrantes y activa el cortafuegos.

## 5. SERVICIOS DEL SISTEMA
### WINDOWS
> Get-Service  /  Start-Service  /  Stop-Service
  Consulta estado de servicio, lo arranca o lo detiene en PowerShell.
> Set-Service <servicio> -StartupType Manual
  Cambia modo inicio de servicio (Automático, Manual o Deshabilitado).
> sc.exe query  y  sc.exe qc <servicio>
  Mira estado y dependencias de servicio en CMD (.exe obligatorio en PowerShell).
### UBUNTU
> systemctl status <servicio>  /  start  /  stop
  Consulta si servicio está activo/falló, lo arranca ahora o lo detiene ahora.
> sudo systemctl enable --now <servicio>  /  disable
  Configura inicio automático con sistema (enable/disable). --now arranca en el acto.
> journalctl -u <servicio> -n 20
  Muestra últimas 20 líneas del log de un servicio para diagnosticar fallos.

## 6. PROCESOS, PRIORIDADES Y CONTROL
### WINDOWS
> tasklist  /  Get-Process
  Lista procesos en ejecución y su identificador numérico (PID).
> taskkill /PID <num>  (y  /F)
  Pide a proceso cerrar bien. Con /F lo mata de golpe sin guardar cambios.
> start /low <programa>
  Arranca programa con prioridad baja para no ralentizar el equipo.
### UBUNTU
> ps aux  /  top  /  pgrep -a <nombre>
  Lista procesos activos, monitor en tiempo real o busca PID por su nombre.
> nice -n 10 <cmd>  y  renice -n 15 -p <PID>
  Cambian prioridad de CPU (-20 máx a 19 mín; solo root puede subir prioridad).
> kill <PID>  y  kill -9 <PID>
  kill pide al proceso cerrar bien; kill -9 lo fuerza de golpe.

## 7. VARIABLES, RUTAS, SEGURIDAD Y ENERGIA
### WINDOWS
> setx <VAR> "<valor>"
  Guarda variable permanente de usuario (/M para todos; requiere nueva terminal).
> where <comando>
  Muestra ruta exacta en %PATH% donde Windows encuentra el ejecutable.
> manage-bde -status  y  powercfg /list
  Comprueba cifrado BitLocker; lista planes de ahorro de energía.
### UBUNTU
> export VAR=valor  y  source ~/.bashrc
  Crea variable temporal en la terminal / recarga ~/.bashrc para cambios permanentes.
> which <comando>
  Indica la ruta exacta del ejecutable que se lanza al escribir ese comando.
> gpg -c <archivo>  /  rsync -av <origen> <destino>
  Cifra un archivo suelto con contraseña / sincroniza carpetas para backups.
> powerprofilesctl list  (y  set)
  Muestra y cambia los perfiles de consumo de energía y batería.
"""
}

if CommandLine.arguments.count >= 3 && CommandLine.arguments[1] == "--capture" {
    let outPath = CommandLine.arguments[2]
    let cap = Process()
    cap.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    cap.arguments = ["-x", "-t", "png", outPath]
    cap.standardOutput = FileHandle.nullDevice
    cap.standardError = FileHandle.nullDevice
    try? cap.run()
    cap.waitUntilExit()
    exit(cap.terminationStatus)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
