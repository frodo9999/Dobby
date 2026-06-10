import SwiftUI
import PhotosUI

/// Lets the user take a photo with the camera or pick one from the photo library.
/// Writes compressed JPEG data to the `imageData` binding when done.
struct PhotoCaptureView: View {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingCameraUnavailableAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Camera
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showingCamera = true
                    } else {
                        showingCameraUnavailableAlert = true
                    }
                } label: {
                    actionTile(icon: "camera.fill", title: "拍照", color: .blue)
                }

                // Photo library
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    actionTile(icon: "photo.on.rectangle", title: "从相册选择", color: .green)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("选择图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(photoData: $imageData)
                    .ignoresSafeArea()
                    .onDisappear {
                        if imageData != nil { dismiss() }
                    }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data),
                       let jpeg = uiImage.jpegData(compressionQuality: 0.6) {
                        imageData = jpeg
                        dismiss()
                    }
                }
            }
            .alert("相机不可用", isPresented: $showingCameraUnavailableAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text("此设备不支持相机，请从相册选择图片")
            }
        }
    }

    @ViewBuilder
    private func actionTile(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
