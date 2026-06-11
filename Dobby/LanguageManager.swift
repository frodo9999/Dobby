import Foundation
import SwiftUI

// MARK: - Manager

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "appLanguage") }
    }

    init() {
        self.language = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    }

    var isEnglish: Bool { language == "en" }
    var s: AppStrings { AppStrings(isEnglish: isEnglish) }
}

// MARK: - All UI Strings

struct AppStrings {
    let isEnglish: Bool

    // MARK: Tab Bar
    var tabRooms: String    { isEnglish ? "Rooms"     : "房间" }
    var tabSearch: String   { isEnglish ? "Search"    : "搜索" }
    var tabSmartAdd: String { isEnglish ? "Smart Add" : "拍照添加" }

    // MARK: Common actions
    var cancel: String        { isEnglish ? "Cancel"         : "取消" }
    var save: String          { isEnglish ? "Save"           : "保存" }
    var add: String           { isEnglish ? "Add"            : "添加" }
    var edit: String          { isEnglish ? "Edit"           : "编辑" }
    var delete: String        { isEnglish ? "Delete"         : "删除" }
    var ok: String            { isEnglish ? "OK"             : "好的" }
    var done: String          { isEnglish ? "Done"           : "完成" }
    var confirmDelete: String { isEnglish ? "Confirm Delete" : "确认删除" }

    // MARK: Language toggle
    var switchToOtherLang: String {
        isEnglish ? "切换到中文" : "Switch to English"
    }

    // MARK: RoomListView
    var myHome: String           { isEnglish ? "My Home"       : "我的家" }
    var inviteFamily: String     { isEnglish ? "Invite Family" : "邀请家庭成员" }
    var exportData: String       { isEnglish ? "Export Data"   : "导出数据" }
    var importData: String       { isEnglish ? "Import Data"   : "导入数据" }
    var shareFailed: String      { isEnglish ? "Share Failed"  : "共享失败" }
    var importComplete: String   { isEnglish ? "Import Complete" : "导入完成" }
    var noRooms: String          { isEnglish ? "No Rooms Yet"  : "还没有房间" }
    var addFirstRoom: String     { isEnglish ? "Tap + to add your first room" : "点击右上角 + 添加你的第一个房间" }
    var cannotDecodeFile: String { isEnglish ? "Cannot decode file encoding" : "无法读取文件编码" }

    func roomSubtitle(cabinets: Int, items: Int) -> String {
        isEnglish
            ? "\(cabinets) cabinets · \(items) items"
            : "\(cabinets) 个柜子 · \(items) 件物品"
    }
    func deleteRoomConfirm(name: String, cabinets: Int, items: Int) -> String {
        isEnglish
            ? "Delete \"\(name)\"? Its \(cabinets) cabinets and \(items) items will also be deleted. This cannot be undone."
            : "确定要删除「\(name)」吗？其中的 \(cabinets) 个柜子和 \(items) 件物品将被一并删除，此操作无法撤销。"
    }
    func importSummary(items: Int, rooms: Int, cabinets: Int, errors: [String]) -> String {
        if isEnglish {
            var s = "Imported \(items) items"
            if rooms > 0 || cabinets > 0 { s += " (\(rooms) rooms, \(cabinets) cabinets created)" }
            if !errors.isEmpty { s += "\n\nSkipped \(errors.count) rows: \(errors.first ?? "")" }
            return s
        } else {
            var s = "成功导入 \(items) 件物品"
            if rooms > 0 || cabinets > 0 { s += "（新建 \(rooms) 个房间、\(cabinets) 个柜子）" }
            if !errors.isEmpty { s += "\n\n跳过 \(errors.count) 行：\(errors.first ?? "")" }
            return s
        }
    }
    func fileReadError(_ msg: String) -> String {
        isEnglish ? "Cannot read file: \(msg)" : "读取文件失败：\(msg)"
    }
    func pickFileFailed(_ msg: String) -> String {
        isEnglish ? "Cannot pick file: \(msg)" : "选择文件失败：\(msg)"
    }

    // MARK: AddRoomView
    var roomName: String            { isEnglish ? "Room Name"             : "房间名称" }
    var roomNamePlaceholder: String { isEnglish ? "e.g. Bedroom, Kitchen" : "例如：主卧、厨房" }
    var chooseIcon: String          { isEnglish ? "Choose Icon"           : "选择图标" }
    var editRoom: String            { isEnglish ? "Edit Room"             : "编辑房间" }
    var addRoom: String             { isEnglish ? "Add Room"              : "添加房间" }

    // MARK: CabinetListView
    var noCabinets: String          { isEnglish ? "No Cabinets Yet"         : "还没有柜子" }
    var addCabinetHint: String      { isEnglish ? "Tap + to add a cabinet"  : "点击右上角 + 添加柜子" }

    func cabinetSubtitle(count: Int) -> String {
        isEnglish ? "\(count) items" : "\(count) 件物品"
    }
    func deleteCabinetConfirm(name: String, count: Int) -> String {
        isEnglish
            ? "Delete \"\(name)\"? Its \(count) items will also be deleted. This cannot be undone."
            : "确定要删除「\(name)」吗？其中的 \(count) 件物品将被一并删除，此操作无法撤销。"
    }

    // MARK: AddCabinetView
    var cabinetName: String             { isEnglish ? "Cabinet Name"                : "柜子名称" }
    var cabinetNamePlaceholder: String  { isEnglish ? "e.g. Wardrobe, Bookshelf"   : "例如：衣柜、书柜、鞋柜" }
    var editCabinet: String             { isEnglish ? "Edit Cabinet" : "编辑柜子" }
    var addCabinet: String              { isEnglish ? "Add Cabinet"  : "添加柜子" }

    // MARK: ItemListView
    var noItems: String      { isEnglish ? "No Items Yet"       : "还没有物品" }
    var addItemHint: String  { isEnglish ? "Tap + to add items" : "点击右上角 + 添加物品" }
    var sortSection: String  { isEnglish ? "Sort"               : "排序" }
    var filterSection: String { isEnglish ? "Filter by Category" : "按分类筛选" }
    var filterAll: String    { isEnglish ? "All"                 : "全部" }
    var moveBatch: String    { isEnglish ? "Move"                : "移动" }

    func deleteCountConfirm(count: Int) -> String {
        isEnglish
            ? "Delete \(count) selected items? This cannot be undone."
            : "确定要删除选中的 \(count) 件物品吗？此操作无法撤销。"
    }
    func deleteCountButton(count: Int) -> String {
        isEnglish ? "Delete \(count)" : "删除 \(count) 件"
    }

    // MARK: ItemSortOption display names
    var sortDateDesc:  String { isEnglish ? "Latest Added"    : "最新添加" }
    var sortDateAsc:   String { isEnglish ? "Earliest Added"  : "最早添加" }
    var sortNameAsc:   String { isEnglish ? "Name A→Z"        : "名称 A→Z" }
    var sortNameDesc:  String { isEnglish ? "Name Z→A"        : "名称 Z→A" }
    var sortExpiryAsc: String { isEnglish ? "Expiry (Soonest)" : "过期日期（近→远）" }
    var sortQtyDesc:   String { isEnglish ? "Quantity (Most)"  : "数量（多→少）" }

    // MARK: ExpiryBadge
    func expiryExpired(days: Int) -> String  { isEnglish ? "Expired \(-days)d ago" : "已过期 \(-days) 天" }
    var expiryToday: String                  { isEnglish ? "Expires today"         : "今天过期" }
    func expiryDaysLeft(days: Int) -> String { isEnglish ? "\(days)d left"         : "还剩 \(days) 天过期" }

    // MARK: ItemDetailView
    var category: String  { isEnglish ? "Category"   : "分类" }
    var quantity: String  { isEnglish ? "Quantity"   : "数量" }
    var expiryDate: String { isEnglish ? "Expiry Date" : "过期日期" }
    var notes: String     { isEnglish ? "Notes"      : "备注" }
    var addedOn: String   { isEnglish ? "Added On"   : "添加时间" }
    var moveTo: String    { isEnglish ? "Move to…"   : "移动到…" }

    func expiryDaysExpired(days: Int) -> String   { isEnglish ? "Expired \(-days)d ago" : "已过期 \(-days) 天" }
    func expiryDaysRemaining(days: Int) -> String { isEnglish ? "\(days) days left"     : "还剩 \(days) 天" }
    func deleteItemConfirm(name: String) -> String {
        isEnglish
            ? "Delete \"\(name)\"? This cannot be undone."
            : "确定要删除「\(name)」吗？此操作无法撤销。"
    }

    // MARK: AddItemView
    var basicInfo: String            { isEnglish ? "Basic Info"    : "基本信息" }
    var itemName: String             { isEnglish ? "Item Name"     : "物品名称" }
    var noCategory: String           { isEnglish ? "None"          : "无分类" }
    var photo: String                { isEnglish ? "Photo"         : "照片" }
    var removePhoto: String          { isEnglish ? "Remove Photo"  : "移除照片" }
    var fromLibrary: String          { isEnglish ? "From Library"  : "从相册选择" }
    var takePhoto: String            { isEnglish ? "Take Photo"    : "拍照" }
    var expirySection: String        { isEnglish ? "Expiry Date"   : "过期日期" }
    var setExpiry: String            { isEnglish ? "Set Expiry"    : "设置过期日期" }
    var notesPlaceholder: String     { isEnglish ? "Optional notes" : "可选备注" }
    var editItem: String             { isEnglish ? "Edit Item"     : "编辑物品" }
    var addItem: String              { isEnglish ? "Add Item"      : "添加物品" }
    var cameraUnavailable: String    { isEnglish ? "Camera Unavailable" : "无法使用相机" }
    var cameraUnavailableMsg: String { isEnglish ? "This device doesn't support the camera. Please use the photo library." : "当前设备不支持相机，请使用相册选择图片" }

    func quantityStepper(n: Int) -> String { isEnglish ? "Quantity: \(n)" : "数量: \(n)" }

    // MARK: MoveItemsView
    var itemLabel: String        { isEnglish ? "Item"             : "物品" }
    var currentLocation: String  { isEnglish ? "Current Location" : "当前位置" }
    var selected: String         { isEnglish ? "Selected"         : "已选择" }
    var current: String          { isEnglish ? "Current"          : "当前" }
    var moveToTitle: String      { isEnglish ? "Move To"          : "移动到" }
    var searchCabinets: String   { isEnglish ? "Search cabinets…" : "搜索柜子..." }

    func selectedCount(n: Int) -> String { isEnglish ? "\(n) items"    : "\(n) 件物品" }
    func itemCount(n: Int) -> String     { isEnglish ? "\(n) items"    : "\(n) 件" }
    func cabinetCount(n: Int) -> String  { isEnglish ? "\(n) cabinets" : "\(n) 个柜子" }

    // MARK: ItemConfirmView / CabinetPickerView
    var itemInfo: String            { isEnglish ? "Item Info"      : "物品信息" }
    var expiryLabel: String         { isEnglish ? "Expiry"         : "保质期" }
    var setExpiryToggle: String     { isEnglish ? "Set Expiry"     : "设置保质期" }
    var storageLocation: String     { isEnglish ? "Storage Location" : "存放位置" }
    var pleaseSelect: String        { isEnglish ? "Please Select"  : "请选择" }
    var selectLocationFirst: String { isEnglish ? "Please select a location before saving" : "请选择存放位置后再保存" }
    var confirmItem: String         { isEnglish ? "Confirm Item"   : "确认物品信息" }
    var selectCabinet: String       { isEnglish ? "Select Cabinet" : "选择柜子" }
    var unassigned: String          { isEnglish ? "Unassigned"     : "未分配" }

    func quantityStepperColon(n: Int) -> String { isEnglish ? "Quantity: \(n)" : "数量：\(n)" }

    // MARK: ReceiptReviewView
    var noItemsRecognized: String        { isEnglish ? "No Items Recognized"      : "没有识别到物品" }
    var retakeReceipt: String            { isEnglish ? "Please retake the receipt" : "请重新拍摄小票" }
    var confirmReceiptTitle: String      { isEnglish ? "Confirm Receipt Items"    : "确认小票物品" }
    var saveSuccess: String              { isEnglish ? "Saved"                    : "保存成功" }
    var expiryToggle: String             { isEnglish ? "Expiry"                   : "保质期" }
    var selectStorageLocation: String    { isEnglish ? "Select storage location"  : "请选择存放位置" }

    func saveAll(count: Int) -> String    { isEnglish ? "Save All (\(count))" : "保存全部（\(count)）" }
    func savedItems(count: Int) -> String { isEnglish ? "Added \(count) items" : "已添加 \(count) 件物品" }

    // MARK: PhotoAddTabView
    var singleItemMode: String    { isEnglish ? "Single Item"  : "单件物品" }
    var receiptMode: String       { isEnglish ? "Receipt"      : "购物小票" }
    var singleItemDesc: String    { isEnglish ? "Photograph an item — AI identifies name, category, and expiry" : "拍摄单件物品，AI 自动识别名称、分类和保质期" }
    var receiptDesc: String       { isEnglish ? "Photograph a receipt to add multiple items at once" : "拍摄购物小票，批量添加多件物品" }
    var takeOrSelectPhoto: String { isEnglish ? "Take / Select Photo"        : "拍照 / 选择图片" }
    var aiProcessing: String      { isEnglish ? "AI Processing…"             : "AI 识别中…" }
    var smartAdd: String          { isEnglish ? "Smart Add"                  : "拍照添加" }
    var recognitionFailed: String { isEnglish ? "Recognition Failed"         : "识别失败" }
    var unknownError: String      { isEnglish ? "Unknown error, please try again" : "未知错误，请重试" }
    var modePickerLabel: String   { isEnglish ? "Mode" : "模式" }

    // MARK: SearchView
    var searchTitle: String       { isEnglish ? "Search"              : "搜索" }
    var searchPlaceholder: String { isEnglish ? "Search items, cabinets, rooms…" : "搜索物品、柜子、房间..." }
    var expiryAlerts: String      { isEnglish ? "Expiry Alerts"       : "过期提醒" }
    var expired: String           { isEnglish ? "Expired"             : "已过期" }
    var expiringSoon7: String     { isEnglish ? "Expiring in 7 days"  : "7天内过期" }
    var byRoom: String            { isEnglish ? "By Room"             : "各房间物品" }
    var byCategory: String        { isEnglish ? "By Category"         : "分类统计" }
    var recentlyAdded: String     { isEnglish ? "Recently Added"      : "最近添加" }
    var statRooms: String         { isEnglish ? "Rooms"               : "房间" }
    var statCabinets: String      { isEnglish ? "Cabinets"            : "柜子" }
    var statItems: String         { isEnglish ? "Items"               : "物品" }
    var uncategorized: String     { isEnglish ? "Uncategorized"       : "未分类" }

    func searchResults(n: Int) -> String { isEnglish ? "Results (\(n))" : "搜索结果 (\(n))" }

    // MARK: AIDiscoveryView
    var aiAsk: String           { isEnglish ? "AI Ask"             : "AI 问问" }
    var aiDone: String          { isEnglish ? "Done"               : "完成" }
    var aiTrySuggestions: String { isEnglish ? "Try these"         : "试试这些" }
    var aiThinking: String      { isEnglish ? "AI is thinking…"    : "AI 正在思考…" }
    var aiQueryFailed: String   { isEnglish ? "Query failed"       : "查询失败" }
    var aiPlaceholder: String   { isEnglish ? "Ask AI, e.g. Do we have milk?" : "问问 AI，例如：有牛奶吗" }

    var aiChips: [String] {
        isEnglish
            ? ["Any food to eat?", "What can I drink?", "What's in the kitchen?", "Any food expiring soon?", "Do we have dish soap?", "Any medicine?"]
            : ["有吃的吗", "有什么可以喝的", "厨房里有什么", "有快过期的食品吗", "有洗碗液吗", "有药吗"]
    }

    // MARK: GeminiServiceError
    var errMissingKey: String      { isEnglish ? "API Key not configured"                        : "未配置 API Key，请检查设置" }
    var errInvalidResponse: String { isEnglish ? "Cannot parse response, please try again"       : "无法解析识别结果，请重试" }
    var errNoItems: String         { isEnglish ? "No items recognized, please retake the photo"  : "未能识别到任何物品，请重新拍摄" }
    func errNetwork(_ msg: String) -> String { isEnglish ? "Network error: \(msg)" : "网络错误：\(msg)" }
}
