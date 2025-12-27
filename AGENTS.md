# AGENTS.md
# NekoPDF — Shared PDF Page Extraction & Future OCR Pipeline

---

## 🎯 專案總目標（Overall Goal）

建立一套可長期演進的 macOS 工具核心，支援以下能力：

- 將 PDF 拆解為可被後續處理的「頁面資產」
- 將每一頁輸出為高品質圖片（PNG）
- 為未來 OCR 與資訊擷取工具預留乾淨、可重用、可擴充的架構
- UI 與核心邏輯完全解耦，避免產品成長時反覆重寫

本專案不是一次性轉檔工具，而是一條 **可長出多個 App 的處理管線（Pipeline）**。

---

## 🧠 核心設計哲學（Non‑Negotiable）

- PDF 處理 ≠ UI
- OCR ≠ PDF
- Pipeline 線性，但控制權不屬於 UI
- 核心模組必須：
  - 可被多個 App 共用
  - 可被 CLI / Background Task 呼叫
  - 不依賴 AppKit / SwiftUI
  - 可單元測試

---

## 🧱 技術棧（Tech Stack）

- 語言：Swift 5.9+
- 平台：macOS 13+
- UI：AppKit（NSWindow / NSViewController）
- PDF 處理：PDFKit
- 圖像處理：Core Graphics
- App 型態：Sandboxed macOS App（App Store Friendly）

---

## 🗂 建議專案結構（Logical）

PDFToPNG / NekoPDF / NekoOCR 應共用相同核心結構：

- Core
  - PDFPageExtractor
  - ImageExportPipeline
- OCR
  - OCRPipeline
  - OCREngine
- App
  - UI / ViewController
- Utils
  - FileSystemHelper
  - Error Definitions

---

## 🧩 Core Module：PDFPageExtractor

### 定位（Responsibility）

PDFPageExtractor 只負責一件事：

**將 PDF 拆解為「頁面資產（Page Assets）」**

它不關心：
- 是否輸出成圖片
- 是否進行 OCR
- UI 顯示方式
- 檔案系統位置

---

### 核心資料模型（Data Model）

```swift
struct PDFPageAsset {
    let pageIndex: Int
    let pageSize: CGSize
    let renderScale: CGFloat
    let image: CGImage
}
```

設計重點：
- 使用 CGImage，避免過早綁定 NSImage
- 保留 pageIndex，供排序、OCR 對齊
- 不持有 URL、不寫檔、不做 side effect

---

### Public Interface

```swift
protocol PDFPageExtracting {
    func extract(
        from pdfURL: URL,
        dpi: CGFloat
    ) throws -> [PDFPageAsset]
}
```

實作：

```swift
final class PDFPageExtractor: PDFPageExtracting
```

---

### 行為約束（Behavior Rules）

- 頁面順序必須與 PDF 原始順序一致
- DPI 可控，並正確影響 renderScale
- 任一頁失敗，整批失敗（不 silent skip）
- 不寫檔、不 log UI、不顯示 alert

---

## 🖼 Image Export Pipeline（for NekoPDF）

圖片輸出不是 PDFPageExtractor 的責任。

---

### Image Export Interface

```swift
protocol ImageExporting {
    func export(
        pages: [PDFPageAsset],
        to directory: URL,
        format: ImageFormat
    ) throws
}
```

```swift
enum ImageFormat {
    case png
}
```

---

### 檔名與資料夾規則（Required）

- 使用者指定輸出目錄
- 自動建立子資料夾：

```
{outputDirectory}/{PDFFileName}/
```

- PNG 命名規則（補零）：

```
page_001.png
page_002.png
```

---

## ⚠️ 錯誤處理原則

必須明確處理：

- PDF 無法讀取
- PDF 無頁數
- Render 失敗
- 無寫入權限
- PNG 寫入失敗

錯誤訊息需為「人類可讀」，不得直接丟 NSError 描述。

---

## 🔍 Future App：NekoOCR（Design Only）

### App 定位

NekoOCR 是「圖片資訊擷取工具」，不是 PDF 工具。

- 輸入：Image Asset
- 處理：OCR / 分析
- 輸出：文字或結構資料

---

## 🧬 OCR Pipeline 抽象層

### OCR Input Asset

```swift
struct OCRInputAsset {
    let sourceIdentifier: String
    let image: CGImage
}
```

說明：
- 不知道來源是否為 PDF
- 可來自 PNG / JPEG / Screenshot

---

### OCR Engine Protocol

```swift
protocol OCREngine {
    func recognize(
        from asset: OCRInputAsset
    ) throws -> OCRResult
}
```

```swift
struct OCRResult {
    let text: String
}
```

---

## 🧠 OCR Pipeline Concept

```
PDF (optional)
   ↓
PDFPageExtractor
   ↓
[PDFPageAsset]
   ↓
OCRInputAsset Mapper
   ↓
OCREngine
   ↓
OCRResult
```

PDF 只是其中一種輸入來源。

---

## 🖥 UI 層設計原則（非常重要）

- UI 只能 orchestration，不得實作邏輯
- UI 不得持有 PDFPageAsset
- UI 不控制 pipeline 細節
- 長任務需預留：
  - Progress reporting（介面即可）
  - Cancellation token（介面即可）

---

## 🚫 明確禁止事項（Do Not）

- 不在 ViewController new PDFPageExtractor
- 不在 Core import AppKit
- 不在 OCR Engine 寫死語言
- 不假設 OCR 一定來自 PDF

---

## 🧪 架構驗收標準（Acceptance）

- PDFPageExtractor 可被多 App 共用
- OCR App 不依賴 PDF 也可存在
- 未來加入 Vision / Tesseract / LLM OCR
  - 不需修改現有介面

---

## 🔮 刻意延後（Explicitly Deferred）

- OCR 結構化輸出（table / block）
- 多語言模型管理
- OCR 進度視覺化
- Batch OCR

這些不是忘記，而是刻意不做。

---

## 🧠 Agent 最終提醒

這不是在寫轉檔工具，
而是在鋪一條 **未來能長出多個產品的處理管線**。

請寫慢一點，乾淨一點。
