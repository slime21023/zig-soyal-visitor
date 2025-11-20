# 數據結構設計文檔

## 📅 文檔資訊
- **版本**：2.0
- **日期**：2024-11-20
- **狀態**：✅ 設計完成，待實現

---

## 🎯 設計目標

### 核心原則
1. **符合官方規格**：完全按照 SOYAL 701Server 規格實現
2. **清晰分離**：高層 API 與底層協議清楚分離
3. **使用者友善**：提供易用的輸入介面
4. **可擴展性**：支援未來功能擴展

### 設計策略
- **Command 1021/1022**：使用結構化 JSON 參數（高層 API）
- **Command 2000**：使用 HEX 字串（底層協議）
- **內部轉換**：自動處理格式轉換
- **輔助函數**：提供 HEX 構建工具

---

## 📦 基礎數據結構

### 1. 訪客資訊（使用者輸入層）

```zig
/// 基本訪客資訊
/// 使用者友善的輸入格式
pub const Visitor = struct {
    card_id: []const u8,      // 格式："數字:數字"，如 "04295:14226"
    start_time: []const u8,   // 格式："YYYY-MM-DD HH:MM"
    end_time: []const u8,     // 格式："YYYY-MM-DD HH:MM"
    area: u8 = 0,             // 預設 0
    node: u8 = 1,             // 預設 1
};
```

### 2. 擴展訪客資訊（Command 2000 用）

```zig
/// 擴展訪客資訊（支援密碼、權限等）
/// 用於需要高級功能的場景
pub const VisitorExtended = struct {
    card_id: []const u8,      // 格式："數字:數字"
    start_time: []const u8,   // 格式："YYYY-MM-DD HH:MM"
    end_time: []const u8,     // 格式："YYYY-MM-DD HH:MM"
    area: u8 = 0,
    node: u8 = 1,
    
    // 高級功能（Command 2000 專用）
    password: ?u32 = null,           // 密碼（0-999999999）
    access_mode: ?u8 = null,         // 通行模式
    door_access: ?[]const u8 = null, // 門禁權限（HEX）
    lift_floors: ?[]const u8 = null, // 電梯樓層
};
```

---

## 📋 Command 1021 數據結構

### 命令結構（符合官方規格）

```zig
/// JSON 指令結構 (1021 - 設定訪客標籤 UID 和時間限制)
/// 完全符合 SOYAL 701Server 官方規格 v1.05
pub const AddVisitorCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16,              // 1021
        Area: u8,                // 0-15（預設 0）
        Node: u8,                // 1-255
        Addr: u32,               // 0-32767（預設 0）
        TagUID: []const u8,      // 8 bytes HEX String："0x..."
        Begin_dt: []const u8,    // "YYYY-MM-DD HH:MM"
        End_dt: []const u8,      // "YYYY-MM-DD HH:MM"
        
        // 選用參數（高級功能）
        Lift: ?[]const u8 = null,        // 4 bytes HEX
        DoorAccess: ?[]const u8 = null,  // 2 bytes HEX
        PIN: ?u32 = null,                // 0-999999999
        Mode: ?u8 = null,                // 0/1/2/3
        Alias: ?[]const u8 = null,       // LCD 顯示名稱
    };
};
```

### 使用範例

```zig
const cmd_item = AddVisitorCommand.CommandItem{
    .c_cmd = 1021,
    .Area = 0,
    .Node = 1,
    .Addr = 0,
    .TagUID = "0x0000000010C73792",
    .Begin_dt = "2024-11-19 09:00",
    .End_dt = "2024-11-19 17:00",
};
```

---

## 📋 Command 1022 數據結構

### 命令結構（符合官方規格）

```zig
/// JSON 指令結構 (1022 - 清除訪客標籤)
/// 完全符合 SOYAL 701Server 官方規格 v1.05
pub const DeleteVisitorCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16,  // 1022
        Area: u8,    // 0-15（預設 0）
        Node: u8,    // 1-255
        Addr: u32,   // 0-32767（預設 0）
    };
};
```

**注意**：1022 不需要 TagUID，只通過 Addr 刪除訪客。

### 使用範例

```zig
const cmd_item = DeleteVisitorCommand.CommandItem{
    .c_cmd = 1022,
    .Area = 0,
    .Node = 1,
    .Addr = 0,
};
```

---

## 📋 Command 2000 數據結構

### 命令結構（符合官方規格）

```zig
/// JSON 指令結構 (2000 - HEX 格式協議傳輸)
/// 完全符合 SOYAL 701Server 官方規格 v1.01
/// 這是底層協議傳輸指令，支援所有 SOYAL 協議功能
pub const RawProtocolCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16,          // 2000
        Area: u8,            // 區域編號
        Node: u8,            // 節點編號
        Hex: []const u8,     // HEX 字串（必須以 "0x" 開頭）
    };
};
```

### 使用範例

#### 範例 1：控制門鎖
```zig
const cmd_item = RawProtocolCommand.CommandItem{
    .c_cmd = 2000,
    .Area = 0,
    .Node = 1,
    .Hex = "0x2184",
};
```

#### 範例 2：設定訪客（8BH 協議）
```zig
const hex_payload = try buildVisitor8BHPayload(allocator, visitor_extended);
defer allocator.free(hex_payload);

const cmd_item = RawProtocolCommand.CommandItem{
    .c_cmd = 2000,
    .Area = 0,
    .Node = 1,
    .Hex = hex_payload,  // "0x8B570000C8..."
};
```

---

## 📊 回應數據結構

### 通用回應結構

```zig
/// 服務器回應結構
pub const Response = struct {
    resp_array: []const ResponseItem,

    pub const ResponseItem = struct {
        c_resp: u8,     // 3=處理中, 4=成功(ACK), 5=失敗(NACK)
        Area: u8,       // 區域編號
        Node: u8,       // 節點編號
        c_cmd: ?u16 = null,  // 原始命令代碼
        Hex: ?[]const u8 = null,  // HEX 回應（Command 2000）
    };
};
```

### 回應狀態碼

| c_resp | 狀態 | 說明 |
|--------|------|------|
| 3 | Processing | 處理中 |
| 4 | ACK | 成功 |
| 5 | NACK | 失敗 |

---

## 🔧 配置數據結構

### 系統配置

```zig
/// 系統配置
pub const Config = struct {
    host: []const u8,      // 701Server 主機位址
    port: u16,             // 連接埠（預設 7010）
    username: []const u8,  // 登入使用者名稱
};
```

### 預設配置

```zig
pub const DEFAULT_CONFIG = Config{
    .host = "127.0.0.1",
    .port = 7010,
    .username = "admin",
};
```

---

## 🔄 轉換輔助結構

### DateTime 結構（內部使用）

```zig
/// 日期時間結構
/// 用於 Command 2000 HEX 時間轉換
pub const DateTime = struct {
    year: u16,    // 2000-2099
    month: u8,    // 1-12
    day: u8,      // 1-31
    hour: u8,     // 0-23
    minute: u8,   // 0-59
    
    /// 從 "YYYY-MM-DD HH:MM" 字串解析
    pub fn parse(time_str: []const u8) !DateTime {
        // 實現解析邏輯
    }
    
    /// 轉換為 Command 2000 HEX 格式（5 bytes）
    pub fn toHexBytes(self: DateTime, allocator: std.mem.Allocator) ![]u8 {
        // YY MM DD HH MM (Hex)
        return std.fmt.allocPrint(
            allocator,
            "{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}",
            .{
                self.year - 2000,
                self.month,
                self.day,
                self.hour,
                self.minute,
            }
        );
    }
};
```

---

## 🗂️ 數據流程圖

### Command 1021 資料流程

```
使用者輸入
    ↓
Visitor {
    card_id: "04295:14226"
    start_time: "2024-11-19 09:00"
    end_time: "2024-11-19 17:00"
}
    ↓
[驗證器驗證]
    ↓
[轉換 TagUID]
card_id → "0x0000000010C73792"
    ↓
AddVisitorCommand.CommandItem {
    c_cmd: 1021
    Addr: 0
    TagUID: "0x0000000010C73792"
    Begin_dt: "2024-11-19 09:00"
    End_dt: "2024-11-19 17:00"
}
    ↓
[JSON 序列化]
    ↓
發送到 701Server
```

### Command 2000 資料流程

```
使用者輸入
    ↓
VisitorExtended {
    card_id: "04295:14226"
    start_time: "2024-11-19 09:00"
    end_time: "2024-11-19 17:00"
    password: 1212
}
    ↓
[驗證器驗證]
    ↓
[構建 HEX Payload]
buildVisitor8BHPayload() → "0x8B570000C8..."
    ↓
RawProtocolCommand.CommandItem {
    c_cmd: 2000
    Area: 0
    Node: 1
    Hex: "0x8B570000C8..."
}
    ↓
[JSON 序列化]
    ↓
發送到 701Server
```

---

## 📝 設計決策記錄

### 決策 1：Addr 固定為 0
**理由**：
- 簡化操作
- 適合單一訪客場景
- 未來可擴展為動態管理

### 決策 2：保留兩種命令結構
**理由**：
- Command 1021：高層 API，易用
- Command 2000：底層協議，功能完整
- 滿足不同使用場景

### 決策 3：使用者輸入 "數字:數字" 格式
**理由**：
- 易讀、易記
- 與系統界面顯示一致
- 內部自動轉換為 HEX

### 決策 4：Command 2000 使用單一 Hex 參數
**理由**：
- 符合官方規格
- 支援所有協議功能
- 靈活性最大

---

## 🔍 與舊版的差異

### 舊版 UniversalCommand（錯誤）

```zig
// ❌ 錯誤：不符合官方規格
pub const UniversalCommand = struct {
    pub const CommandItem = struct {
        c_cmd: u16,
        Area: u8,
        Node: u8,
        CardID: []const u8,     // ❌ 官方沒有這個
        StartTime: []const u8,  // ❌ 官方沒有這個
        EndTime: []const u8,    // ❌ 官方沒有這個
        LiftData: ?[]const u8,  // ❌ 官方沒有這個
    };
};
```

### 新版 RawProtocolCommand（正確）

```zig
// ✅ 正確：符合官方規格
pub const RawProtocolCommand = struct {
    pub const CommandItem = struct {
        c_cmd: u16,
        Area: u8,
        Node: u8,
        Hex: []const u8,  // ✅ 官方規格的單一參數
    };
};
```

---

## 🎯 實現檢查清單

### 數據結構
- [x] `Visitor` - 基本訪客資訊 ✅
- [x] `AddVisitorCommand` - Command 1021 ✅
- [x] `DeleteVisitorCommand` - Command 1022 ✅
- [ ] `VisitorExtended` - 擴展訪客資訊 🔄
- [ ] `RawProtocolCommand` - Command 2000 🔄
- [ ] `DateTime` - 時間轉換輔助 🔄

### 輔助函數
- [x] `cardIdToHexTagUID()` - 卡號轉 HEX ✅
- [ ] `buildVisitor8BHPayload()` - 構建 8BH HEX 🔄
- [ ] `DateTime.parse()` - 解析時間字串 🔄
- [ ] `DateTime.toHexBytes()` - 時間轉 HEX 🔄

---

## 📚 相關文檔

- `01_COMMAND_SPECIFICATIONS.md` - 命令規格
- `03_IMPLEMENTATION_PLAN.md` - 實現計畫
- `TAGUID_CONVERSION_ANALYSIS.md` - TagUID 轉換分析

---

**文檔版本**：2.0  
**最後更新**：2024-11-20  
**狀態**：✅ 設計完成
