const std = @import("std");
const types = @import("types.zig");
const Client = @import("client.zig").Client;
const validators = @import("validators.zig");
const converters = @import("converters.zig");

/// 新增訪客
pub fn addVisitor(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    visitor: types.Visitor,
) !void {
    // 驗證輸入參數
    validators.CardIdValidator.validate(visitor.card_id) catch |err| {
        std.debug.print("\n❌ {s}\n", .{validators.CardIdValidator.formatError(err)});
        std.debug.print("   您輸入的卡號: {s}\n", .{visitor.card_id});
        std.debug.print("   範例格式: 59488:61427\n\n", .{});
        return err;
    };

    validators.TimeValidator.validateTimeRange(visitor.start_time, visitor.end_time) catch |err| {
        std.debug.print("\n❌ {s}\n", .{validators.TimeValidator.formatError(err)});
        std.debug.print("   開始時間: {s}\n", .{visitor.start_time});
        std.debug.print("   結束時間: {s}\n\n", .{visitor.end_time});
        return err;
    };

    try validators.AreaNodeValidator.validateArea(visitor.area);
    try validators.AreaNodeValidator.validateNode(visitor.node);

    // 轉換卡號為 HEX TagUID（符合 SOYAL 規格）
    const hex_tag_uid = try converters.cardIdToHexTagUID(visitor.card_id, allocator);
    defer allocator.free(hex_tag_uid);

    std.debug.print("\n📝 新增訪客...\n", .{});
    std.debug.print("   卡片 ID: {s}\n", .{visitor.card_id});
    std.debug.print("   TagUID (HEX): {s}\n", .{hex_tag_uid});
    std.debug.print("   開始時間: {s}\n", .{visitor.start_time});
    std.debug.print("   結束時間: {s}\n", .{visitor.end_time});
    std.debug.print("   區域/節點: {d}/{d}\n\n", .{ visitor.area, visitor.node });

    // 建立指令結構（符合官方規格）
    const cmd_item = types.AddVisitorCommand.CommandItem{
        .c_cmd = 1021,
        .Area = visitor.area,
        .Node = visitor.node,
        .Addr = 0, // 位址預設為 0
        .TagUID = hex_tag_uid, // 使用轉換後的 HEX 格式
        .Begin_dt = visitor.start_time,
        .End_dt = visitor.end_time,
    };

    var cmd_array = [_]types.AddVisitorCommand.CommandItem{cmd_item};

    const command = types.AddVisitorCommand{
        .l_user = config.username,
        .cmd_array = &cmd_array,
    };

    // 序列化為 JSON
    var json_out: std.io.Writer.Allocating = .init(allocator);
    defer json_out.deinit();
    try std.json.Stringify.value(command, .{}, &json_out.writer);
    const json_buffer = json_out.written();

    std.debug.print("🔍 JSON 輸出:\n{s}\n\n", .{json_buffer});

    // 發送指令
    const response = try client.sendCommand(json_buffer);
    defer allocator.free(response);

    // 解析回應
    try handleResponse(allocator, response);
}

/// 刪除訪客
pub fn deleteVisitor(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    area: u8,
    node: u8,
) !void {
    // 驗證輸入參數
    try validators.AreaNodeValidator.validateArea(area);
    try validators.AreaNodeValidator.validateNode(node);

    std.debug.print("\n🗑️  刪除訪客...\n", .{});
    std.debug.print("   位址: 0 (固定)\n", .{});
    std.debug.print("   區域/節點: {d}/{d}\n\n", .{ area, node });

    // 建立指令結構（符合官方規格）
    // 注意：1022 命令不需要 TagUID，只需要 Addr
    const cmd_item = types.DeleteVisitorCommand.CommandItem{
        .c_cmd = 1022,
        .Area = area,
        .Node = node,
        .Addr = 0, // 位址預設為 0
    };

    var cmd_array = [_]types.DeleteVisitorCommand.CommandItem{cmd_item};

    const command = types.DeleteVisitorCommand{
        .l_user = config.username,
        .cmd_array = &cmd_array,
    };

    // 序列化為 JSON
    var json_out: std.io.Writer.Allocating = .init(allocator);
    defer json_out.deinit();
    try std.json.Stringify.value(command, .{}, &json_out.writer);
    const json_buffer = json_out.written();

    std.debug.print("🔍 JSON 輸出:\n{s}\n\n", .{json_buffer});

    // 發送指令
    const response = try client.sendCommand(json_buffer);
    defer allocator.free(response);

    // 解析回應
    try handleResponse(allocator, response);
}

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
        std.debug.print("\n❌ 錯誤: HEX 字串必須以 '0x' 開頭\n", .{});
        std.debug.print("   您輸入的值: {s}\n", .{hex_payload});
        std.debug.print("   正確格式: 0x8B570000C8...\n\n", .{});
        return error.InvalidHexFormat;
    }

    try validators.AreaNodeValidator.validateArea(area);
    try validators.AreaNodeValidator.validateNode(node);

    std.debug.print("\n📡 發送原始協議指令...\n", .{});
    std.debug.print("   區域: {d}\n", .{area});
    std.debug.print("   節點: {d}\n", .{node});
    std.debug.print("   HEX Payload: {s}\n\n", .{hex_payload});

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

    // 序列化為 JSON
    var json_out: std.io.Writer.Allocating = .init(allocator);
    defer json_out.deinit();
    try std.json.Stringify.value(command, .{}, &json_out.writer);
    const json_buffer = json_out.written();

    std.debug.print("🔍 JSON 輸出:\n{s}\n\n", .{json_buffer});

    // 發送指令
    const response = try client.sendCommand(json_buffer);
    defer allocator.free(response);

    // 解析回應
    try handleResponse(allocator, response);
}

/// 新增訪客（使用 Command 2000，支援密碼等高級功能）
pub fn addVisitorExtended(
    allocator: std.mem.Allocator,
    client: *Client,
    config: types.Config,
    visitor: types.VisitorExtended,
    addr: u32,
) !void {
    // 驗證輸入參數
    validators.CardIdValidator.validate(visitor.card_id) catch |err| {
        std.debug.print("\n❌ {s}\n", .{validators.CardIdValidator.formatError(err)});
        std.debug.print("   您輸入的卡號: {s}\n", .{visitor.card_id});
        std.debug.print("   範例格式: 59488:61427\n\n", .{});
        return err;
    };

    validators.TimeValidator.validateTimeRange(visitor.start_time, visitor.end_time) catch |err| {
        std.debug.print("\n❌ {s}\n", .{validators.TimeValidator.formatError(err)});
        std.debug.print("   開始時間: {s}\n", .{visitor.start_time});
        std.debug.print("   結束時間: {s}\n\n", .{visitor.end_time});
        return err;
    };

    try validators.AreaNodeValidator.validateArea(visitor.area);
    try validators.AreaNodeValidator.validateNode(visitor.node);

    // 構建 HEX payload
    const hex_payload = try converters.buildVisitor8BHPayload(allocator, visitor, addr);
    defer allocator.free(hex_payload);

    std.debug.print("\n📝 新增訪客（擴展功能 - Command 2000）...\n", .{});
    std.debug.print("   卡片 ID: {s}\n", .{visitor.card_id});
    std.debug.print("   位址: {d}\n", .{addr});
    std.debug.print("   開始時間: {s}\n", .{visitor.start_time});
    std.debug.print("   結束時間: {s}\n", .{visitor.end_time});
    if (visitor.password) |pwd| {
        std.debug.print("   密碼: {d}\n", .{pwd});
    }
    if (visitor.access_mode) |mode| {
        std.debug.print("   通行模式: 0x{X:0>2}\n", .{mode});
    }
    if (visitor.door_access) |access| {
        std.debug.print("   門禁權限: {s}\n", .{access});
    }
    if (visitor.lift_floors) |floors| {
        std.debug.print("   電梯樓層: {s}\n", .{floors});
    }
    std.debug.print("   HEX Payload: {s}\n\n", .{hex_payload});

    // 發送原始協議
    try sendRawProtocol(allocator, client, config, visitor.area, visitor.node, hex_payload);
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
