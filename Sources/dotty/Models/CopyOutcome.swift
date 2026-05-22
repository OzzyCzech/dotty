import Foundation

enum CopyOutcome {
    case copied
    case linked
    case skipped(reason: String)
    case failed(Error)
}
