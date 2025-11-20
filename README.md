# SOYAL 訪客管理 CLI 工具

基於 Zig 開發的命令列工具，透過 TCP 協定與 SOYAL 701ServerSQL 通訊，實現訪客 QR Code 的設定與管理。

## ✨ 特色

- 🚀 使用 Zig 語言開發，高效能、低資源消耗
- 🔌 原生 TCP 協定通訊，無需額外依賴
- 📝 支援訪客權限新增與刪除
- 🎯 簡單易用的命令列介面
- ⚙️ 支援環境變數設定
- 🔐 支援 Command 2000 高級功能（密碼、門禁權限等）
- 🔄 自動 TagUID HEX 轉換
- ✅ 完全符合 SOYAL 701Server 官方規格

## 📦 安裝

### 前置需求
- Zig 0.11.0 或更新版本

### 編譯
```bash
# 克隆專案
git clone <repository-url>
cd soyal-visitor-cli

# 編譯
zig build

# 編譯並安裝到系統
zig build -Doptimize=ReleaseSafe
```

編譯後的執行檔位於 `zig-out/bin/soyal-visitor`

## 🚀 使用方式

### 基本指令

#### 1. 新增訪客權限
```bash
soyal-visitor add <卡片ID> <開始時間> <結束時間> [區域] [節點]
```

**範例**：
```bash
# 新增訪客，有效期限一天（卡號格式：數字:數字）
soyal-visitor add "59488:61427" "2024-11-19 09:00" "2024-11-19 17:00"

# 指定區域和節點
soyal-visitor add "04295:14226" "2024-11-20 08:00" "2024-11-20 18:00" 0 1
```

#### 2. 新增訪客權限（擴展功能 - 支援密碼）
```bash
soyal-visitor add-extended <卡片ID> <開始時間> <結束時間> [密碼] [區域] [節點]
```

**範例**：
```bash
# 新增訪客並設定密碼（使用 Command 2000）
soyal-visitor add-extended "04295:14226" "2024-11-19 09:00" "2024-11-19 17:00" 1212

# 不設定密碼
soyal-visitor add-extended "59488:61427" "2024-11-19 09:00" "2024-11-19 17:00"
```

#### 3. 發送原始 HEX 協議
```bash
soyal-visitor raw <HEX_PAYLOAD> [區域] [節點]
```

**範例**：
```bash
# 控制門鎖
soyal-visitor raw "0x2184" 0 1

# 完整的訪客設定 HEX
soyal-visitor raw "0x8B570000C8..." 0 1
```

#### 4. 刪除訪客權限
```bash
soyal-visitor delete [區域] [節點]
```

**範例**：
```bash
# 刪除訪客權限
soyal-visitor delete

# 指定區域和節點
soyal-visitor delete 0 1
```

#### 5. 顯示說明
```bash
soyal-visitor help
```

## ⚙️ 設定

### 環境變數

| 變數名稱 | 說明 | 預設值 |
|---------|------|--------|
| `SOYAL_HOST` | 701ServerSQL 主機位址 | 127.0.0.1 |
| `SOYAL_PORT` | 701ServerSQL 連接埠 | 7010 |
| `SOYAL_USER` | 登入使用者名稱 | z visitor |

**使用範例**：
```bash
# 連接到遠端伺服器
export SOYAL_HOST=192.168.1.100
export SOYAL_PORT=7010
export SOYAL_USER=admin

soyal-visitor add "12345:67890" "2024-11-19 09:00" "2024-11-19 17:00"
```

或單次使用：
```bash
SOYAL_HOST=192.168.1.100 soyal-visitor add "12345:67890" "2024-11-19 09:00" "2024-11-19 17:00"
```

## 🔄 TagUID 自動轉換

本工具會自動將使用者友善的 `"數字:數字"` 格式轉換為符合 SOYAL 規格的 8 bytes HEX TagUID。

### 轉換範例

```bash
$ soyal-visitor add "04295:14226" "2024-11-19 09:00" "2024-11-19 17:00"

📝 新增訪客...
   卡片 ID: 04295:14226
   TagUID (HEX): 0x0000000010C73792    ← 自動轉換
   開始時間: 2024-11-19 09:00
   結束時間: 2024-11-19 17:00
   區域/節點: 0/1
```

### 轉換演算法

```
公式：HEX_TagUID = (第一個數字 << 16) | 第二個數字

範例：
  輸入：04295:14226
  步驟 1：04295 = 0x10C7
  步驟 2：14226 = 0x3792
  步驟 3：(0x10C7 << 16) | 0x3792 = 0x10C73792
  輸出：0x0000000010C73792
```

詳細說明請參閱 [TAGUID_CONVERSION_ANALYSIS.md](TAGUID_CONVERSION_ANALYSIS.md)

---

## 📊 JSON 指令說明

### 新增訪客 (c_cmd: 1021)
```json
{
  "l_user": "z visitor",
  "cmd_array": [{
    "c_cmd": 1021,
    "Area": 0,
    "Node": 1,
    "Addr": 0,
    "TagUID": "0x00000000E860EFF3",
    "Begin_dt": "2024-11-19 09:00",
    "End_dt": "2024-11-19 17:00"
  }]
}
```

### 刪除訪客 (c_cmd: 1022)
```json
{
  "l_user": "z visitor",
  "cmd_array": [{
    "c_cmd": 1022,
    "Area": 0,
    "Node": 1,
    "Addr": 0
  }]
}
```

### HEX 協議傳輸 (c_cmd: 2000)
```json
{
  "l_user": "z visitor",
  "cmd_array": [{
    "c_cmd": 2000,
    "Area": 0,
    "Node": 1,
    "Hex": "0x8B570000C80000000010C73792000004BC86FFFFFF1606100A1B1706100A1B000000FF"
  }]
}
```

### 回應格式
```json
{
  "resp_array": [{
    "c_cmd": 1021,
    "c_resp": 3,
    "Area": 0,
    "Node": 1
  }]
}
```

**c_resp 狀態碼**：
- `3`: 執行成功 ✅
- 其他: 執行失敗 ❌

## 🔧 開發

### 專案結構
```
soyal-visitor-cli/
├── build.zig          # 建置設定
├── src/
│   ├── main.zig       # 主程式與 CLI 介面
│   ├── client.zig     # TCP 客戶端
│   ├── commands.zig   # 指令處理邏輯
│   └── types.zig      # 資料結構定義
└── README.md
```

### 執行測試
```bash
# 開發模式執行
zig build run -- help

# 測試新增訪客（使用正確的卡號格式：數字:數字）
zig build run -- add "12345:67890" "2024-11-19 09:00" "2024-11-19 17:00"

# 測試刪除訪客
zig build run -- delete "12345:67890"
```

## 📝 注意事項

1. **卡號格式**：必須使用 `數字:數字` 格式（如：`59488:61427`），詳見 [CARD_ID_FORMAT.md](design/CARD_ID_FORMAT.md)
2. **時間格式**：必須使用 `YYYY-MM-DD HH:MM` 格式（符合 SOYAL 701Server 規格）
3. **HEX 轉換**：卡號會自動轉換為 8 bytes HEX TagUID（如：`"04295:14226"` → `"0x0000000010C73792"`），詳見 [TAGUID_CONVERSION_ANALYSIS.md](TAGUID_CONVERSION_ANALYSIS.md)
4. **網路連線**：確保能連接到 701ServerSQL 伺服器
5. **權限**：需要有效的登入使用者名稱
6. **規格符合性**：詳見 [SPEC_COMPLIANCE_REPORT.md](SPEC_COMPLIANCE_REPORT.md)

## 🐛 疑難排解

### 連線失敗
```
error: ConnectionRefused
```
**解決方式**：
- 檢查 701ServerSQL 是否正在執行
- 確認主機位址和連接埠設定正確
- 檢查防火牆設定

### 指令執行失敗 (c_resp != 3)
**可能原因**：
- 卡片 ID 格式錯誤
- 時間格式不正確
- 控制器節點不存在
- 權限不足

## 🔧 進階功能

### Command 2000 說明

Command 2000 是一個底層協議傳輸指令，支援所有 SOYAL 協議功能。

**優點**：
- 支援密碼設定
- 支援門禁權限控制
- 支援電梯樓層設定
- 可直接發送原始協議指令

**使用方式**：
1. 使用 `add-extended` 命令（自動構建 HEX）
2. 使用 `raw` 命令（手動提供 HEX）

詳細說明請參閱 [COMMAND_2000_ANALYSIS.md](COMMAND_2000_ANALYSIS.md)

### 支援的命令列表

| 命令 | Command | 說明 | 支援狀態 |
|------|---------|------|----------|
| 1021 | 設定訪客標籤 | 高層 API，簡單易用 | ✅ 完全支援 |
| 1022 | 清除訪客標籤 | 刪除訪客權限 | ✅ 完全支援 |
| 2000 | HEX 格式協議傳輸 | 底層協議，功能完整 | ✅ 完全支援 |

## 📚 參考資料

### 官方文件
- [SOYAL 官方網站](https://www.soyal.com/article.php?act=view&id=84)
- [701ServerSQL JSON Command 1V05](https://files.soyal.com.tw/EN/download/Cross-System%20Integration/701Server%20Json%20Command%201V05.pdf)

### 技術參考
- [Zig 語言官方文件](https://ziglang.org/documentation/master/)

## 📄 授權

MIT License

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

---

**開發者**: 基於 SOYAL 701ServerSQL JSON Command 規格開發
**版本**: 1.0.0