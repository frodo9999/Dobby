import Foundation
import CoreData

struct CSVService {

    // MARK: - Export

    static func exportToCSV(items: [Item]) -> String {
        var lines: [String] = []
        lines.append("房间,柜子,物品名称,分类,数量,备注,过期日期,添加时间")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for item in items.sorted(by: { ($0.cabinet?.room?.name ?? "") < ($1.cabinet?.room?.name ?? "") }) {
            let roomName = escapeCSV(item.cabinet?.room?.name ?? "")
            let cabinetName = escapeCSV(item.cabinet?.name ?? "")
            let name = escapeCSV(item.name)
            let category = escapeCSV(item.category)
            let quantity = "\(item.quantity)"
            let notes = escapeCSV(item.notes)
            let expiry = item.expiryDate.map { dateFormatter.string(from: $0) } ?? ""
            let created = dateFormatter.string(from: item.createdAt)

            lines.append("\(roomName),\(cabinetName),\(name),\(category),\(quantity),\(notes),\(expiry),\(created)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Import

    struct ImportResult {
        var roomsCreated: Int = 0
        var cabinetsCreated: Int = 0
        var itemsCreated: Int = 0
        var errors: [String] = []
    }

    static func importFromCSV(
        csvString: String,
        context: NSManagedObjectContext,
        existingRooms: [Room]
    ) -> ImportResult {
        var result = ImportResult()
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }

        guard lines.count > 1 else {
            result.errors.append("CSV 文件为空或只有标题行")
            return result
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var roomMap: [String: Room] = [:]
        for room in existingRooms {
            roomMap[room.name] = room
        }

        for (index, line) in lines.dropFirst().enumerated() {
            let fields = parseCSVLine(line)

            guard fields.count >= 5 else {
                result.errors.append("第 \(index + 2) 行格式错误，已跳过")
                continue
            }

            let roomName = fields[0].trimmingCharacters(in: .whitespaces)
            let cabinetName = fields[1].trimmingCharacters(in: .whitespaces)
            let itemName = fields[2].trimmingCharacters(in: .whitespaces)
            let category = fields.count > 3 ? fields[3].trimmingCharacters(in: .whitespaces) : ""
            let quantity = fields.count > 4 ? (Int(fields[4].trimmingCharacters(in: .whitespaces)) ?? 1) : 1
            let notes = fields.count > 5 ? fields[5].trimmingCharacters(in: .whitespaces) : ""
            let expiryStr = fields.count > 6 ? fields[6].trimmingCharacters(in: .whitespaces) : ""

            guard !roomName.isEmpty, !cabinetName.isEmpty, !itemName.isEmpty else {
                result.errors.append("第 \(index + 2) 行缺少必要字段（房间/柜子/物品名称），已跳过")
                continue
            }

            // Find or create room
            let room: Room
            if let existing = roomMap[roomName] {
                room = existing
            } else {
                let newRoom = Room(context: context)
                newRoom.name = roomName
                newRoom.icon = "door.left.hand.closed"
                newRoom.sortOrder = 0
                room = newRoom
                roomMap[roomName] = newRoom
                result.roomsCreated += 1
            }

            // Find or create cabinet
            let cabinet: Cabinet
            if let existing = room.cabinetsArray.first(where: { $0.name == cabinetName }) {
                cabinet = existing
            } else {
                let newCabinet = Cabinet(context: context)
                newCabinet.name = cabinetName
                newCabinet.icon = "cabinet"
                newCabinet.sortOrder = 0
                newCabinet.room = room
                cabinet = newCabinet
                result.cabinetsCreated += 1
            }

            // Create item
            let expiryDate = expiryStr.isEmpty ? nil : dateFormatter.date(from: expiryStr)
            let item = Item(context: context)
            item.name = itemName
            item.category = category
            item.quantity = Int64(max(1, quantity))
            item.notes = notes
            item.expiryDate = expiryDate
            item.cabinet = cabinet
            result.itemsCreated += 1
        }

        try? context.save()
        return result
    }

    // MARK: - CSV Helpers

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
