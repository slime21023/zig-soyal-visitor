# SOYAL Command 2000 增補說明

## 概述

根據 SOYAL 官方文件，**command 2000** 是一個**通用協議傳輸指令（Universal Command）**，用於設定訪客存取時間段，並支援電梯樓層資料的控制。

## 相關資源

- [SOYAL 701ServerSQL Json Universal Command Introduction](https://www.soyal.com/article.php?act=view&id=84)
- SOYAL 提供的 JSON 指令包括：1000, 1001, 1002, 1003, 1004, 1021, 1022, 3002, 3003, 2000
- Command 2000 是新增的通用指令，支援所有協議傳輸

## 功能特點

### Command 2000 vs Command 1021

| 特性 | Command 1021 | Command 2000 |
|------|-------------|-------------|
| 用途 | 新增訪客權限 | 通用協議傳輸（新增訪客 + 電梯控制） |
| 電梯樓層支援 | ❌ 不支援 | ✅ 支援 |
| LiftData 欄位 | ❌ 無 | ✅ 有（選填） |
| 適用場景 | 基本門禁控制 | 門禁 + 電梯樓層控制 |

## 實作內容

### 1. 類型定義 (`types.zig`)

新增了以下結構：

```zig
/// JSON 指令結構 (2000 - 通用協議傳輸指令，支援電梯樓層資料)
pub const UniversalCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16, // 2000
        Area: u8,
        Node: u8,
        CardID: []const u8,
        StartTime: []const u8,
        EndTime: []const u8,
        LiftData: ?[]const u8 = null, // 電梯樓層資料 (選填)
    };
};

/// 訪客資訊結構（擴充版，支援電梯樓層）
pub const VisitorWithLift = struct {
    card_id: []const u8,
    start_time: []const u8,
    end_time: []const u8,
    area: u8 = 0,
    node: u8 = 1,
    lift_floors: ?[]const u8 = null, // 電梯樓層列表
};
```

### 2. 命令處理函數 (`commands.zig`)

新增了 `addVisitorWithLift()` 函數：

```zig
pub fn addVisitorWithLift(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    visitor: types.VisitorWithLift,
) !void
```

功能：
- 發送 command 2000 指令到 701ServerSQL
- 支援電梯樓層資料（LiftData）
- 顯示詳細的發送資訊和回應狀態

### 3. CLI 介面 (`main.zig`)

新增了 `add-lift` 命令：

```bash
soyal-visitor add-lift <卡片ID> <開始時間> <結束時間> <電梯樓層> [區域] [節點]
```

## 使用範例

### 基本用法

```bash
# 新增訪客，允許進入 1, 2, 5, 10 樓
soyal-visitor add-lift VISITOR001 "2024-11-19 08:00:00" "2024-11-19 18:00:00" "1,2,5,10"
```

### 進階用法

```bash
# 指定區域和節點，允許進入地下室和部分樓層
soyal-visitor add-lift QR789012 "2024-11-19 09:00:00" "2024-11-19 17:00:00" "B1,1,2,3" 0 1
```

### 電梯樓層格式

LiftData 欄位支援以下格式：
- **數字樓層**: `"1,2,3,5,10"`
- **含地下室**: `"B1,B2,1,2,3"`
- **混合格式**: `"B1,1,2,5,10,15"`

> **注意**：樓層號碼用逗號分隔，不要加空格

## JSON 指令範例

### Command 2000 發送格式

```json
{
  "l_user": "admin",
  "cmd_array": [
    {
      "c_cmd": 2000,
      "Area": 0,
      "Node": 1,
      "CardID": "VISITOR001",
      "StartTime": "2024-11-19 08:00:00",
      "EndTime": "2024-11-19 18:00:00",
      "LiftData": "1,2,5,10"
    }
  ]
}
```

### 伺服器回應格式

```json
{
  "resp_array": [
    {
      "c_cmd": 2000,
      "c_resp": 3,
      "Area": 0,
      "Node": 1
    }
  ]
}
```

回應代碼：
- `c_resp: 3` = ✅ 成功
- `c_resp: 其他值` = ❌ 失敗

## 測試建議

### 1. 測試基本功能

```bash
# 測試不含電梯樓層（向下相容）
soyal-visitor add VISITOR001 "2024-11-19 08:00:00" "2024-11-19 18:00:00"

# 測試含電梯樓層
soyal-visitor add-lift VISITOR002 "2024-11-19 08:00:00" "2024-11-19 18:00:00" "1,2,3"
```

### 2. 測試電梯樓層格式

```bash
# 測試數字樓層
soyal-visitor add-lift TEST001 "2024-11-19 08:00:00" "2024-11-19 18:00:00" "1,2,5"

# 測試地下室樓層
soyal-visitor add-lift TEST002 "2024-11-19 08:00:00" "2024-11-19 18:00:00" "B1,1,2"
```

### 3. 測試錯誤處理

```bash
# 測試參數不足
soyal-visitor add-lift VISITOR003 "2024-11-19 08:00:00"

# 測試連線錯誤（確保程式能正確處理）
SOYAL_HOST=192.168.1.999 soyal-visitor add-lift TEST "2024-11-19 08:00:00" "2024-11-19 18:00:00" "1,2"
```

## 技術細節

### 與 Command 1021 的整合

- Command 1021 (`add`): 用於一般訪客，不需要電梯控制
- Command 2000 (`add-lift`): 用於需要電梯樓層控制的訪客
- 兩者可以並存使用，互不影響

### 向下相容性

- 原有的 `add` 和 `delete` 指令完全不受影響
- 舊有的 `types.Visitor` 結構仍然保留
- 新增的 `types.VisitorWithLift` 為擴充版本

### UTF-8 支援

程式在 Windows 上自動設定控制台為 UTF-8 編碼，確保中文訊息正確顯示。

## 未來擴展建議

1. **批次處理**: 支援一次新增多個訪客
2. **時間範本**: 預設常用的時間範圍（如：工作時間、半天、全天）
3. **樓層範本**: 預設常用的樓層組合（如：辦公樓層、訪客樓層）
4. **配置檔**: 從配置檔讀取預設設定
5. **互動模式**: 提供互動式命令行介面

## 參考資料

- SOYAL 官方文件: https://www.soyal.com/article.php?act=view&id=84
- 701ServerSQL 產品頁: https://www.soyal.com/product.php?act=view&id=148
- JSON Command 規範: 參考 SOYAL 701Server Json Command 文件

## 維護者

本增補由 AI 助手根據 SOYAL 官方文件和網路資源完成。

最後更新：2024-11-19
