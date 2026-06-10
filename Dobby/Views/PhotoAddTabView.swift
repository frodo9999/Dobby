import SwiftUI
import PhotosUI

/// Root view for the "拍照添加" tab.
/// Lets the user choose between single-item and receipt mode, then capture a photo.
struct PhotoAddTabView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.sortOrder)],
        animation: .default
    ) private var rooms: FetchedResults<Room>

    @State private var mode: PhotoAddMode = .singleItem
    @State private var showingCapture = false
    @State private var capturedImageData: Data?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false

    // Navigation targets
    @State private var singleItemResult: ItemRecognitionResult?
    @State private var receiptResults: [ItemRecognitionResult]?

    private let geminiService: GeminiServiceProtocol = {
        if let service = try? GeminiService() {
            return service as GeminiServiceProtocol
        }
        return MockGeminiService() as GeminiServiceProtocol
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Mode picker
                Picker("模式", selection: $mode) {
                    ForEach(PhotoAddMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Description
                VStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Capture button
                Button {
                    showingCapture = true
                } label: {
                    Label("拍照 / 选择图片", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                }
                .disabled(isProcessing)

                if isProcessing {
                    ProgressView("AI 识别中…")
                        .padding()
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("拍照添加")
            // Photo capture sheet
            .sheet(isPresented: $showingCapture) {
                PhotoCaptureView(imageData: $capturedImageData)
            }
            // Single item confirm sheet
            .sheet(item: $singleItemResult) { result in
                ItemConfirmView(
                    recognitionResult: result,
                    rooms: Array(rooms),
                    geminiService: geminiService
                )
            }
            // Receipt review sheet
            .sheet(isPresented: Binding(
                get: { receiptResults != nil },
                set: { if !$0 { receiptResults = nil } }
            )) {
                if let results = receiptResults {
                    ReceiptReviewView(
                        recognitionResults: results,
                        rooms: Array(rooms)
                    )
                }
            }
            .alert("识别失败", isPresented: $showingError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误，请重试")
            }
            // Trigger AI recognition when a photo is captured
            .onChange(of: capturedImageData) { _, data in
                guard let data else { return }
                Task { await recognize(imageData: data) }
            }
        }
    }

    // MARK: - Recognition

    private func recognize(imageData: Data) async {
        isProcessing = true
        capturedImageData = nil
        defer { isProcessing = false }

        do {
            switch mode {
            case .singleItem:
                let result = try await geminiService.recognizeItem(imageData: imageData)
                singleItemResult = result
            case .receipt:
                let results = try await geminiService.recognizeReceipt(imageData: imageData)
                receiptResults = results
            }
        } catch let error as GeminiServiceError {
            errorMessage = error.errorDescription
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Mode Enum

enum PhotoAddMode: String, CaseIterable, Identifiable {
    case singleItem
    case receipt

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singleItem: return "单件物品"
        case .receipt:    return "购物小票"
        }
    }

    var icon: String {
        switch self {
        case .singleItem: return "camera.viewfinder"
        case .receipt:    return "doc.text.viewfinder"
        }
    }

    var description: String {
        switch self {
        case .singleItem: return "拍摄单件物品，AI 自动识别名称、分类和保质期"
        case .receipt:    return "拍摄购物小票，批量添加多件物品"
        }
    }
}

// MARK: - ItemRecognitionResult: Identifiable (for .sheet(item:))

extension ItemRecognitionResult: Identifiable {
    public var id: String { name + (category?.rawValue ?? "") }
}

#Preview {
    PhotoAddTabView()
        .environment(\.managedObjectContext,
            PersistenceController.preview.container.viewContext)
}
