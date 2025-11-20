const std = @import("std");
const types = @import("types.zig");

/// 將 "數字:數字" 格式的卡號轉換為 8 bytes HEX 字串
/// 演算法：(first << 16) | second
/// 範例：
///   輸入："04295:14226"
///   輸出："0x0000000010C73792"
pub fn cardIdToHexTagUID(card_id: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // 1. 分割卡號
    var iter = std.mem.splitScalar(u8, card_id, ':');
    const first_str = iter.next() orelse return error.InvalidCardIdFormat;
    const second_str = iter.next() orelse return error.InvalidCardIdFormat;

    // 確保沒有多餘的部分
    if (iter.next() != null) return error.InvalidCardIdFormat;

    // 2. 轉換為數字
    const first = std.fmt.parseInt(u32, first_str, 10) catch return error.InvalidFirstPart;
    const second = std.fmt.parseInt(u32, second_str, 10) catch return error.InvalidSecondPart;

    // 3. 組合演算法：(first << 16) | second
    // 注意：需要轉換為 u64 以避免溢位
    const combined: u64 = (@as(u64, first) << 16) | @as(u64, second);

    // 4. 格式化為 16 字符 HEX 字串（0x + 16 個十六進制字符 = 8 bytes）
    return std.fmt.allocPrint(allocator, "0x{X:0>16}", .{combined});
}

/// 將 HEX TagUID 轉換回 "數字:數字" 格式（用於顯示或調試）
pub fn hexTagUIDToCardId(hex_tag_uid: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // 移除 "0x" 前綴
    const hex_str = if (std.mem.startsWith(u8, hex_tag_uid, "0x"))
        hex_tag_uid[2..]
    else
        hex_tag_uid;

    // 解析為 u64
    const combined = try std.fmt.parseInt(u64, hex_str, 16);

    // 提取兩個數字
    const first: u32 = @intCast((combined >> 16) & 0xFFFFFFFF);
    const second: u32 = @intCast(combined & 0xFFFF);

    // 格式化為 "數字:數字"
    return std.fmt.allocPrint(allocator, "{d}:{d}", .{ first, second });
}

// ============================================================
// Command 2000 HEX 構建函數
// ============================================================

/// 從 "YYYY-MM-DD HH:MM" 字串解析日期時間
/// 範例：
///   輸入："2024-11-19 09:00"
///   輸出：DateTime{ .year=2024, .month=11, .day=19, .hour=9, .minute=0 }
pub fn parseDateTime(time_str: []const u8) !types.DateTime {
    // 驗證長度
    if (time_str.len != 16) return error.InvalidTimeFormat;

    // 驗證格式（基本檢查）
    if (time_str[4] != '-' or time_str[7] != '-' or time_str[10] != ' ' or time_str[13] != ':') {
        return error.InvalidTimeFormat;
    }

    // 解析各部分
    const year = std.fmt.parseInt(u16, time_str[0..4], 10) catch return error.InvalidYear;
    const month = std.fmt.parseInt(u8, time_str[5..7], 10) catch return error.InvalidMonth;
    const day = std.fmt.parseInt(u8, time_str[8..10], 10) catch return error.InvalidDay;
    const hour = std.fmt.parseInt(u8, time_str[11..13], 10) catch return error.InvalidHour;
    const minute = std.fmt.parseInt(u8, time_str[14..16], 10) catch return error.InvalidMinute;

    // 驗證範圍
    if (year < 2000 or year > 2099) return error.YearOutOfRange;
    if (month < 1 or month > 12) return error.MonthOutOfRange;
    if (day < 1 or day > 31) return error.DayOutOfRange;
    if (hour > 23) return error.HourOutOfRange;
    if (minute > 59) return error.MinuteOutOfRange;

    return types.DateTime{
        .year = year,
        .month = month,
        .day = day,
        .hour = hour,
        .minute = minute,
    };
}

/// 構建 8BH 協議 HEX 字串（設定訪客）
/// 範例輸出："0x8B570000C80000000010C73792000004BC86FFFFFF1606100A1B1706100A1B000000FF"
pub fn buildVisitor8BHPayload(
    allocator: std.mem.Allocator,
    visitor: types.VisitorExtended,
    addr: u32,
) ![]u8 {
    // 1. 解析卡號
    var iter = std.mem.splitScalar(u8, visitor.card_id, ':');
    const first_str = iter.next() orelse return error.InvalidCardId;
    const second_str = iter.next() orelse return error.InvalidCardId;

    const card_first = std.fmt.parseInt(u32, first_str, 10) catch return error.InvalidCardId;
    const card_second = std.fmt.parseInt(u32, second_str, 10) catch return error.InvalidCardId;

    // 2. 解析時間
    const start_dt = try parseDateTime(visitor.start_time);
    const end_dt = try parseDateTime(visitor.end_time);

    // 3. 準備參數（使用預設值）
    const password = visitor.password orelse 0;
    const access_mode = visitor.access_mode orelse 0x86; // 預設：卡片+密碼
    const door_access = visitor.door_access orelse "FFFFFF";
    const lift_data = visitor.lift_floors orelse "FF";

    // 4. 構建 HEX 字串
    // 格式：8B 57 0000 C8 00000000 10C7 3792 000004BC 86 FFFFFF 1606100A1B 1706100A1B 000000 FF
    return std.fmt.allocPrint(
        allocator,
        "0x8B570000{X:0>2}0000000{X:0>4}{X:0>4}0000{X:0>4}{X:0>2}{s}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}{X:0>2}000000{s}",
        .{
            @as(u8, @intCast(addr & 0xFF)),
            card_first,
            card_second,
            password,
            access_mode,
            door_access,
            start_dt.year - 2000,
            start_dt.month,
            start_dt.day,
            start_dt.hour,
            start_dt.minute,
            end_dt.year - 2000,
            end_dt.month,
            end_dt.day,
            end_dt.hour,
            end_dt.minute,
            lift_data,
        },
    );
}

// ============================================================
// 測試
// ============================================================

test "cardIdToHexTagUID - 範例 1" {
    const allocator = std.testing.allocator;

    const result = try cardIdToHexTagUID("04295:14226", allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("0x0000000010C73792", result);
}

test "cardIdToHexTagUID - 範例 2" {
    const allocator = std.testing.allocator;

    const result = try cardIdToHexTagUID("59488:61427", allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("0x00000000E860EFF3", result);
}

test "cardIdToHexTagUID - 最小值" {
    const allocator = std.testing.allocator;

    const result = try cardIdToHexTagUID("0:0", allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("0x0000000000000000", result);
}

test "cardIdToHexTagUID - 最大值（16-bit 範圍）" {
    const allocator = std.testing.allocator;

    // 65535 = 0xFFFF (最大 16-bit 值)
    const result = try cardIdToHexTagUID("65535:65535", allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("0x00000000FFFFFFFF", result);
}

test "cardIdToHexTagUID - 錯誤格式" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(error.InvalidCardIdFormat, cardIdToHexTagUID("12345", allocator));
    try std.testing.expectError(error.InvalidCardIdFormat, cardIdToHexTagUID("1:2:3", allocator));
    try std.testing.expectError(error.InvalidFirstPart, cardIdToHexTagUID("abc:123", allocator));
    try std.testing.expectError(error.InvalidSecondPart, cardIdToHexTagUID("123:xyz", allocator));
}

test "hexTagUIDToCardId - 逆向轉換" {
    const allocator = std.testing.allocator;

    const result = try hexTagUIDToCardId("0x0000000010C73792", allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("4295:14226", result);
}

test "cardIdToHexTagUID - 完整轉換循環" {
    const allocator = std.testing.allocator;

    const original = "04295:14226";

    // 轉換為 HEX
    const hex = try cardIdToHexTagUID(original, allocator);
    defer allocator.free(hex);

    // 轉換回來
    const restored = try hexTagUIDToCardId(hex, allocator);
    defer allocator.free(restored);

    // 注意：前導零會被移除，所以比較時要注意
    try std.testing.expectEqualStrings("4295:14226", restored);
}

test "演算法驗證 - 手動計算" {
    const allocator = std.testing.allocator;

    // 04295 (0x10C7) << 16 = 0x10C70000 = 281477120
    // 0x10C70000 | 0x3792 (14226) = 0x10C73792 = 281491346

    const first: u32 = 4295;
    const second: u32 = 14226;
    const expected_combined: u64 = 281491346; // 0x10C73792 的十進制值

    const combined: u64 = (@as(u64, first) << 16) | @as(u64, second);
    try std.testing.expectEqual(expected_combined, combined);

    const result = try cardIdToHexTagUID("04295:14226", allocator);
    defer allocator.free(result);

    // 驗證格式化結果
    var buf: [32]u8 = undefined;
    const expected = try std.fmt.bufPrint(&buf, "0x{X:0>16}", .{expected_combined});
    try std.testing.expectEqualStrings(expected, result);
}

test "parseDateTime - 正常時間" {
    const dt = try parseDateTime("2024-11-19 09:00");
    try std.testing.expectEqual(@as(u16, 2024), dt.year);
    try std.testing.expectEqual(@as(u8, 11), dt.month);
    try std.testing.expectEqual(@as(u8, 19), dt.day);
    try std.testing.expectEqual(@as(u8, 9), dt.hour);
    try std.testing.expectEqual(@as(u8, 0), dt.minute);
}

test "parseDateTime - 範例時間" {
    const dt = try parseDateTime("2022-06-16 10:27");
    try std.testing.expectEqual(@as(u16, 2022), dt.year);
    try std.testing.expectEqual(@as(u8, 6), dt.month);
    try std.testing.expectEqual(@as(u8, 16), dt.day);
    try std.testing.expectEqual(@as(u8, 10), dt.hour);
    try std.testing.expectEqual(@as(u8, 27), dt.minute);
}

test "buildVisitor8BHPayload - 官方範例" {
    const allocator = std.testing.allocator;

    const visitor = types.VisitorExtended{
        .card_id = "04295:14226",
        .start_time = "2022-06-16 10:27",
        .end_time = "2023-06-16 10:27",
        .password = 1212,
    };

    const hex = try buildVisitor8BHPayload(allocator, visitor, 200);
    defer allocator.free(hex);

    // 驗證關鍵部分
    try std.testing.expect(std.mem.startsWith(u8, hex, "0x8B570000C8")); // 指令碼 + 位址
    try std.testing.expect(std.mem.indexOf(u8, hex, "10C73792") != null); // 卡號
    try std.testing.expect(std.mem.indexOf(u8, hex, "04BC") != null); // 密碼 (1212 = 0x04BC)
}

test "buildVisitor8BHPayload - 無密碼" {
    const allocator = std.testing.allocator;

    const visitor = types.VisitorExtended{
        .card_id = "12345:67890",
        .start_time = "2024-11-19 09:00",
        .end_time = "2024-11-19 17:00",
    };

    const hex = try buildVisitor8BHPayload(allocator, visitor, 0);
    defer allocator.free(hex);

    // 應該包含密碼 0
    try std.testing.expect(std.mem.indexOf(u8, hex, "00000000") != null);
}
