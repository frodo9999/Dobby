import SwiftUI
import CoreData
import PhotosUI

struct AddItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let cabinet: Cabinet
    var existingItem: Item?

    @State private var name = ""
    @State private var category = ""
    @State private var quantity = 1
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingCameraAlert = false
    @State private var hasExpiryDate = false
    @State private var expiryDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!

    var isEditing: Bool { existingItem != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("物品名称", text: $name)

                    Picker("分类", selection: $category) {
                        Text("无分类").tag("")
                        ForEach(ItemCategory.allCases, id: \.rawValue) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat.rawValue)
                        }
                    }

                    Stepper("数量: \(quantity)", value: $quantity, in: 1...9999)
                }

                Section("照片") {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("移除照片", role: .destructive) {
                            self.photoData = nil
                            self.selectedPhoto = nil
                        }
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("从相册选择", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showingCamera = true
                        } else {
                            showingCameraAlert = true
                        }
                    } label: {
                        Label("拍照", systemImage: "camera")
                    }
                }

                Section("过期日期") {
                    Toggle("设置过期日期", isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker("过期日期", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("备注") {
                    TextField("可选备注", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "编辑物品" : "添加物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            photoData = uiImage.jpegData(compressionQuality: 0.6)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(photoData: $photoData)
            }
            .alert("无法使用相机", isPresented: $showingCameraAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text("当前设备不支持相机，请使用相册选择图片")
            }
            .onAppear {
                if let item = existingItem {
                    name = item.name
                    category = item.category
                    quantity = Int(item.quantity)
                    notes = item.notes
                    photoData = item.photoData
                    if let date = item.expiryDate {
                        hasExpiryDate = true
                        expiryDate = date
                    }
                }
            }
        }
    }

    private func saveItem() {
        let expiry = hasExpiryDate ? expiryDate : nil
        if let item = existingItem {
            item.name = name
            item.category = category
            item.quantity = Int64(quantity)
            item.notes = notes
            item.photoData = photoData
            item.expiryDate = expiry
            item.updatedAt = Date()
            try? viewContext.save()
            scheduleNotification(for: name, id: item.objectID.uriRepresentation().absoluteString, expiry: expiry)
        } else {
            let item = Item(context: viewContext)
            item.name = name
            item.category = category
            item.quantity = Int64(quantity)
            item.notes = notes
            item.photoData = photoData
            item.expiryDate = expiry
            item.cabinet = cabinet
            try? viewContext.save()
            scheduleNotification(for: name, id: item.objectID.uriRepresentation().absoluteString, expiry: expiry)
        }
    }

    private func scheduleNotification(for itemName: String, id: String, expiry: Date?) {
        if let expiry {
            NotificationManager.scheduleExpiryNotification(itemName: itemName, itemID: id, expiryDate: expiry)
        } else {
            NotificationManager.cancelExpiryNotification(itemID: id)
        }
    }
}
