enum PDFCompressionQuality: String, CaseIterable, Identifiable {
    case screen
    case ebook
    case printer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .screen:
            return "最小"
        case .ebook:
            return "平衡"
        case .printer:
            return "保真"
        }
    }

    var ghostscriptSetting: String {
        switch self {
        case .screen:
            return "/screen"
        case .ebook:
            return "/ebook"
        case .printer:
            return "/printer"
        }
    }
}
