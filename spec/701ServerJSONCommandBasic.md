# 701Server JSON Command 文件

## 版本資訊
- **版本**: 1.05
- **產品**: 701ServerSQL 10v5
- **公司**: SOYAL TECHNOLOGY CO., LTD.
- **網址**: http://www.soyal.com
- **日期**: 2023/7/18

---

## 1. JSON Command Schema 格式

### 1.1 請求格式 (Request Schema)

```json
{
  "l_user": "login user",
  "cmd_array": [
    {
      "c_cmd": 1000,
      "user": "Engineer"
    },
    {
      "c_cmd": 1002,
      "NodeID": 1,
      "Start": 0,
      "End": 3
    }
  ]
}
```

### 1.2 回應格式 (Response Schema)

```json
{
  "resp_array": [
    {
      "c_cmd": 1000,
      "c_resp": 3,
      "db_used": true,
      "name": "Name",
      "ver": "10.1"
    },
    {
      "c_cmd": 1002,
      "c_resp": 3,
      "NodeID": 1,
      "Array": [
        {"Data": "0xFFFFFFFF", "Index": 0},
        {"Data": "0xFFFFFFFF", "Index": 1}
      ]
    }
  ]
}
```

### 1.3 回應代碼 (Response Code)

| 回應代碼 | 說明 |
|---------|------|
| 3 | Echo request data |
| 4 | Echo ACK |
| 5 | Echo NACK |

### 1.4 錯誤回應格式

```json
{
  "resp_err": "(0x80000003) command array can not be null!"
}
```

---

## 2. 命令列表

### 2.1 取得伺服器資訊 (Get Server Information)

**命令代碼**: 1000

**請求參數**:
- `c_cmd`: 1000 (INT)

**回應參數**:
- `c_cmd`: 1000 (INT)
- `c_resp`: 3 (INT)
- `ver`: 主機作業系統版本 (String)
- `name`: 主機名稱 (String)
- `db_used`: 資料庫使用狀態 (Bool)

---

### 2.2 取得控制器類型與線上狀態 (Get Controller Type and Online Status)

**命令代碼**: 1001

**請求參數**:
- `c_cmd`: 1001 (INT)
- `Area`: 0-15 (INT, 預設 0) □
- `Start Node`: 起始節點 1-254 (INT)
- `End Node`: 結束節點 1-254 (INT)
- `PollNode`: LAN 上輪詢的節點 (String) □
- `Online`: 控制器線上/離線狀態 (String) □
- `CtlCode`: 線上控制器類型代碼 (String) □
- `NetFamily`: LAN 上每個網路的控制器系列 (String) □

**回應參數**:
- `c_cmd`: 1001 (INT)
- `c_resp`: 3 (INT)
- `Area`: 0-15 (INT)
- `Start Node`: 回應資料的起始節點 (INT)
- `End Node`: 回應資料的結束節點 (INT)
- `PollNode`: "1"=已檢查, "0"=未檢查 (String)
- `Online`: "1"=線上, "0"=離線 (String)
- `CtlCode`: 控制器代碼，"FF"=未知 (String)
- `NetFamily`: 網路系列設定 (String)

**範例**:

請求:
```json
{
  "cmd_array": [{
    "c_cmd": 1001,
    "Area": 1,
    "Start Node": 1,
    "End Node": 10,
    "Online": "",
    "CtlCode": "",
    "NetFamily": "",
    "PollNode": ""
  }],
  "l_user": "supervisor"
}
```

回應:
```json
{
  "resp_array": [{
    "Area": 1,
    "CtlCode": "0xFFFFFFFFFFFFFFFFFFFF",
    "End Node": 10,
    "NetFamily": "0x16161616161616161616",
    "Online": "0000000000",
    "PollNode": "0000000000",
    "Start Node": 1,
    "c_cmd": 1001,
    "c_resp": 3
  }]
}
```

---

### 2.3 取得遠端終端控制器 IO 狀態

**命令代碼**: 1002

**請求參數**:
- `c_cmd`: 1002 (INT)
- `Area`: 0 (INT) □
- `Node`: 控制器節點 (INT)
- `Start Pp`: I/O 起始位址 0-1023 (INT)
- `End Pp`: I/O 結束位址 0-1023 (INT)

---

### 2.4 取得門禁控制器 IO 狀態

**命令代碼**: 1003

**請求參數**:
- `c_cmd`: 1003 (INT)
- `Area`: 0 (INT) □
- `Start`: 1 (INT)
- `End`: 2 (INT)

**回應參數**:
- `c_cmd`: 1003 (INT)
- `c_resp`: 3 (INT)
- `Array`: 包含節點狀態資訊的陣列
  - `Node`: 節點編號
  - `Status`: "Online !" 或 "Offline !"
  - `SubArray`: 子節點資訊
    - `ARM`: "Off"
    - `Alarm Relay`: "Off"
    - `Alarming`: "Off"
    - `Door`: "Close"
    - `Door Relay`: "Close"
    - `PTE`: "Off"
    - `SubNode`: "Main" 或 "WG"

**範例**:

```json
{
  "resp_array": [{
    "c_cmd": 1003,
    "c_resp": 3,
    "Array": [
      {
        "Node": 1,
        "Status": "Online !",
        "SubArray": [
          {
            "ARM": "Off",
            "Alarm Relay": "Off",
            "Alarming": "Off",
            "Door": "Close",
            "Door Relay": "Close",
            "PTE": "Off",
            "SubNode": "Main"
          },
          {
            "ARM": "Off",
            "Alarm Relay": "Off",
            "Alarming": "Off",
            "Door": "Close",
            "Door Relay": "Close",
            "PTE": "Off",
            "SubNode": "WG"
          }
        ]
      },
      {
        "Node": 2,
        "Status": "Offline !"
      }
    ]
  }]
}
```

---

### 2.5 設定遠端終端控制器 IO 狀態

**命令代碼**: 1004

**請求參數**:
- `c_cmd`: 1004 (INT)
- `Area`: 0 (INT) □
- `Node`: 1-254 (INT)
- `Pp`: 0-1023 (INT)
- `State`: 0 或 1 (INT)
- `Value`: 0=鎖定, 1=脈衝 (INT) □

**回應參數**:
- `c_cmd`: 1004 (INT)
- `c_resp`: 4 (INT)

**備註**: Value 欄位為選用，支援門禁控制器控制門鎖繼電器

---

### 2.6 設定訪客標籤 UID 和時間限制

**命令代碼**: 1021

**請求參數**:
- `c_cmd`: 1021 (INT)
- `Area`: 0 (INT) □
- `Node`: 節點編號 (INT)
- `Addr`: 位址 (INT)
- `TagUID`: 8 位元組 UID (HEX) (String)
- `Begin_dt`: 開始日期時間 "YYYY-MM-DD HH:MM" (String)
- `End_dt`: 結束日期時間 "YYYY-MM-DD HH:MM" (String)
- `Lift`: 4 位元組電梯控制 (HEX) (String) □
  - [1~8F][9~16F][17~24F][25~32F]
- `DoorAccess`: 2 位元組門禁權限 (HEX) (String) □
  - [1st Byte][2nd Byte]
  - 控制面板：第1位元組 bit 0 允許節點9存取，bit 7 允許節點16存取
  - 控制器：第2位元組 bit 0 允許主埠存取，第1位元組 bit 1 允許WG埠存取
- `PIN`: 0-999999999 (INT)
- `Mode`: 0/1/2/3 (無效/僅卡片/卡片或PIN/卡片和PIN) (INT)
- `Alias`: LCD 顯示名稱 (16 ASCII 或 8 Big-5) (String)

**回應參數**:
- `c_cmd`: 1021 (INT)
- `c_resp`: 4 (INT)

---

### 2.7 清除訪客標籤

**命令代碼**: 1022

**請求參數**:
- `c_cmd`: 1022 (INT)
- `Area`: 0 (INT) □
- `Node`: 節點編號 (INT)
- `Addr`: 位址 (INT)

**回應參數**:
- `c_cmd`: 1022 (INT)
- `c_resp`: 4 (INT)

---

### 2.8 清除範圍內的訪客標籤

**命令代碼**: 1024

**請求參數**:
- `c_cmd`: 1024 (INT)
- `Area`: 0 (INT) □
- `Node`: 節點編號 (INT)
- `AddrStr`: 起始位址 (INT)
- `AddrEnd`: 結束位址 (INT)

**回應參數**:
- `c_cmd`: 1024 (INT)
- `c_resp`: 4 (INT)

---

### 2.9 HEX 格式協定傳輸

**命令代碼**: 2000

**請求參數**:
- `c_cmd`: 2000 (INT)
- `Area`: 0 (INT) □
- `Node`: 節點編號 (INT)
- `Hex`: 從功能代碼開始的傳輸資料 "0x..." (String)
- `Format`: "L" = E-Serial 控制器長格式 (String) □

**回應參數**:
- `c_cmd`: 2000 (INT)
- `Area`: 0 (INT)
- `Node`: 節點編號 (INT)
- `c_resp`: 3 (INT)
- `Hex`: 回應資料 (String)

**範例 1**: 標準格式傳輸

發送: `0x7E.04.01.25.DB.01`

請求:
```json
{
  "l_user": "login user",
  "cmd_array": [{
    "c_cmd": 2000,
    "Area": 0,
    "Node": 1,
    "Hex": "0x25"
  }]
}
```

接收: `0x7E21000B0120271701010516110001000010005C340100907E000000000000000071B9`

回應:
```json
{
  "resp_array": [{
    "c_cmd": 2000,
    "Area": 0,
    "Node": 1,
    "c_resp": 3,
    "Hex": "0x7E21000B0120271701010516110001000010005C340100907E000000000000000071B9"
  }]
}
```

**範例 2**: 設定 RTC

`7E 0B 01 23 07 1B 0A 02 02 05 16 D8 47` (Node:1, Cmd:23, Sec.Min.Hr.Week.Day.Mon.Year)

請求:
```json
{
  "l_user": "login user",
  "cmd_array": [{
    "c_cmd": 2000,
    "Area": 0,
    "Node": 1,
    "Hex": "0x23071B0A02020516"
  }]
}
```

回應:
```json
{
  "resp_array": [{
    "Area": 0,
    "Hex": "0x7E0700040144E05E87",
    "Node": 1,
    "c_cmd": 2000,
    "c_resp": 3
  }]
}
```

---

### 2.10 建立事件記錄

**命令代碼**: 3002

**請求參數**:
- `c_cmd`: 3002 (INT)
- `Area`: 0 (INT) □
- `Node`: 節點編號 (INT)
- `MsgCode`: 0-256 (INT)
- `MsgSubCode`: 0-256 (INT)
- `Door`: 1-255 (INT)
- `Addr`: 0-32767 (INT)
- `TagUID`: 8 位元組 UID (HEX) (String)
- `Datetime`: "YYYY-MM-DD HH:MM:SS" (String) □

**回應參數**:
- `c_cmd`: 3002 (INT)
- `c_resp`: 4 (INT)
- `REC_INDEX`: 插入的事件記錄索引 (INT64)

**備註**: 
- 若 Datetime 欄位為空，將使用伺服器當前時間
- **10v4 版本**:
  - MsgCode: 114 用於遠端考勤
  - MsgSubCode: 1=遠端進入, 2=遠端離開, 3=修改進入, 4=修改離開

---

### 2.11 設定控制器即時時鐘

**命令代碼**: 3003

**請求參數**:
- `c_cmd`: 3003 (INT)
- `Area`: 0 (INT) □
- `Node`: 節點編號 (INT)
- `Datetime`: "YYYY-MM-DD HH:MM:SS" (String) □

**回應參數**:
- `c_cmd`: 3003 (INT)
- `c_resp`: 4 (INT)

**備註**: 若 Datetime 欄位為空，將使用伺服器當前時間

---

## 3. 控制器系列代碼

| 代碼 | 系列說明 |
|------|---------|
| 00H | AR701 Serial Desktop Remote I/O Controller |
| 01H | AR704E 4 Door Controller Serial |
| 02H | AR716E 16 Door Controller Serial (Version I) |
| 03H | AR716E 16 Door Controller Serial (Version II) |
| 04H | AR716E 16 Door Controller with TCP/IP Module (Version II) |
| 05H | AR821E LCD Fingerprint Controller Serial |
| 06H | AR821E LCD Fingerprint Controller with lift control |
| 07H | AR829E LCD Controller Serial |
| 08H | AR821E LCD Fingerprint Controller Serial (Version II) |
| 09H | AR727H LCD Controller Serial (Version I) |
| 0AH | AR101H/323D/721H/723H & 888W Controller Serial |
| 0BH | AR727/747H LCD Controller Serial (Version III) |
| 0CH | AR829E LCD Controller Serial (Version III) |
| 0DH | AR716E18 16+2 Door Controller with TCP/IP (Version III) |
| 0EH | AR401E Remote Programmer Logic Controller |
| 0FH | AR821E LCD Fingerprint Controller Serial (Version III) |
| 10H | AR821E LCD Vein Controller Serial (Version I) |
| 11H | AR821E LCD Fingerprint Controller Serial (Version IV) |
| 12H | AR725E Controller Serial (Version I) |
| 13H | AR821E LCD Vein Controller Serial (Version II) |
| 14H | AR321H/331H/725H/888H Controller Serial (Version I) |
| 15H | AR721E Dual Port Wiegand Controller Serial (Version I) |
| 16H | AR331E/327E/725Ev2/727E/837E/EF/881E/716E16 Controller |
| 17H | RS-485 Remote IO with MODBUS-RTU Support |
| 18H | TCP/IP Remote Gateway and IO with MODBUS-TCP Support |

---

## 4. 更新記錄

| 版本 | 日期 | 更新內容 |
|------|------|---------|
| 1.01 | 2020-Nov-27 | 初始版本 |
| 1.02 | 2020-Dec-24 | - |
| 1.03 | 2021-Jun-18 | 新增命令 1021, 1022 |
| 1.04 | 2022-May-02 | 新增命令 2000, 3003 |
| 1.05 | 2023-Jul-18 | 當前版本 |

---

## 附註

**符號說明**:
- □ 表示該欄位可省略 (optional)
- INT: 整數類型
- String: 字串類型
- Bool: 布林值類型
- INT64: 64位元整數類型

---

**文件資訊**:
- 公司: SOYAL TECHNOLOGY CO., LTD.
- 網址: http://www.soyal.com
- 文件版本: 1.05
- 更新日期: 2023/7/18