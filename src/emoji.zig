const std = @import("std");

const emoji_json = @embedFile("./emojis.json");

const Emoji = struct { emoji: []const u8, description: []const u8 };

var emoji_list: []Emoji = &.{};

pub fn get_emojis() []Emoji {
    if (emoji_list.len == 0) {
        const parsed = std.json.parseFromSlice([]Emoji, std.heap.page_allocator, emoji_json, .{}) catch unreachable;

        emoji_list = parsed.value;
    }

    return emoji_list;
}

pub fn get_matching_input(allocator: std.mem.Allocator, input: std.ArrayList(u8)) ![]Emoji {
    var filtered = std.ArrayList(Emoji).init(allocator);
    defer filtered.deinit();

    const all_emojis = get_emojis();

    var input_words_iterator = std.mem.splitSequence(u8, input.items, " ");

    while (input_words_iterator.next()) |input_word| {
        for (all_emojis) |emoji| {
            var description_word_iterator = std.mem.splitSequence(u8, emoji.description, " ");

            while (description_word_iterator.next()) |description_word| {
                const index_of_input_word = std.ascii.indexOfIgnoreCase(description_word, input_word);

                if (index_of_input_word != null and index_of_input_word == 0) {
                    _ = try filtered.append(emoji);
                }
            }
        }
    }

    return try filtered.toOwnedSlice();
}

const expect = std.testing.expect;

test "get_matching_input works for full input" {
    const allocator = std.testing.allocator;

    var input = std.ArrayList(u8).init(allocator);
    defer input.deinit();

    try input.appendSlice("Romania");

    const matching = try get_matching_input(allocator, input);
    defer allocator.free(matching);

    const expected_emoji = "🇷🇴";
    const expected_description = "flag: Romania";

    const value = matching[0];

    try expect(std.mem.eql(u8, value.emoji, expected_emoji));
    try expect(std.mem.eql(u8, value.description, expected_description));
}

test "get_maching_input works for partial input" {
    const allocator = std.testing.allocator;

    var input = std.ArrayList(u8).init(allocator);
    defer input.deinit();

    try input.appendSlice("rom");

    const matching = try get_matching_input(allocator, input);
    defer allocator.free(matching);

    const expected_emoji = "🇷🇴";
    const expected_description = "flag: Romania";

    const value = matching[0];

    try expect(std.mem.eql(u8, value.emoji, expected_emoji));
    try expect(std.mem.eql(u8, value.description, expected_description));
}
