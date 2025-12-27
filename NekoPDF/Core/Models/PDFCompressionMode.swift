enum PDFCompressionMode: String, CaseIterable, Identifiable {
    case lossless
    case ghostscript

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lossless:
            return "結構整理"
        case .ghostscript:
            return "外部壓縮"
        }
    }
}
