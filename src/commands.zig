const std = @import("std");
const types = @import("types.zig");
const Client = @import("client.zig").Client;

/// 新增訪客
pub fn addVisitor(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    visitor: types.Visitor,
) !void {
    std.debug.print("\n📝 新增訪客...\n", .{});
    std.debug.print("   卡片 ID: {s}\n", .{visitor.card_id});
    std.debug.print("   開始時間: {s}\n", .{visitor.start_time});
    std.debug.print("   結束時間: {s}\n", .{visitor.end_time});
    std.debug.print("   區域/節點: {d}/{d}\n\n", .{ visitor.area, visitor.node });

    // 建立指令結構
    const cmd_item = types.AddVisitorCommand.CommandItem{
        .c_cmd = 1021,
        .Area = visitor.area,
        .Node = visitor.node,
        .CardID = visitor.card_id,
        .StartTime = visitor.start_time,
        .EndTime = visitor.end_time,
    };

    var cmd_array = [_]types.AddVisitorCommand.CommandItem{cmd_item};

    const command = types.AddVisitorCommand{
        .l_user = config.username,
        .cmd_array = &cmd_array,
    };

    // 序列化為 JSON
    var json_buffer = std.ArrayList(u8).init(allocator);
    defer json_buffer.deinit();

    try std.json.stringify(command, .{}, json_buffer.writer());

    // 發送指令
    const response = try client.sendCommand(json_buffer.items);
    defer allocator.free(response);

    // 解析回應
    try handleResponse(allocator, response);
}

/// 刪除訪客
pub fn deleteVisitor(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    card_id: []const u8,
    area: u8,
    node: u8,
) !void {
    std.debug.print("\n🗑️  刪除訪客...\n", .{});
    std.debug.print("   卡片 ID: {s}\n", .{card_id});
    std.debug.print("   區域/節點: {d}/{d}\n\n", .{ area, node });

    // 建立指令結構
    const cmd_item = types.DeleteVisitorCommand.CommandItem{
        .c_cmd = 1022,
        .Area = area,
        .Node = node,
        .CardID = card_id,
    };

    var cmd_array = [_]types.DeleteVisitorCommand.CommandItem{cmd_item};

    const command = types.DeleteVisitorCommand{
        .l_user = config.username,
        .cmd_array = &cmd_array,
    };

    // 序列化為 JSON
    var json_buffer = std.ArrayList(u8).init(allocator);
    defer json_buffer.deinit();

    try std.json.stringify(command, .{}, json_buffer.writer());

    // 發送指令
    const response = try client.sendCommand(json_buffer.items);
    defer allocator.free(response);

    // 解析回應
    try handleResponse(allocator, response);
}

/// 使用 command 2000 新增訪客（支援電梯樓層）
pub fn addVisitorWithLift(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    visitor: types.VisitorWithLift,
) !void {
    std.debug.print("\n📝 新增訪客（含電梯樓層）...\n", .{});
    std.debug.print("   卡片 ID: {s}\n", .{visitor.card_id});
    std.debug.print("   開始時間: {s}\n", .{visitor.start_time});
    std.debug.print("   結束時間: {s}\n", .{visitor.end_time});
    std.debug.print("   區域/節點: {d}/{d}\n", .{ visitor.area, visitor.node });
    if (visitor.lift_floors) |floors| {
        std.debug.print("   電梯樓層: {s}\n\n", .{floors});
    } else {
        std.debug.print("   電梯樓層: (未設定)\n\n", .{});
    }

    // 建立 command 2000 通用指令結構
    const cmd_item = types.UniversalCommand.CommandItem{
        .c_cmd = 2000,
        .Area = visitor.area,
        .Node = visitor.node,
        .CardID = visitor.card_id,
        .StartTime = visitor.start_time,
        .EndTime = visitor.end_time,
        .LiftData = visitor.lift_floors,
    };

    var cmd_array = [_]types.UniversalCommand.CommandItem{cmd_item};

    const command = types.UniversalCommand{
        .l_user = config.username,
        .cmd_array = &cmd_array,
    };

    // 序列化為 JSON
    var json_buffer = std.ArrayList(u8).init(allocator);
    defer json_buffer.deinit();

    try std.json.stringify(command, .{}, json_buffer.writer());

    std.debug.print("🔍 發送指令: {s}\n\n", .{json_buffer.items});

    // 發送指令
    const response = try client.sendCommand(json_buffer.items);
    defer allocator.free(response);

    // 解析回應
    try handleResponse(allocator, response);
}

/// 處理伺服器回應
fn handleResponse(allocator: std.mem.Allocator, response_data: []const u8) !void {
    const parsed = std.json.parseFromSlice(
        types.Response,
        allocator,
        response_data,
        .{ .allocate = .alloc_always },
    ) catch |err| {
        std.debug.print("❌ 錯誤: 無法解析伺服器回應\n", .{});
        std.debug.print("   原因: {s}\n", .{@errorName(err)});
        std.debug.print("   回應內容: {s}\n", .{response_data});
        std.debug.print("\n   建議:\n", .{});
        std.debug.print("   1. 確認 701ServerSQL 版本是否支援此指令\n", .{});
        std.debug.print("   2. 檢查伺服器回應格式是否正確\n", .{});
        std.debug.print("   3. 聯繫系統管理員確認伺服器設定\n\n", .{});
        return err;
    };
    defer parsed.deinit();

    const response = parsed.value;

    if (response.resp_array.len == 0) {
        std.debug.print("⚠️  警告: 沒有收到回應資料\n", .{});
        std.debug.print("   建議: 請確認指令是否正確發送到伺服器\n\n", .{});
        return;
    }

    for (response.resp_array) |item| {
        std.debug.print("📊 回應狀態:\n", .{});
        std.debug.print("   指令代碼: {d}\n", .{item.c_cmd});
        std.debug.print("   執行結果: {d} ", .{item.c_resp});

        switch (item.c_resp) {
            3 => std.debug.print("(✅ 成功)\n", .{}),
            0 => {
                std.debug.print("(❌ 失敗 - 一般錯誤)\n", .{});
                std.debug.print("\n   可能原因:\n", .{});
                std.debug.print("   - 卡片 ID 格式不正確\n", .{});
                std.debug.print("   - 時間格式錯誤\n", .{});
                std.debug.print("   - 權限不足\n\n", .{});
            },
            1 => {
                std.debug.print("(❌ 失敗 - 參數錯誤)\n", .{});
                std.debug.print("   建議: 請檢查區域/節點編號是否正確\n\n", .{});
            },
            2 => {
                std.debug.print("(❌ 失敗 - 資料庫錯誤)\n", .{});
                std.debug.print("   建議: 請聯繫系統管理員檢查資料庫狀態\n\n", .{});
            },
            else => {
                std.debug.print("(❌ 失敗 - 未知錯誤碼)\n", .{});
                std.debug.print("   建議: 請參閱 SOYAL 官方文件\n\n", .{});
            },
        }

        std.debug.print("   區域/節點: {d}/{d}\n", .{ item.Area, item.Node });
        
        if (item.Hex) |hex_data| {
            std.debug.print("   額外資訊: {s}\n", .{hex_data});
        }
        std.debug.print("\n", .{});
    }
}