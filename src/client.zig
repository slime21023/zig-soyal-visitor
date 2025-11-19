const std = @import("std");
const types = @import("types.zig");

pub const Client = struct {
    allocator: std.mem.Allocator,
    host: []const u8,
    port: u16,

    pub fn init(allocator: std.mem.Allocator, host: []const u8, port: u16) Client {
        return .{
            .allocator = allocator,
            .host = host,
            .port = port,
        };
    }

    /// 發送 JSON 指令到 701ServerSQL
    pub fn sendCommand(self: *Client, json_data: []const u8) ![]u8 {
        // 解析主機位址
        const address = std.net.Address.parseIp(self.host, self.port) catch |err| {
            std.debug.print("\n❌ 錯誤: 無效的主機位址\n", .{});
            std.debug.print("   主機: {s}\n", .{self.host});
            std.debug.print("   連接埠: {d}\n", .{self.port});
            std.debug.print("   建議: 請檢查 SOYAL_HOST 環境變數或預設主機位址\n\n", .{});
            return err;
        };
        
        // 建立 TCP 連線
        const stream = std.net.tcpConnectToAddress(address) catch |err| {
            std.debug.print("\n❌ 錯誤: 無法連線到 701ServerSQL\n", .{});
            std.debug.print("   主機: {s}\n", .{self.host});
            std.debug.print("   連接埠: {d}\n", .{self.port});
            
            switch (err) {
                error.ConnectionRefused => {
                    std.debug.print("   原因: 連線被拒絕（伺服器未運行）\n", .{});
                    std.debug.print("\n   建議:\n", .{});
                    std.debug.print("   1. 確認 701ServerSQL 服務正在運行\n", .{});
                    std.debug.print("   2. 檢查防火牆設定是否阻擋連接埠 {d}\n", .{self.port});
                    std.debug.print("   3. 確認主機位址和連接埠是否正確\n\n", .{});
                },
                error.NetworkUnreachable => {
                    std.debug.print("   原因: 網路無法到達\n", .{});
                    std.debug.print("\n   建議:\n", .{});
                    std.debug.print("   1. 檢查網路連線是否正常\n", .{});
                    std.debug.print("   2. 確認目標主機是否在線\n", .{});
                    std.debug.print("   3. 檢查網路設定（IP、子網路遮罩、閘道）\n\n", .{});
                },
                error.ConnectionTimedOut => {
                    std.debug.print("   原因: 連線逾時\n", .{});
                    std.debug.print("\n   建議:\n", .{});
                    std.debug.print("   1. 檢查目標主機是否回應\n", .{});
                    std.debug.print("   2. 確認網路延遲是否過高\n", .{});
                    std.debug.print("   3. 嘗試 ping {s} 確認連通性\n\n", .{self.host});
                },
                else => {
                    std.debug.print("   原因: {s}\n", .{@errorName(err)});
                    std.debug.print("\n   建議: 請檢查網路設定和伺服器狀態\n\n", .{});
                },
            }
            return err;
        };
        defer stream.close();

        std.debug.print("✓ 已連線到 {s}:{d}\n", .{ self.host, self.port });

        // 發送 JSON 資料
        stream.writeAll(json_data) catch |err| {
            std.debug.print("\n❌ 錯誤: 發送資料失敗\n", .{});
            std.debug.print("   原因: {s}\n", .{@errorName(err)});
            std.debug.print("   建議: 連線可能已中斷，請重試\n\n", .{});
            return err;
        };
        std.debug.print("✓ 已發送指令\n", .{});

        // 接收回應
        var buffer: [4096]u8 = undefined;
        const bytes_read = stream.read(&buffer) catch |err| {
            std.debug.print("\n❌ 錯誤: 接收回應失敗\n", .{});
            std.debug.print("   原因: {s}\n", .{@errorName(err)});
            std.debug.print("   建議: 伺服器可能未正常回應\n\n", .{});
            return err;
        };
        
        if (bytes_read == 0) {
            std.debug.print("\n❌ 錯誤: 伺服器未回應任何資料\n", .{});
            std.debug.print("   建議: 請確認 701ServerSQL 服務運作正常\n\n", .{});
            return error.NoResponse;
        }

        const response = try self.allocator.dupe(u8, buffer[0..bytes_read]);
        std.debug.print("✓ 收到回應 ({d} bytes)\n\n", .{bytes_read});

        return response;
    }

    /// 解析伺服器回應
    pub fn parseResponse(self: *Client, response_data: []const u8) !types.Response {
        const parsed = try std.json.parseFromSlice(
            types.Response,
            self.allocator,
            response_data,
            .{ .allocate = .alloc_always },
        );
        defer parsed.deinit();

        return parsed.value;
    }
};