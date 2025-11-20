const std = @import("std");

/// 訪客資訊結構
pub const Visitor = struct {
    card_id: []const u8,
    start_time: []const u8,
    end_time: []const u8,
    area: u8 = 0,
    node: u8 = 1,
};

/// JSON 指令結構 (1021 - 新增訪客)
/// 符合 SOYAL 701Server 官方規格
pub const AddVisitorCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16, // 1021
        Area: u8, // 0 (預設)
        Node: u8, // 節點編號
        Addr: u32, // 位址 (預設 0)
        TagUID: []const u8, // 卡號 (格式: 數字:數字)
        Begin_dt: []const u8, // 開始時間 "YYYY-MM-DD HH:MM"
        End_dt: []const u8, // 結束時間 "YYYY-MM-DD HH:MM"
    };
};

/// JSON 指令結構 (1022 - 刪除訪客)
/// 符合 SOYAL 701Server 官方規格
pub const DeleteVisitorCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16, // 1022
        Area: u8, // 0 (預設)
        Node: u8, // 節點編號
        Addr: u32, // 位址 (預設 0)
    };
};

/// JSON 指令結構 (2000 - HEX 格式協議傳輸)
/// 完全符合 SOYAL 701Server 官方規格 v1.01
/// 這是底層協議傳輸指令，支援所有 SOYAL 協議功能
pub const RawProtocolCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16, // 2000
        Area: u8, // 區域編號
        Node: u8, // 節點編號
        Hex: []const u8, // HEX 字串（必須以 "0x" 開頭）
    };
};

/// 擴展訪客資訊（支援 Command 2000 高級功能）
pub const VisitorExtended = struct {
    card_id: []const u8,
    start_time: []const u8,
    end_time: []const u8,
    area: u8 = 0,
    node: u8 = 1,

    // Command 2000 專用高級功能
    password: ?u32 = null, // 密碼（0-999999999）
    access_mode: ?u8 = null, // 通行模式（預設 0x86：卡片+密碼）
    door_access: ?[]const u8 = null, // 門禁權限 HEX（預設 "FFFFFF"）
    lift_floors: ?[]const u8 = null, // 電梯樓層 HEX（預設 "FF"）
};

/// 日期時間結構（用於 Command 2000 時間轉換）
pub const DateTime = struct {
    year: u16, // 2000-2099
    month: u8, // 1-12
    day: u8, // 1-31
    hour: u8, // 0-23
    minute: u8, // 0-59
};

/// 伺服器回應結構
pub const Response = struct {
    resp_array: []ResponseItem,

    pub const ResponseItem = struct {
        c_cmd: u16,
        c_resp: u8,
        Area: u8,
        Node: u8,
        Hex: ?[]const u8 = null,
    };
};

/// CLI 設定
pub const Config = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 7010,
    username: []const u8 = "z visitor", // 預設使用者名稱
};
