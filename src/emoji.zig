const std = @import("std");

const emoji_json = @embedFile("./emojis.json");

const Emoji = struct { emoji: []u8, description: []u8 };

var emoji_list: []Emoji = &.{};

pub fn get_emojis() []Emoji {
    if (emoji_list.len == 0) {
        const parsed = std.json.parseFromSlice([]Emoji, std.heap.page_allocator, emoji_json, .{}) catch unreachable;

        emoji_list = parsed.value;
    }

    return emoji_list;
}
