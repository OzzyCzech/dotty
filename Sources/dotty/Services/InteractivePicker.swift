import Foundation

#if canImport(Darwin)
import Darwin
#endif

enum PickerRow {
    case header(String)
    case item(id: String, label: String, secondary: String)
}

enum InteractivePicker {
    static var isAvailable: Bool {
        isatty(fileno(stdin)) != 0 && isatty(fileno(stdout)) != 0
    }

    /// Returns selected IDs, or nil if the user cancelled.
    static func multiSelect(
        title: String,
        rows: [PickerRow],
        initiallySelected: Set<String>,
        helpFooter: String = "↑↓ move · space toggle · a all/none · enter confirm · q quit"
    ) -> [String]? {
        let itemIndices = rows.indices.filter {
            if case .item = rows[$0] { return true }
            return false
        }
        guard !itemIndices.isEmpty else { return [] }

        var selected = initiallySelected
        var cursor = itemIndices[0]

        return withRawMode {
            // Hide cursor; restore on exit.
            print("\u{001B}[?25l", terminator: "")
            defer { print("\u{001B}[?25h", terminator: "") }

            var firstDraw = true
            var renderedLines = 0
            while true {
                if !firstDraw {
                    // Move cursor up by renderedLines and clear from cursor to end of screen.
                    print("\u{001B}[\(renderedLines)A\r\u{001B}[J", terminator: "")
                }
                firstDraw = false
                renderedLines = render(title: title, rows: rows, selected: selected, cursor: cursor, helpFooter: helpFooter)
                fflush(stdout)

                let key = readKey()
                switch key {
                case .up:
                    if let prev = itemIndices.reversed().first(where: { $0 < cursor }) {
                        cursor = prev
                    } else if let last = itemIndices.last {
                        cursor = last
                    }
                case .down:
                    if let next = itemIndices.first(where: { $0 > cursor }) {
                        cursor = next
                    } else if let first = itemIndices.first {
                        cursor = first
                    }
                case .space:
                    if case .item(let id, _, _) = rows[cursor] {
                        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
                    }
                case .toggleAll:
                    let allIDs = itemIndices.compactMap { i -> String? in
                        if case .item(let id, _, _) = rows[i] { return id }
                        return nil
                    }
                    if selected.count == allIDs.count {
                        selected.removeAll()
                    } else {
                        selected = Set(allIDs)
                    }
                case .enter:
                    return itemIndices.compactMap { i -> String? in
                        if case .item(let id, _, _) = rows[i], selected.contains(id) { return id }
                        return nil
                    }
                case .quit:
                    return nil
                case .unknown:
                    continue
                }
            }
        }
    }

    private static func render(title: String, rows: [PickerRow], selected: Set<String>, cursor: Int, helpFooter: String) -> Int {
        var lines = 0
        print("\(Ansi.bold(title))\r")
        lines += 1
        print("\(Ansi.dim(helpFooter))\r")
        lines += 1
        print("\r")
        lines += 1
        for (i, row) in rows.enumerated() {
            switch row {
            case .header(let name):
                print("\(Ansi.bold(Ansi.underline(name)))\r")
            case .item(let id, let label, let secondary):
                let isSelected = selected.contains(id)
                let mark = isSelected ? Ansi.green("●") : Ansi.dim("○")
                let focus = (i == cursor) ? Ansi.cyan("▶") : " "
                let labelText = isSelected ? label : Ansi.dim(label)
                let secondaryText = Ansi.dim(secondary)
                print("  \(focus) \(mark) \(labelText)  \(secondaryText)\r")
            }
            lines += 1
        }
        return lines
    }

    // MARK: - Key handling

    private enum Key {
        case up, down, space, enter, quit, toggleAll, unknown
    }

    private static func readKey() -> Key {
        var byte: UInt8 = 0
        guard read(0, &byte, 1) == 1 else { return .quit }
        switch byte {
        case 0x1B:
            var next: UInt8 = 0
            guard read(0, &next, 1) == 1 else { return .quit }
            if next != 0x5B { return .quit }
            var arrow: UInt8 = 0
            guard read(0, &arrow, 1) == 1 else { return .unknown }
            switch arrow {
            case 0x41: return .up
            case 0x42: return .down
            default: return .unknown
            }
        case 0x0D, 0x0A:
            return .enter
        case 0x20:
            return .space
        case 0x61, 0x41:  // a / A
            return .toggleAll
        case 0x71, 0x51, 0x03:  // q / Q / Ctrl-C
            return .quit
        default:
            return .unknown
        }
    }

    // MARK: - Raw mode

    private static func withRawMode<T>(_ body: () -> T) -> T {
        var orig = termios()
        tcgetattr(0, &orig)
        var raw = orig
        cfmakeraw(&raw)
        raw.c_oflag |= tcflag_t(OPOST)
        tcsetattr(0, TCSANOW, &raw)
        defer { tcsetattr(0, TCSANOW, &orig) }
        return body()
    }
}
