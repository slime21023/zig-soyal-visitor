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
pub const AddVisitorCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16,
        Area: u8,
        Node: u8,
        CardID: []const u8,
        StartTime: []const u8,
        EndTime: []const u8,
    };
};

/// JSON 指令結構 (1022 - 刪除訪客)
pub const DeleteVisitorCommand = struct {
    l_user: []const u8,
    cmd_array: []const CommandItem,

    pub const CommandItem = struct {
        c_cmd: u16,
        Area: u8,
        Node: u8,
        CardID: []const u8,
    };
};

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
        LiftData: ?[]const u8 = null, // 電梯樓層資料 (選填，格式如: "1,2,3,5" 表示可進入 1,2,3,5 樓)
    };
};

/// 訪客資訊結構（擴充版，支援電梯樓層）
pub const VisitorWithLift = struct {
    card_id: []const u8,
    start_time: []const u8,
    end_time: []const u8,
    area: u8 = 0,
    node: u8 = 1,
    lift_floors: ?[]const u8 = null, // 電梯樓層列表，格式: "1,2,3,5"
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
    username: []const u8 = "admin",
};