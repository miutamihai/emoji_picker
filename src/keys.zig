const std = @import("std");

pub const KeyType = enum {
    sig_term,
    character,
    new_line,
    backspace,
    unknown,

    control,

    const Self = @This();

    // TODO: Change this massive shit
    pub fn from_byte(byte: u8) Self {
        if (byte == 3) {
            return .sig_term;
        }

        if (byte == 13) {
            return .new_line;
        }

        if (byte == 127) {
            return .backspace;
        }

        if (byte >= 'A' and byte <= 'z') {
            return .character;
        }

        if (byte == '\x1B') {
            return .control;
        }

        return .unknown;
    }
};

pub const ControlKey = enum {
    arrow_up,
    arrow_down,
    arrow_right,
    arrow_left,

    unknown,

    const Self = @This();

    pub fn from_byte(byte: u8) Self {
        return switch (byte) {
            'A' => .arrow_up,
            'B' => .arrow_down,
            'C' => .arrow_right,
            'D' => .arrow_left,

            else => .unknown,
        };
    }
};

pub const Key = struct {
    key_type: KeyType,
    character: u8,

    pub fn init(byte: u8) Key {
        const key_type = KeyType.from_byte(byte);

        return .{ .key_type = key_type, .character = byte };
    }
};
