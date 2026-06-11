import SwiftUI
import CoreData
import PhotosUI

struct AddItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lm: LanguageManager

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
                Section(lm.s.basicInfo) {
                    TextField(lm.s.itemName, text: $name)

                    Picker(lm.s.category, selection: $category) {
                        Text(lm.s.noCategory).tag("")
                        ForEach(ItemCategory.allCases, id: \.rawValue) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat.rawValue)
                        }
                    }

                    Stepper(lm.s.quantityStepper(n: quantity), value: $quantity, in: 1...9999)
                }

                Section(lm.s.photo) {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button(lm.s.removePhoto, role: .destructive) {
                            self.photoData = nil
                            self.selectedPhoto = nil
                        }
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(lm.s.fromLibrary, systemImage: "photo.on.rectangle")
                    }

                    Button {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showingCamera = true
                        } else {
                            showingCameraAlert = true
                        }
                    } label: {
                        Label(lm.s.takePhoto, systemImage: "camera")
                    }
                }

                Section(lm.s.expirySection) {
                    Toggle(lm.s.setExpiry, isOn: $hasExpiryDate)
                    if hasExpiryDate {
                        DatePicker(lm.s.expiryDate, selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section(lm.s.notes) {
                    TextField(lm.s.notesPlaceholder, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? lm.s.editItem : lm.s.addItem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lm.s.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? lm.s.save : lm.s.add) {
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
            .alert(lm.s.cameraUnavailable, isPresented: $showingCameraAlert) {
                Button(lm.s.ok, role: .cancel) {}
            } message: {
                Text(lm.s.cameraUnavailableMsg)
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
