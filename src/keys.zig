pub const KeyType = enum {
    sig_term,
    character,
    new_line,
    backspace,

    // TODO: Change this massive shit
    pub fn from_byte(byte: u8) KeyType {
        if (byte == 3) {
            return .sig_term;
        }

        if (byte == 13) {
            return .new_line;
        }

        if (byte == 127) {
            return .backspace;
        }

        return .character;
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
