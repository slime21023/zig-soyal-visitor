const std = @import("std");
const types = @import("types.zig");
const Client = @import("client.zig").Client;
const commands = @import("commands.zig");
const builtin = @import("builtin");

pub fn main() !void {
    // 在 Windows 上設定控制台為 UTF-8 編碼
    if (builtin.os.tag == .windows) {
        _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 解析命令列參數
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    // 預設設定
    const config = types.Config{};

    // 建立 TCP 客戶端
    var client = Client.init(allocator, config.host, config.port);

    const command = args[1];

    if (std.mem.eql(u8, command, "add")) {
        handleAddCommand(allocator, &client, config, args) catch |err| {
            if (err != error.ConnectionRefused and
                err != error.NetworkUnreachable and
                err != error.ConnectionTimedOut and
                err != error.NoResponse)
            {
                std.debug.print("\n❌ 執行失敗: {s}\n", .{@errorName(err)});
                std.debug.print("   請檢查參數是否正確或聯繫系統管理員\n\n", .{});
            }
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "add-extended")) {
        handleAddExtendedCommand(allocator, &client, config, args) catch |err| {
            if (err != error.ConnectionRefused and
                err != error.NetworkUnreachable and
                err != error.ConnectionTimedOut and
                err != error.NoResponse)
            {
                std.debug.print("\n❌ 執行失敗: {s}\n", .{@errorName(err)});
                std.debug.print("   請檢查參數是否正確或聯繫系統管理員\n\n", .{});
            }
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "raw")) {
        handleRawCommand(allocator, &client, config, args) catch |err| {
            if (err != error.ConnectionRefused and
                err != error.NetworkUnreachable and
                err != error.ConnectionTimedOut and
                err != error.NoResponse)
            {
                std.debug.print("\n❌ 執行失敗: {s}\n", .{@errorName(err)});
                std.debug.print("   請檢查參數是否正確或聯繫系統管理員\n\n", .{});
            }
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "delete")) {
        handleDeleteCommand(allocator, &client, config, args) catch |err| {
            if (err != error.ConnectionRefused and
                err != error.NetworkUnreachable and
                err != error.ConnectionTimedOut and
                err != error.NoResponse)
            {
                std.debug.print("\n❌ 執行失敗: {s}\n", .{@errorName(err)});
                std.debug.print("   請檢查參數是否正確或聯繫系統管理員\n\n", .{});
            }
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printUsage();
    } else {
        std.debug.print("\n❌ 未知指令: {s}\n\n", .{command});
        try printUsage();
        std.process.exit(1);
    }
}

fn handleAddCommand(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    args: [][:0]u8,
) !void {
    if (args.len < 5) {
        std.debug.print("\n❌ 參數不足\n", .{});
        std.debug.print("用法: soyal-visitor add <卡片ID> <開始時間> <結束時間> [區域] [節點]\n", .{});
        std.debug.print("\n範例:\n", .{});
        std.debug.print("  soyal-visitor add QR123456 \"2024-11-19 09:00:00\" \"2024-11-19 17:00:00\"\n", .{});
        std.debug.print("  soyal-visitor add QR789012 \"2024-11-19 09:00:00\" \"2024-11-19 17:00:00\" 0 1\n\n", .{});
        return error.InvalidArguments;
    }

    const card_id = args[2];
    const start_time = args[3];
    const end_time = args[4];
    const area: u8 = if (args.len > 5) std.fmt.parseInt(u8, args[5], 10) catch {
        std.debug.print("\n❌ 錯誤: 區域編號必須是 0-255 之間的數字\n", .{});
        std.debug.print("   您輸入的值: {s}\n\n", .{args[5]});
        return error.InvalidArea;
    } else 0;
    const node: u8 = if (args.len > 6) std.fmt.parseInt(u8, args[6], 10) catch {
        std.debug.print("\n❌ 錯誤: 節點編號必須是 0-255 之間的數字\n", .{});
        std.debug.print("   您輸入的值: {s}\n\n", .{args[6]});
        return error.InvalidNode;
    } else 1;

    const visitor = types.Visitor{
        .card_id = card_id,
        .start_time = start_time,
        .end_time = end_time,
        .area = area,
        .node = node,
    };

    try commands.addVisitor(allocator, client, config, visitor);
}

fn handleDeleteCommand(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    args: [][:0]u8,
) !void {
    if (args.len < 2) {
        std.debug.print("\n❌ 錯誤: delete 指令需要參數\n", .{});
        std.debug.print("   用法: soyal-visitor delete [區域] [節點]\n\n", .{});
        return error.MissingArguments;
    }

    const area: u8 = if (args.len > 2) std.fmt.parseInt(u8, args[2], 10) catch {
        std.debug.print("\n❌ 錯誤: 區域編號必須是 0-255 之間的數字\n", .{});
        std.debug.print("   您輸入的值: {s}\n\n", .{args[2]});
        return error.InvalidArea;
    } else 0;
    const node: u8 = if (args.len > 3) std.fmt.parseInt(u8, args[3], 10) catch {
        std.debug.print("\n❌ 錯誤: 節點編號必須是 0-255 之間的數字\n", .{});
        std.debug.print("   您輸入的值: {s}\n\n", .{args[3]});
        return error.InvalidNode;
    } else 1;

    try commands.deleteVisitor(allocator, client, config, area, node);
}

fn handleAddExtendedCommand(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    args: [][:0]u8,
) !void {
    if (args.len < 5) {
        std.debug.print("\n❌ 錯誤: add-extended 指令需要至少 3 個參數\n", .{});
        std.debug.print("   用法: soyal-visitor add-extended <卡片ID> <開始時間> <結束時間> [密碼] [區域] [節點]\n", .{});
        std.debug.print("   範例: soyal-visitor add-extended \"04295:14226\" \"2024-11-19 09:00\" \"2024-11-19 17:00\" 1212\n\n", .{});
        return error.MissingArguments;
    }

    const card_id = args[2];
    const start_time = args[3];
    const end_time = args[4];

    const password: ?u32 = if (args.len > 5)
        std.fmt.parseInt(u32, args[5], 10) catch null
    else
        null;

    const area: u8 = if (args.len > 6) std.fmt.parseInt(u8, args[6], 10) catch {
        std.debug.print("\n❌ 錯誤: 區域編號必須是 0-255 之間的數字\n", .{});
        std.debug.print("   您輸入的值: {s}\n\n", .{args[6]});
        return error.InvalidArea;
    } else 0;

    const node: u8 = if (args.len > 7) std.fmt.parseInt(u8, args[7], 10) catch {
        std.debug.print("\n❌ 錯誤: 節點編號必須是 0-255 之間的數字\n", .{});
        std.debug.print("   您輸入的值: {s}\n\n", .{args[7]});
        return error.InvalidNode;
    } else 1;

    const visitor = types.VisitorExtended{
        .card_id = card_id,
        .start_time = start_time,
        .end_time = end_time,
        .area = area,
        .node = node,
        .password = password,
    };

    try commands.addVisitorExtended(allocator, client, config, visitor, 0);
}

fn handleRawCommand(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    args: [][:0]u8,
) !void {
    if (args.len < 3) {
        std.debug.print("\n❌ 錯誤: raw 指令需要 HEX payload 參數\n", .{});
        std.debug.print("   用法: soyal-visitor raw <HEX_PAYLOAD> [區域] [節點]\n", .{});
        std.debug.print("   範例: soyal-visitor raw \"0x2184\" 0 1\n\n", .{});
        return error.MissingArguments;
    }

    const hex_payload = args[2];

    const area: u8 = if (args.len > 3) std.fmt.parseInt(u8, args[3], 10) catch {
        std.debug.print("\n❌ 錯誤: 區域編號必須是 0-255 之間的數字\n", .{});
        std.debug.print("   您輸入的值: {s}\n\n", .{args[3]});
        return error.InvalidArea;
    } else 0;

    const node: u8 = if (args.len > 4) std.fmt.parseInt(u8, args[4], 10) catch {
        std.debug.print("\n❌ 錯誤: 節點編號必須是 0-255 之間的數字\n", .{});
        std.debug.print("   您輸入的值: {s}\n\n", .{args[4]});
        return error.InvalidNode;
    } else 1;

    try commands.sendRawProtocol(allocator, client, config, area, node, hex_payload);
}

fn printUsage() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};
    try stdout.writeAll(
        \\
        \\🔧 SOYAL 訪客管理 CLI 工具
        \\━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        \\
        \\用法:
        \\  soyal-visitor <指令> [參數...]
        \\
        \\指令:
        \\  add <卡片ID> <開始時間> <結束時間> [區域] [節點]
        \\      新增訪客權限（使用 Command 1021）
        \\      
        \\      範例:
        \\        soyal-visitor add "04295:14226" "2024-11-19 09:00" "2024-11-19 17:00"
        \\        soyal-visitor add "59488:61427" "2024-11-19 09:00" "2024-11-19 17:00" 0 1
        \\
        \\  add-extended <卡片ID> <開始時間> <結束時間> [密碼] [區域] [節點]
        \\      新增訪客權限（使用 Command 2000，支援密碼等高級功能）
        \\      
        \\      範例:
        \\        soyal-visitor add-extended "04295:14226" "2024-11-19 09:00" "2024-11-19 17:00" 1212
        \\        soyal-visitor add-extended "59488:61427" "2024-11-19 09:00" "2024-11-19 17:00"
        \\
        \\  delete [區域] [節點]
        \\      刪除訪客權限（使用 Command 1022）
        \\      
        \\      範例:
        \\        soyal-visitor delete
        \\        soyal-visitor delete 0 1
        \\
        \\  raw <HEX_PAYLOAD> [區域] [節點]
        \\      發送原始 HEX 協議指令（Command 2000）
        \\      
        \\      範例:
        \\        soyal-visitor raw "0x2184" 0 1
        \\        soyal-visitor raw "0x8B570000C8..." 0 1
        \\
        \\  help
        \\      顯示此說明訊息
        \\
        \\參數說明:
        \\  卡片ID         卡號 (格式: 數字:數字，如 "04295:14226")
        \\  開始時間       權限開始時間 (格式: YYYY-MM-DD HH:MM)
        \\  結束時間       權限結束時間 (格式: YYYY-MM-DD HH:MM)
        \\  密碼           訪客密碼 (可選，數字)
        \\  HEX_PAYLOAD    原始 HEX 協議字串 (必須以 "0x" 開頭)
        \\  區域           控制器區域編號 (預設: 0)
        \\  節點           控制器節點編號 (預設: 1)
        \\
        \\環境變數:
        \\  SOYAL_HOST      701ServerSQL 主機位址 (預設: 127.0.0.1)
        \\  SOYAL_PORT      701ServerSQL 連接埠 (預設: 7010)
        \\  SOYAL_USER      登入使用者名稱 (預設: z visitor)
        \\
        \\範例:
        \\  # 新增訪客（Command 1021）
        \\  soyal-visitor add "04295:14226" "2024-11-19 08:00" "2024-11-19 18:00"
        \\
        \\  # 新增訪客並設定密碼（Command 2000）
        \\  soyal-visitor add-extended "04295:14226" "2024-11-19 08:00" "2024-11-19 18:00" 1212
        \\
        \\  # 發送原始 HEX 協議（控制門鎖）
        \\  soyal-visitor raw "0x2184" 0 1
        \\
        \\  # 刪除訪客權限
        \\  soyal-visitor delete
        \\
        \\  # 指定伺服器位址
        \\  SOYAL_HOST=192.168.1.100 SOYAL_PORT=7010 soyal-visitor add "12345:67890" "..." "..."
        \\
        \\━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        \\
        \\
    );
}
