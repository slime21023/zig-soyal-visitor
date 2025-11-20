# 實現計畫文檔（方案 2：重構）

## 📅 文檔資訊
- **版本**：2.0
- **日期**：2024-11-20
- **方案**：方案 2 - 重構 Command 2000 實現
- **狀態**：📋 計畫階段

---

## 🎯 實現目標

### 主要目標
1. ✅ **保持 Command 1021/1022**：已完全符合規格，無需修改
2. 🔄 **重構 Command 2000**：符合官方規格，使用單一 `Hex` 參數
3. ✨ **新增輔助函數**：提供 HEX 構建工具
4. 📚 **完善文檔**：更新所有相關文檔

### 次要目標
- 保持向下相容（如果可能）
- 提供清晰的遷移路徑
- 增加測試覆蓋率

---

## 📋 實現階段

### 階段 1：準備工作 ✅
- [x] 清理舊 design 文檔
- [x] 創建新的設計文檔
  - [x] `01_COMMAND_SPECIFICATIONS.md`
  - [x] `02_DATA_STRUCTURE_DESIGN.md`
  - [x] `03_IMPLEMENTATION_PLAN.md`（本文檔）
- [x] 確認實現方案

### 階段 2：數據結構修改 🔄
**預估時間**：20-30 分鐘

#### 2.1 重命名現有結構
```zig
// src/types.zig

// 原有的 UniversalCommand 重命名為內部使用
/// 內部擴展命令（非官方規格）
/// 僅用於內部高層 API，不直接發送到 701Server
pub const InternalExtendedCommand = struct {
    // 保持原有結構不變
    // ...
};
```

#### 2.2 新增 Command 2000 結構
```zig
// src/types.zig

/// Command 2000：HEX 格式協議傳輸
/// 符合 SOYAL 701Server 官方規格 v1.01
pub const RawProtocolCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16,          // 2000
        Area: u8,
        Node: u8,
        Hex: []const u8,     // HEX 字串
    };
};
```

#### 2.3 新增輔助數據結構
```zig
// src/types.zig

/// 擴展訪客資訊（支援 Command 2000 高級功能）
pub const VisitorExtended = struct {
    card_id: []const u8,
    start_time: []const u8,
    end_time: []const u8,
    area: u8 = 0,
    node: u8 = 1,
    
    // Command 2000 專用
    password: ?u32 = null,
    access_mode: ?u8 = null,
    door_access: ?[]const u8 = null,
    lift_floors: ?[]const u8 = null,
};

/// 日期時間結構（用於 Command 2000 時間轉換）
pub const DateTime = struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    
    pub fn parse(time_str: []const u8) !DateTime;
    pub fn toHexBytes(self: DateTime, allocator: std.mem.Allocator) ![]u8;
};
```

### 階段 3：HEX 構建函數 🔄
**預估時間**：40-50 分鐘

#### 3.1 DateTime 實現
```zig
// src/converters.zig

/// 從 "YYYY-MM-DD HH:MM" 解析日期時間
pub fn parseDateTime(time_str: []const u8) !types.DateTime {
    // 驗證長度
    if (time_str.len != 16) return error.InvalidTimeFormat;
    
    // 解析各部分
    const year = try std.fmt.parseInt(u16, time_str[0..4], 10);
    const month = try std.fmt.parseInt(u8, time_str[5..7], 10);
    const day = try std.fmt.parseInt(u8, time_str[8..10], 10);
    const hour = try std.fmt.parseInt(u8, time_str[11..13], 10);
    const minute = try std.fmt.parseInt(u8, time_str[14..16], 10);
    
    // 驗證範圍
    if (year < 2000 or year > 2099) return error.YearOutOfRange;
    if (month < 1 or month > 12) return error.MonthOutOfRange;
    if (day < 1 or day > 31) return error.DayOutOfRange;
    if (hour > 23) return error.HourOutOfRange;
    if (minute > 59) return error.MinuteOutOfRange;
    
    return types.DateTime{
        .year = year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
    };
}
```

#### 3.2 8BH 協議 HEX 構建器
```zig
// src/converters.zig

/// 構建 8BH 協議 HEX 字串（設定訪客）
/// 範例輸出："0x8B570000C80000000010C73792000004BC86FFFFFF..."
pub fn buildVisitor8BHPayload(
    allocator: std.mem.Allocator,
    visitor: types.VisitorExtended,
    addr: u32,
) ![]u8 {
    // 1. 解析卡號
    var iter = std.mem.split(u8, visitor.card_id, ":");
    const first_str = iter.next() orelse return error.InvalidCardId;
    const second_str = iter.next() orelse return error.InvalidCardId;
    
    const card_first = try std.fmt.parseInt(u32, first_str, 10);
    const card_second = try std.fmt.parseInt(u32, second_str, 10);
    
    // 2. 解析時間
    const start_dt = try parseDateTime(visitor.start_time);
    const end_dt = try parseDateTime(visitor.end_time);
    
    // 3. 準備參數
    const password = visitor.password orelse 0;
    const access_mode = visitor.access_mode orelse 0x86; // 預設：卡片+密碼
    const door_access = visitor.door_access orelse "FFFFFF";
    const lift_data = visitor.lift_floors orelse "FF";
    
    // 4. 構建 HEX 字串
    return std.fmt.allocPrint(
        allocator,
        "0x8B570000{X:0>2}0000000{X:0>4}{X:0>4}0000{X:0>4}{X:0>2}{s}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}000000{s}",
        .{
            @as(u8, @intCast(addr & 0xFF)),
            card_first,
            card_second,
            password,
            access_mode,
            door_access,
            start_dt.year - 2000,
            start_dt.month,
            start_dt.day,
            start_dt.hour,
            start_dt.minute,
            end_dt.year - 2000,
            end_dt.month,
            end_dt.day,
            end_dt.hour,
            end_dt.minute,
            lift_data,
        }
    );
}
```

#### 3.3 其他協議構建器（可選）
```zig
// src/converters.zig

/// 構建 21H 協議（控制門鎖）
pub fn buildDoorControlPayload(
    allocator: std.mem.Allocator,
    action: u8,  // 0x84 = 開, 0x00 = 關
) ![]u8 {
    return std.fmt.allocPrint(allocator, "0x21{X:0>2}", .{action});
}

/// 構建 23H 協議（設定時間）
pub fn buildSetTimePayload(
    allocator: std.mem.Allocator,
    dt: types.DateTime,
) ![]u8 {
    // 時間格式：秒.分.時.週.日.月.年
    const weekday = 5; // 假設週五
    return std.fmt.allocPrint(
        allocator,
        "0x2300{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}",
        .{
            dt.minute,
            dt.hour,
            weekday,
            dt.day,
            dt.month,
            dt.year - 2000,
        }
    );
}
```

### 階段 4：命令處理函數 🔄
**預估時間**：30-40 分鐘

#### 4.1 新增 Command 2000 函數
```zig
// src/commands.zig

/// 發送原始協議指令（Command 2000）
pub fn sendRawProtocol(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    area: u8,
    node: u8,
    hex_payload: []const u8,
) !void {
    // 驗證 HEX 格式
    if (!std.mem.startsWith(u8, hex_payload, "0x")) {
        return error.InvalidHexFormat;
    }
    
    std.debug.print("\n📡 發送原始協議指令...\n", .{});
    std.debug.print("   Area: {d}\n", .{area});
    std.debug.print("   Node: {d}\n", .{node});
    std.debug.print("   Hex: {s}\n\n", .{hex_payload});
    
    // 建立指令
    const cmd_item = types.RawProtocolCommand.CommandItem{
        .c_cmd = 2000,
        .Area = area,
        .Node = node,
        .Hex = hex_payload,
    };
    
    var cmd_array = [_]types.RawProtocolCommand.CommandItem{cmd_item};
    
    const command = types.RawProtocolCommand{
        .l_user = config.username,
        .cmd_array = &cmd_array,
    };
    
    // 序列化並發送
    var json_buffer = std.ArrayList(u8).init(allocator);
    defer json_buffer.deinit();
    
    try std.json.stringify(command, .{}, json_buffer.writer());
    
    std.debug.print("🔍 JSON: {s}\n\n", .{json_buffer.items});
    
    const response = try client.sendCommand(json_buffer.items);
    defer allocator.free(response);
    
    try handleResponse(allocator, response);
}
```

#### 4.2 新增擴展訪客函數
```zig
// src/commands.zig

/// 新增訪客（使用 Command 2000，支援密碼等高級功能）
pub fn addVisitorExtended(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    visitor: types.VisitorExtended,
    addr: u32,
) !void {
    // 驗證
    validators.CardIdValidator.validate(visitor.card_id) catch |err| {
        std.debug.print("\n❌ {s}\n", .{validators.CardIdValidator.formatError(err)});
        return err;
    };
    
    validators.TimeValidator.validateTimeRange(visitor.start_time, visitor.end_time) catch |err| {
        std.debug.print("\n❌ {s}\n", .{validators.TimeValidator.formatError(err)});
        return err;
    };
    
    // 構建 HEX payload
    const hex_payload = try converters.buildVisitor8BHPayload(allocator, visitor, addr);
    defer allocator.free(hex_payload);
    
    std.debug.print("\n📝 新增訪客（擴展功能）...\n", .{});
    std.debug.print("   卡片 ID: {s}\n", .{visitor.card_id});
    std.debug.print("   位址: {d}\n", .{addr});
    if (visitor.password) |pwd| {
        std.debug.print("   密碼: {d}\n", .{pwd});
    }
    std.debug.print("   HEX Payload: {s}\n\n", .{hex_payload});
    
    // 發送
    try sendRawProtocol(allocator, client, config, visitor.area, visitor.node, hex_payload);
}
```

#### 4.3 更新/標記舊函數
```zig
// src/commands.zig

/// 新增訪客（含電梯樓層）- 內部實現
/// 注意：這不是官方 Command 2000 規格
/// 建議使用 addVisitorExtended() 代替
pub fn addVisitorWithLift(
    // ... 保持原有實現，但標記為內部使用
) !void {
    // 原有實現
}
```

### 階段 5：CLI 整合 🔄
**預估時間**：20-30 分鐘

#### 5.1 新增 CLI 命令
```zig
// src/main.zig

// 新增子命令：
// add-extended   - 使用 Command 2000 新增訪客（支援密碼）
// raw-protocol   - 發送原始 HEX 協議

const help_text =
    \\Usage: soyal-visitor <command> [options]
    \\
    \\Commands:
    \\  add <card_id> <start_time> <end_time> [area] [node]
    \\      新增訪客（Command 1021）
    \\
    \\  add-extended <card_id> <start_time> <end_time> [password] [area] [node]
    \\      新增訪客，支援密碼（Command 2000）
    \\
    \\  delete <card_id> [area] [node]
    \\      刪除訪客（Command 1022）
    \\
    \\  raw <hex_payload> [area] [node]
    \\      發送原始 HEX 協議（Command 2000）
    \\
    \\  help
    \\      顯示此幫助訊息
;
```

#### 5.2 實現新命令處理
```zig
// src/main.zig

// 處理 add-extended 命令
if (std.mem.eql(u8, command, "add-extended")) {
    // 解析參數
    const card_id = args[2];
    const start_time = args[3];
    const end_time = args[4];
    
    const password: ?u32 = if (args.len > 5)
        try std.fmt.parseInt(u32, args[5], 10)
    else
        null;
    
    const area: u8 = if (args.len > 6)
        try std.fmt.parseInt(u8, args[6], 10)
    else
        0;
    
    const node: u8 = if (args.len > 7)
        try std.fmt.parseInt(u8, args[7], 10)
    else
        1;
    
    const visitor = types.VisitorExtended{
        .card_id = card_id,
        .start_time = start_time,
        .end_time = end_time,
        .area = area,
        .node = node,
        .password = password,
    };
    
    try commands.addVisitorExtended(allocator, &client, config, visitor, 0);
}

// 處理 raw 命令
if (std.mem.eql(u8, command, "raw")) {
    const hex_payload = args[2];
    const area: u8 = if (args.len > 3) try std.fmt.parseInt(u8, args[3], 10) else 0;
    const node: u8 = if (args.len > 4) try std.fmt.parseInt(u8, args[4], 10) else 1;
    
    try commands.sendRawProtocol(allocator, &client, config, area, node, hex_payload);
}
```

### 階段 6：測試 🔄
**預估時間**：30-40 分鐘

#### 6.1 單元測試
```zig
// src/converters.zig

test "DateTime parsing" {
    const dt = try parseDateTime("2024-11-19 09:00");
    try std.testing.expectEqual(@as(u16, 2024), dt.year);
    try std.testing.expectEqual(@as(u8, 11), dt.month);
    try std.testing.expectEqual(@as(u8, 19), dt.day);
    try std.testing.expectEqual(@as(u8, 9), dt.hour);
    try std.testing.expectEqual(@as(u8, 0), dt.minute);
}

test "buildVisitor8BHPayload" {
    const allocator = std.testing.allocator;
    
    const visitor = types.VisitorExtended{
        .card_id = "04295:14226",
        .start_time = "2022-06-16 10:27",
        .end_time = "2023-06-16 10:27",
        .password = 1212,
    };
    
    const hex = try buildVisitor8BHPayload(allocator, visitor, 200);
    defer allocator.free(hex);
    
    // 驗證關鍵部分
    try std.testing.expect(std.mem.startsWith(u8, hex, "0x8B570000C8"));
    try std.testing.expect(std.mem.indexOf(u8, hex, "10C73792") != null);
}
```

#### 6.2 功能測試
```bash
# 測試 Command 1021（原有功能）
zig build run -- add "04295:14226" "2024-11-19 09:00" "2024-11-19 17:00"

# 測試 Command 2000（新增功能）
zig build run -- add-extended "04295:14226" "2024-11-19 09:00" "2024-11-19 17:00" 1212

# 測試原始協議
zig build run -- raw "0x2184" 0 1

# 測試完整的 8BH 協議
zig build run -- raw "0x8B570000C80000000010C73792000004BC86FFFFFF1606100A1B1706100A1B000000FF" 0 1
```

### 階段 7：文檔更新 🔄
**預估時間**：20-30 分鐘

#### 7.1 更新主 README
- 添加 Command 2000 說明
- 更新命令列表
- 添加新的使用範例

#### 7.2 更新 COMMAND_2000_README（如果存在）
- 標記為新版實現
- 添加實際範例

#### 7.3 創建遷移指南
- 說明從舊版 API 遷移的方法
- 提供對照表

---

## ⏱️ 時間估算

| 階段 | 任務 | 預估時間 |
|------|------|----------|
| 1 | 準備工作 | ✅ 完成 |
| 2 | 數據結構修改 | 20-30 分鐘 |
| 3 | HEX 構建函數 | 40-50 分鐘 |
| 4 | 命令處理函數 | 30-40 分鐘 |
| 5 | CLI 整合 | 20-30 分鐘 |
| 6 | 測試 | 30-40 分鐘 |
| 7 | 文檔更新 | 20-30 分鐘 |
| **總計** | | **2.5-3.5 小時** |

---

## 🎯 實現優先級

### P0（必須）
- [x] 設計文檔 ✅
- [ ] `RawProtocolCommand` 數據結構 🔄
- [ ] `buildVisitor8BHPayload()` 函數 🔄
- [ ] `sendRawProtocol()` 函數 🔄
- [ ] 基本測試 🔄

### P1（重要）
- [ ] `addVisitorExtended()` 函數 🔄
- [ ] CLI 整合（add-extended, raw） 🔄
- [ ] 完整測試 🔄
- [ ] 主要文檔更新 🔄

### P2（建議）
- [ ] `buildDoorControlPayload()` 等其他協議 ⏳
- [ ] 更多單元測試 ⏳
- [ ] 性能優化 ⏳
- [ ] 遷移指南 ⏳

---

## ⚠️ 風險與緩解

### 風險 1：向下相容性
**影響**：現有使用 `UniversalCommand` 的代碼可能失效

**緩解**：
- 保留 `InternalExtendedCommand` 結構
- 提供清晰的遷移路徑
- 在文檔中標記變更

### 風險 2：HEX 構建複雜度
**影響**：HEX 字串構建可能出錯

**緩解**：
- 詳細的單元測試
- 與官方範例對照驗證
- 提供調試日誌

### 風險 3：測試困難
**影響**：無法實際測試 701Server 連線

**緩解**：
- 單元測試覆蓋核心邏輯
- JSON 格式驗證
- 提供模擬模式

---

## 📊 成功標準

### 功能標準
- ✅ Command 1021/1022 保持不變
- ✅ Command 2000 符合官方規格
- ✅ HEX 構建函數正確輸出
- ✅ 所有測試通過

### 品質標準
- ✅ 代碼清晰易讀
- ✅ 文檔完整詳盡
- ✅ 無記憶體洩漏
- ✅ 錯誤處理完善

### 可用性標準
- ✅ CLI 命令直觀
- ✅ 錯誤訊息友善
- ✅ 範例易於理解
- ✅ 遷移路徑清晰

---

## 📚 相關文檔

- `01_COMMAND_SPECIFICATIONS.md` - 命令規格
- `02_DATA_STRUCTURE_DESIGN.md` - 數據結構設計
- `COMMAND_2000_ANALYSIS.md` - Command 2000 分析
- `TAGUID_CONVERSION_ANALYSIS.md` - TagUID 轉換分析

---

## 🚀 執行決策

**準備開始實現？**

請確認：
- [x] 已閱讀所有設計文檔 ✅
- [x] 理解實現方案 ✅
- [x] 時間安排合理 ✅
- [ ] 準備開始編碼 🔄

---

**文檔版本**：2.0  
**最後更新**：2024-11-20  
**狀態**：✅ 計畫完成，等待執行確認
