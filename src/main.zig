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
                err != error.NoResponse) {
                std.debug.print("\n❌ 執行失敗: {s}\n", .{@errorName(err)});
                std.debug.print("   請檢查參數是否正確或聯繫系統管理員\n\n", .{});
            }
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, command, "add-lift")) {
        handleAddLiftCommand(allocator, &client, config, args) catch |err| {
            if (err != error.ConnectionRefused and 
                err != error.NetworkUnreachable and 
                err != error.ConnectionTimedOut and
                err != error.NoResponse) {
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
                err != error.NoResponse) {
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
    if (args.len < 3) {
        std.debug.print("\n❌ 參數不足\n", .{});
        std.debug.print("用法: soyal-visitor delete <卡片ID> [區域] [節點]\n", .{});
        std.debug.print("\n範例:\n", .{});
        std.debug.print("  soyal-visitor delete QR123456\n", .{});
        std.debug.print("  soyal-visitor delete QR789012 0 1\n\n", .{});
        return error.InvalidArguments;
    }

    const card_id = args[2];
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

    try commands.deleteVisitor(allocator, client, config, card_id, area, node);
}

fn handleAddLiftCommand(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    args: [][:0]u8,
) !void {
    if (args.len < 6) {
        std.debug.print("\n❌ 參數不足\n", .{});
        std.debug.print("用法: soyal-visitor add-lift <卡片ID> <開始時間> <結束時間> <電梯樓層> [區域] [節點]\n", .{});
        std.debug.print("電梯樓層格式: \"1,2,3,5\" (用逗號分隔樓層號碼)\n", .{});
        std.debug.print("\n範例:\n", .{});
        std.debug.print("  soyal-visitor add-lift VISITOR001 \"2024-11-19 09:00:00\" \"2024-11-19 17:00:00\" \"1,2,5,10\"\n", .{});
        std.debug.print("  soyal-visitor add-lift QR789012 \"2024-11-19 09:00:00\" \"2024-11-19 17:00:00\" \"B1,1,2,3\" 0 1\n\n", .{});
        return error.InvalidArguments;
    }

    const card_id = args[2];
    const start_time = args[3];
    const end_time = args[4];
    const lift_floors = args[5];
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

    const visitor = types.VisitorWithLift{
        .card_id = card_id,
        .start_time = start_time,
        .end_time = end_time,
        .area = area,
        .node = node,
        .lift_floors = lift_floors,
    };

    try commands.addVisitorWithLift(allocator, client, config, visitor);
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
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
        \\      新增訪客權限
        \\      
        \\      範例:
        \\        soyal-visitor add QR123456 "2024-11-19 09:00:00" "2024-11-19 17:00:00"
        \\        soyal-visitor add QR789012 "2024-11-19 09:00:00" "2024-11-19 17:00:00" 0 1
        \\
        \\  add-lift <卡片ID> <開始時間> <結束時間> <電梯樓層> [區域] [節點]
        \\      新增訪客權限（含電梯樓層控制，使用 command 2000）
        \\      電梯樓層格式: "1,2,3,5" (用逗號分隔樓層號碼)
        \\      
        \\      範例:
        \\        soyal-visitor add-lift VISITOR001 "2024-11-19 09:00:00" "2024-11-19 17:00:00" "1,2,5,10"
        \\        soyal-visitor add-lift QR789012 "2024-11-19 09:00:00" "2024-11-19 17:00:00" "B1,1,2,3" 0 1
        \\
        \\  delete <卡片ID> [區域] [節點]
        \\      刪除訪客權限
        \\      
        \\      範例:
        \\        soyal-visitor delete QR123456
        \\        soyal-visitor delete QR789012 0 1
        \\
        \\  help
        \\      顯示此說明訊息
        \\
        \\參數說明:
        \\  卡片ID      訪客的 QR Code 或卡片識別碼
        \\  開始時間    權限開始時間 (格式: YYYY-MM-DD HH:MM:SS)
        \\  結束時間    權限結束時間 (格式: YYYY-MM-DD HH:MM:SS)
        \\  電梯樓層    可進入的電梯樓層 (格式: "1,2,3,5" 或 "B1,1,2,3")
        \\  區域        控制器區域編號 (預設: 0)
        \\  節點        控制器節點編號 (預設: 1)
        \\
        \\環境變數:
        \\  SOYAL_HOST      701ServerSQL 主機位址 (預設: 127.0.0.1)
        \\  SOYAL_PORT      701ServerSQL 連接埠 (預設: 7010)
        \\  SOYAL_USER      登入使用者名稱 (預設: admin)
        \\
        \\範例:
        \\  # 新增訪客，有效期限一天
        \\  soyal-visitor add VISITOR001 "2024-11-19 08:00:00" "2024-11-19 18:00:00"
        \\
        \\  # 新增訪客並指定可進入電梯樓層（使用 command 2000）
        \\  soyal-visitor add-lift VISITOR002 "2024-11-19 08:00:00" "2024-11-19 18:00:00" "1,2,5,10"
        \\
        \\  # 刪除訪客權限
        \\  soyal-visitor delete VISITOR001
        \\
        \\  # 指定伺服器位址
        \\  SOYAL_HOST=192.168.1.100 SOYAL_PORT=7010 soyal-visitor add QR001 "..." "..."
        \\
        \\━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        \\
        \\
    );
}