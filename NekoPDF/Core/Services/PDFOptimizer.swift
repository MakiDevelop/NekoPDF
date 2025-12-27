import Foundation
import CoreGraphics

enum PDFOptimizeError: Error, LocalizedError {
    case fileNotFound
    case invalidPDF
    case noPages
    case outputDirectoryNotFound
    case outputFileExists
    case pdfWriteFailed
    case ghostscriptNotFound
    case ghostscriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "無法讀取 PDF 檔案"
        case .invalidPDF:
            return "PDF 檔案損毀或格式錯誤"
        case .noPages:
            return "PDF 沒有任何頁面"
        case .outputDirectoryNotFound:
            return "輸出目錄不存在"
        case .outputFileExists:
            return "輸出檔案已存在"
        case .pdfWriteFailed:
            return "PDF 壓縮失敗"
        case .ghostscriptNotFound:
            return "找不到 Ghostscript（gs），請先安裝或改用結構整理"
        case .ghostscriptFailed(let detail):
            if detail.isEmpty {
                return "Ghostscript 壓縮失敗"
            }
            return "Ghostscript 壓縮失敗：\(detail)"
        }
    }
}

final class PDFOptimizer: PDFOptimizing, @unchecked Sendable {

    func optimize(
        pdfURL: URL,
        to outputURL: URL,
        mode: PDFCompressionMode,
        quality: PDFCompressionQuality
    ) throws {
        switch mode {
        case .lossless:
            try optimizeLossless(pdfURL: pdfURL, to: outputURL)
        case .ghostscript:
            try optimizeWithGhostscript(pdfURL: pdfURL, to: outputURL, quality: quality)
        }
    }

    private func optimizeLossless(pdfURL: URL, to outputURL: URL) throws {
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw PDFOptimizeError.fileNotFound
        }

        guard let source = CGPDFDocument(pdfURL as CFURL) else {
            throw PDFOptimizeError.invalidPDF
        }

        guard source.numberOfPages > 0 else {
            throw PDFOptimizeError.noPages
        }

        let outputDirectory = outputURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: outputDirectory.path) else {
            throw PDFOptimizeError.outputDirectoryNotFound
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            throw PDFOptimizeError.outputFileExists
        }

        var firstBox = source.page(at: 1)?.getBoxRect(.mediaBox) ?? .zero
        guard let context = CGContext(outputURL as CFURL, mediaBox: &firstBox, nil) else {
            throw PDFOptimizeError.pdfWriteFailed
        }

        do {
            for index in 1...source.numberOfPages {
                guard let page = source.page(at: index) else {
                    throw PDFOptimizeError.pdfWriteFailed
                }

                let mediaBox = page.getBoxRect(.mediaBox)
                let pageInfo = [kCGPDFContextMediaBox as String: mediaBox] as CFDictionary
                context.beginPDFPage(pageInfo)
                context.drawPDFPage(page)
                context.endPDFPage()
            }

            context.closePDF()
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private func optimizeWithGhostscript(
        pdfURL: URL,
        to outputURL: URL,
        quality: PDFCompressionQuality
    ) throws {
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw PDFOptimizeError.fileNotFound
        }

        let outputDirectory = outputURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: outputDirectory.path) else {
            throw PDFOptimizeError.outputDirectoryNotFound
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            throw PDFOptimizeError.outputFileExists
        }

        guard let gsPath = findGhostscriptPath() else {
            throw PDFOptimizeError.ghostscriptNotFound
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NekoPDF-GS-\(UUID().uuidString)", isDirectory: true)
        let tempInput = tempDirectory.appendingPathComponent("input.pdf")
        let tempOutput = tempDirectory.appendingPathComponent("output.pdf")
        let logURL = tempDirectory.appendingPathComponent("ghostscript.log")

        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: pdfURL, to: tempInput)

        let gsResources = findGhostscriptResourcePaths(gsPath: gsPath)
        var args: [String] = []
        if let gsResources {
            args.append("-I")
            args.append(gsResources.libraryPathList)
        }
        args += [
            "-sDEVICE=pdfwrite",
            "-dCompatibilityLevel=1.7",
            "-dPDFSETTINGS=\(quality.ghostscriptSetting)",
            "-dNOPAUSE",
            "-dBATCH",
            "-dSAFER",
            "-dPDFSTOPONERROR",
            "-dVerbose",
            "-dDetectDuplicateImages=true",
            "-dCompressFonts=true",
            "-sOutputFile=\(tempOutput.lastPathComponent)",
            tempInput.lastPathComponent
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: gsPath)
        process.arguments = args
        if let gsResources = gsResources {
            var environment = ProcessInfo.processInfo.environment
            environment["GS_LIB"] = gsResources.libraryPathList
            if let fontPath = gsResources.fontPath {
                environment["GS_FONTPATH"] = fontPath
            }
            if let iccPath = gsResources.iccPath {
                environment["GS_ICC_PROFILE_DIR"] = iccPath
            }
            environment["TMPDIR"] = tempDirectory.path
            process.environment = environment
        }
        process.currentDirectoryURL = tempDirectory
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            let detail = error.localizedDescription
            throw PDFOptimizeError.ghostscriptFailed(detail)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdoutText = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
        let combinedText = [stderrText, stdoutText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
        let logText = [stderrText, stdoutText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        if !logText.isEmpty {
            try? logText.write(to: logURL, atomically: true, encoding: .utf8)
        } else {
            let fallback = """
            Ghostscript produced no output.
            exit code: \(process.terminationStatus)
            termination reason: \(process.terminationReason.rawValue)
            """
            try? fallback.write(to: logURL, atomically: true, encoding: .utf8)
        }

        if process.terminationStatus != 0 {
            let detail = combinedText.isEmpty
                ? "exit code \(process.terminationStatus)（log: \(logURL.path)）"
                : "\(combinedText)（log: \(logURL.path)）"
            throw PDFOptimizeError.ghostscriptFailed(detail)
        }

        guard FileManager.default.fileExists(atPath: tempOutput.path) else {
            throw PDFOptimizeError.ghostscriptFailed("未產生輸出檔案")
        }

        do {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.copyItem(at: tempOutput, to: outputURL)
            try? FileManager.default.removeItem(at: tempDirectory)
        } catch {
            throw PDFOptimizeError.ghostscriptFailed(error.localizedDescription)
        }
    }

    private func findGhostscriptPath() -> String? {
        if let bundledURL = Bundle.main.url(forResource: "gs", withExtension: nil) {
            let path = bundledURL.path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let candidates = [
            "/opt/homebrew/bin/gs",
            "/usr/local/bin/gs",
            "/usr/bin/gs"
        ]

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        if let envPath = ProcessInfo.processInfo.environment["PATH"] {
            for entry in envPath.split(separator: ":") {
                let path = "\(entry)/gs"
                if FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }

        return nil
    }

    private struct GhostscriptResourcePaths {
        let libraryPathList: String
        let fontPath: String?
        let iccPath: String?
    }

    private func findGhostscriptResourcePaths(gsPath: String) -> GhostscriptResourcePaths? {
        // 首先嘗試在 app bundle 中查找資源
        if let resourceURL = Bundle.main.resourceURL {
            let gsRootURL = resourceURL.appendingPathComponent("ghostscript", isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: gsRootURL.path, isDirectory: &isDir), isDir.boolValue {
                if let paths = extractResourcePaths(from: gsRootURL) {
                    return paths
                }
            }
        }

        // 如果 bundle 中沒有，嘗試根據 gs 執行檔路徑推斷系統資源位置
        return findSystemGhostscriptResources(gsPath: gsPath)
    }

    private func findSystemGhostscriptResources(gsPath: String) -> GhostscriptResourcePaths? {
        // 從 gs 執行檔路徑推斷 share 目錄
        // 例如：/opt/homebrew/bin/gs -> /opt/homebrew/share/ghostscript/
        let gsURL = URL(fileURLWithPath: gsPath)
        let binDir = gsURL.deletingLastPathComponent() // /opt/homebrew/bin
        let prefixDir = binDir.deletingLastPathComponent() // /opt/homebrew

        let candidateShareDirs = [
            prefixDir.appendingPathComponent("share/ghostscript", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/share/ghostscript"),
            URL(fileURLWithPath: "/usr/local/share/ghostscript"),
            URL(fileURLWithPath: "/usr/share/ghostscript")
        ]

        for shareDir in candidateShareDirs {
            if let paths = extractResourcePaths(from: shareDir) {
                return paths
            }
        }

        return nil
    }

    private func extractResourcePaths(from gsRootURL: URL) -> GhostscriptResourcePaths? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gsRootURL.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }

        // 嘗試直接在根目錄下的 Resource 結構（常見於 bundle）
        let rootResourceDir = gsRootURL.appendingPathComponent("Resource", isDirectory: true)
        let rootInitDir = rootResourceDir.appendingPathComponent("Init", isDirectory: true)
        let rootLibDir = gsRootURL.appendingPathComponent("lib", isDirectory: true)
        if FileManager.default.fileExists(atPath: rootResourceDir.path) {
            var paths: [String] = []
            if FileManager.default.fileExists(atPath: rootInitDir.path) {
                paths.append(rootInitDir.path)
            }
            paths.append(rootResourceDir.path)
            if FileManager.default.fileExists(atPath: rootLibDir.path) {
                paths.append(rootLibDir.path)
            }
            let fontDir = rootResourceDir.appendingPathComponent("Font", isDirectory: true)
            let fallbackFontDir = gsRootURL.appendingPathComponent("fonts", isDirectory: true)
            let iccDir = gsRootURL.appendingPathComponent("iccprofiles", isDirectory: true)
            let fontPath = FileManager.default.fileExists(atPath: fontDir.path)
                ? fontDir.path
                : (FileManager.default.fileExists(atPath: fallbackFontDir.path) ? fallbackFontDir.path : nil)
            let iccPath = FileManager.default.fileExists(atPath: iccDir.path) ? iccDir.path : nil
            return GhostscriptResourcePaths(
                libraryPathList: paths.joined(separator: ":"),
                fontPath: fontPath,
                iccPath: iccPath
            )
        }

        // 嘗試在版本子目錄下查找（常見於系統安裝，如 /usr/share/ghostscript/10.03.0/）
        guard let versionDirs = try? FileManager.default.contentsOfDirectory(
            at: gsRootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for dir in versionDirs where dir.hasDirectoryPath {
            let resourceDir = dir.appendingPathComponent("Resource", isDirectory: true)
            let initDir = resourceDir.appendingPathComponent("Init", isDirectory: true)
            let fontDir = resourceDir.appendingPathComponent("Font", isDirectory: true)
            let libDir = dir.appendingPathComponent("lib", isDirectory: true)
            let iccDir = dir.appendingPathComponent("iccprofiles", isDirectory: true)

            var paths: [String] = []
            if FileManager.default.fileExists(atPath: initDir.path) {
                paths.append(initDir.path)
            }
            if FileManager.default.fileExists(atPath: resourceDir.path) {
                paths.append(resourceDir.path)
            }
            if FileManager.default.fileExists(atPath: libDir.path) {
                paths.append(libDir.path)
            }

            if !paths.isEmpty {
                let fontPath = FileManager.default.fileExists(atPath: fontDir.path) ? fontDir.path : nil
                let iccPath = FileManager.default.fileExists(atPath: iccDir.path) ? iccDir.path : nil
                return GhostscriptResourcePaths(
                    libraryPathList: paths.joined(separator: ":"),
                    fontPath: fontPath,
                    iccPath: iccPath
                )
            }
        }

        return nil
    }
}
