enum ImageFormat {
    case png
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        }
    }
}
