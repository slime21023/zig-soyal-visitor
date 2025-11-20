const std = @import("std");

/// 卡號驗證器
/// 卡號格式：數字:數字（例如：59488:61427）
pub const CardIdValidator = struct {
    /// 驗證卡號格式
    pub fn validate(card_id: []const u8) !void {
        // 1. 檢查是否為空
        if (card_id.len == 0) return error.EmptyCardId;

        // 2. 檢查長度上限
        if (card_id.len > 30) return error.CardIdTooLong;

        // 3. 檢查格式：必須是 "數字:數字"
        const colon_pos = std.mem.indexOf(u8, card_id, ":") orelse {
            return error.MissingColonSeparator;
        };

        // 4. 確保只有一個冒號
        if (std.mem.count(u8, card_id, ":") != 1) {
            return error.InvalidCardIdFormat;
        }

        // 5. 分割並驗證兩部分
        const first_part = card_id[0..colon_pos];
        const second_part = card_id[colon_pos + 1 ..];

        // 第一部分和第二部分都不能為空
        if (first_part.len == 0) return error.EmptyFirstPart;
        if (second_part.len == 0) return error.EmptySecondPart;

        // 6. 驗證兩部分都只包含數字
        for (first_part) |char| {
            if (char < '0' or char > '9') {
                return error.FirstPartNotNumeric;
            }
        }

        for (second_part) |char| {
            if (char < '0' or char > '9') {
                return error.SecondPartNotNumeric;
            }
        }
    }

    /// 格式化錯誤訊息
    pub fn formatError(err: anyerror) []const u8 {
        return switch (err) {
            error.EmptyCardId => "卡號不能為空",
            error.CardIdTooLong => "卡號長度超過限制（最大 30 字元）",
            error.MissingColonSeparator => "卡號格式錯誤：缺少冒號分隔符（正確格式：數字:數字，例如：59488:61427）",
            error.InvalidCardIdFormat => "卡號格式錯誤：只能包含一個冒號分隔符",
            error.EmptyFirstPart => "卡號格式錯誤：冒號前不能為空",
            error.EmptySecondPart => "卡號格式錯誤：冒號後不能為空",
            error.FirstPartNotNumeric => "卡號格式錯誤：冒號前只能是數字",
            error.SecondPartNotNumeric => "卡號格式錯誤：冒號後只能是數字",
            else => "未知的卡號驗證錯誤",
        };
    }
};

/// 時間驗證器
/// 時間格式：YYYY-MM-DD HH:MM（符合 SOYAL 701Server 規格）
pub const TimeValidator = struct {
    /// 驗證時間格式
    pub fn validate(time_str: []const u8) !void {
        // 1. 檢查長度（16 字元）
        if (time_str.len != 16) return error.InvalidTimeFormat;

        // 2. 檢查格式（位置字元）
        if (time_str[4] != '-' or time_str[7] != '-' or
            time_str[10] != ' ' or time_str[13] != ':')
        {
            return error.InvalidTimeFormat;
        }

        // 3. 解析並驗證日期時間值
        const year = std.fmt.parseInt(u16, time_str[0..4], 10) catch {
            return error.InvalidYear;
        };
        const month = std.fmt.parseInt(u8, time_str[5..7], 10) catch {
            return error.InvalidMonth;
        };
        const day = std.fmt.parseInt(u8, time_str[8..10], 10) catch {
            return error.InvalidDay;
        };
        const hour = std.fmt.parseInt(u8, time_str[11..13], 10) catch {
            return error.InvalidHour;
        };
        const minute = std.fmt.parseInt(u8, time_str[14..16], 10) catch {
            return error.InvalidMinute;
        };

        // 4. 驗證數值範圍
        if (year < 2000 or year > 2100) return error.YearOutOfRange;
        if (month < 1 or month > 12) return error.MonthOutOfRange;
        if (day < 1 or day > 31) return error.DayOutOfRange;
        if (hour > 23) return error.HourOutOfRange;
        if (minute > 59) return error.MinuteOutOfRange;
    }

    /// 驗證時間範圍（開始時間必須早於結束時間）
    pub fn validateTimeRange(start: []const u8, end: []const u8) !void {
        try validate(start);
        try validate(end);

        // 比較開始時間和結束時間
        if (std.mem.order(u8, start, end) != .lt) {
            return error.EndTimeNotAfterStartTime;
        }
    }

    /// 格式化錯誤訊息
    pub fn formatError(err: anyerror) []const u8 {
        return switch (err) {
            error.InvalidTimeFormat => "時間格式錯誤（正確格式：YYYY-MM-DD HH:MM，例如：2024-11-19 09:00）",
            error.InvalidYear => "年份格式錯誤",
            error.InvalidMonth => "月份格式錯誤",
            error.InvalidDay => "日期格式錯誤",
            error.InvalidHour => "小時格式錯誤",
            error.InvalidMinute => "分鐘格式錯誤",
            error.YearOutOfRange => "年份超出範圍（2000-2100）",
            error.MonthOutOfRange => "月份超出範圍（1-12）",
            error.DayOutOfRange => "日期超出範圍（1-31）",
            error.HourOutOfRange => "小時超出範圍（0-23）",
            error.MinuteOutOfRange => "分鐘超出範圍（0-59）",
            error.EndTimeNotAfterStartTime => "結束時間必須晚於開始時間",
            else => "未知的時間驗證錯誤",
        };
    }
};

/// Area/Node 驗證器
pub const AreaNodeValidator = struct {
    const MAX_AREA: u8 = 255;
    const MAX_NODE: u8 = 255;
    const MIN_AREA: u8 = 0;
    const MIN_NODE: u8 = 0;

    /// 驗證 Area 值
    pub fn validateArea(area: u8) !void {
        if (area < MIN_AREA or area > MAX_AREA) {
            return error.InvalidAreaValue;
        }
    }

    /// 驗證 Node 值
    pub fn validateNode(node: u8) !void {
        if (node < MIN_NODE or node > MAX_NODE) {
            return error.InvalidNodeValue;
        }
    }

    /// 格式化錯誤訊息
    pub fn formatError(err: anyerror) []const u8 {
        return switch (err) {
            error.InvalidAreaValue => "區域編號超出範圍（0-255）",
            error.InvalidNodeValue => "節點編號超出範圍（0-255）",
            else => "未知的 Area/Node 驗證錯誤",
        };
    }
};

/// 電梯樓層驗證器
pub const LiftDataValidator = struct {
    /// 驗證電梯樓層資料格式
    pub fn validate(lift_data: []const u8) !void {
        if (lift_data.len == 0) return error.EmptyLiftData;

        // 分割樓層列表
        var iter = std.mem.splitScalar(u8, lift_data, ',');
        var floor_count: usize = 0;

        while (iter.next()) |floor_str| {
            floor_count += 1;

            // 移除可能的空格
            const floor = std.mem.trim(u8, floor_str, " ");

            // 驗證單個樓層格式
            try validateFloor(floor);
        }

        // 檢查樓層數量限制
        if (floor_count > 50) return error.TooManyFloors;
        if (floor_count == 0) return error.EmptyLiftData;
    }

    /// 驗證單個樓層格式
    fn validateFloor(floor: []const u8) !void {
        if (floor.len == 0) return error.EmptyFloor;

        // 檢查地下室格式 (B1, B2, ...)
        if (floor[0] == 'B' or floor[0] == 'b') {
            if (floor.len < 2) return error.InvalidBasementFormat;
            _ = std.fmt.parseInt(u8, floor[1..], 10) catch {
                return error.InvalidBasementNumber;
            };
            return;
        }

        // 檢查數字樓層
        const floor_num = std.fmt.parseInt(u16, floor, 10) catch {
            return error.InvalidFloorNumber;
        };

        if (floor_num < 1 or floor_num > 99) {
            return error.FloorOutOfRange;
        }
    }

    /// 格式化錯誤訊息
    pub fn formatError(err: anyerror) []const u8 {
        return switch (err) {
            error.EmptyLiftData => "電梯樓層資料不能為空",
            error.TooManyFloors => "電梯樓層數量過多（最多 50 層）",
            error.EmptyFloor => "樓層編號不能為空",
            error.InvalidBasementFormat => "地下室樓層格式錯誤（正確格式：B1, B2）",
            error.InvalidBasementNumber => "地下室樓層編號必須是數字",
            error.InvalidFloorNumber => "樓層編號格式錯誤（只能是數字或 B+數字）",
            error.FloorOutOfRange => "樓層編號超出範圍（1-99）",
            else => "未知的電梯樓層驗證錯誤",
        };
    }
};

// 測試
test "CardID validation - valid formats" {
    try CardIdValidator.validate("59488:61427");
    try CardIdValidator.validate("04295:14226");
    try CardIdValidator.validate("12345:67890");
    try CardIdValidator.validate("0:0");
}

test "CardID validation - invalid formats" {
    try std.testing.expectError(error.MissingColonSeparator, CardIdValidator.validate("12345"));
    try std.testing.expectError(error.MissingColonSeparator, CardIdValidator.validate("QR123456"));
    try std.testing.expectError(error.FirstPartNotNumeric, CardIdValidator.validate("abc:123"));
    try std.testing.expectError(error.SecondPartNotNumeric, CardIdValidator.validate("123:def"));
    try std.testing.expectError(error.InvalidCardIdFormat, CardIdValidator.validate("1:2:3"));
    try std.testing.expectError(error.EmptyCardId, CardIdValidator.validate(""));
    try std.testing.expectError(error.EmptyFirstPart, CardIdValidator.validate(":123"));
    try std.testing.expectError(error.EmptySecondPart, CardIdValidator.validate("123:"));
}

test "Time validation - valid formats" {
    try TimeValidator.validate("2024-11-19 09:00");
    try TimeValidator.validate("2024-12-31 23:59");
    try TimeValidator.validate("2025-01-01 00:00");
}

test "Time validation - invalid formats" {
    try std.testing.expectError(error.InvalidTimeFormat, TimeValidator.validate("2024/11/19 09:00"));
    try std.testing.expectError(error.InvalidTimeFormat, TimeValidator.validate("2024-11-19"));
    try std.testing.expectError(error.InvalidTimeFormat, TimeValidator.validate("2024-11-19 09:00:00"));
    try std.testing.expectError(error.MonthOutOfRange, TimeValidator.validate("2024-13-01 09:00"));
    try std.testing.expectError(error.DayOutOfRange, TimeValidator.validate("2024-11-32 09:00"));
    try std.testing.expectError(error.HourOutOfRange, TimeValidator.validate("2024-11-19 24:00"));
}

test "Time range validation" {
    try TimeValidator.validateTimeRange("2024-11-19 09:00", "2024-11-19 17:00");
    try std.testing.expectError(error.EndTimeNotAfterStartTime, TimeValidator.validateTimeRange("2024-11-19 17:00", "2024-11-19 09:00"));
}

test "LiftData validation - valid formats" {
    try LiftDataValidator.validate("1,2,3,5");
    try LiftDataValidator.validate("B1,1,2,3");
    try LiftDataValidator.validate("B1,B2,1,2,3,5,10");
}

test "LiftData validation - invalid formats" {
    try std.testing.expectError(error.EmptyLiftData, LiftDataValidator.validate(""));
    try std.testing.expectError(error.InvalidFloorNumber, LiftDataValidator.validate("1,2,ABC,5"));
    try std.testing.expectError(error.FloorOutOfRange, LiftDataValidator.validate("1,2,100"));
}
