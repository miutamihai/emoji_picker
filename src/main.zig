const std = @import("std");
const terminal = @import("terminal.zig");
const screen = @import("screen.zig");
const keys = @import("keys.zig");

const c = @cImport(@cInclude("locale.h"));

pub fn main() !void {
    _ = c.setlocale(c.LC_CTYPE, ".UTF8");

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(general_purpose_allocator.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    const terminal_instance = try terminal.Terminal.init(allocator);
    var screen_instance = try screen.Screen.init(allocator, terminal_instance);

    var input = std.ArrayList(u8).init(allocator);

    try terminal_instance.clear_screen();
    try terminal_instance.enable_raw_mode();
    try terminal_instance.move_to_alt_screen();
    var input_starting_coordinates = try screen_instance.navigate(screen.ScreenType.home, input);
    try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
    try terminal_instance.change_cursor_shape();

    const stdin = std.io.getStdIn().reader();

    while (true) {
        const byte = try stdin.readByte();
        const key = keys.Key.init(byte);

        switch (key.key_type) {
            .sig_term => {
                try terminal_instance.disable_raw_mode();
                try terminal_instance.move_to_original_screen();

                break;
            },
            .backspace => {
                if (input.items.len == 0) {
                    continue;
                }

                _ = input.popOrNull();
                try terminal_instance.delete_character();

                if (screen_instance.current_screen == screen.ScreenType.search and input.items.len == 0) {
                    input_starting_coordinates = try screen_instance.navigate(screen.ScreenType.home, input);
                } else {
                    input_starting_coordinates = try screen_instance.navigate(screen.ScreenType.search, input);
                }

                try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
            },
            .character => {
                try input.append(key.character);

                input_starting_coordinates = try screen_instance.navigate(screen.ScreenType.search, input);
                try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
            },
            .new_line => {
                try terminal_instance.write("\n");
            },
            .control => {
                // We skip the [ character that follows the control
                // byte
                _ = try stdin.readByte();

                const control_key = keys.ControlKey.from_byte(try stdin.readByte());

                switch (control_key) {
                    .arrow_up => {
                        try screen_instance.change_highlight(-1);

                        try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
                    },
                    .arrow_down => {
                        try screen_instance.change_highlight(1);

                        try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
                    },
                    else => {
                        continue;
                    },
                }
            },
            .unknown => {
                continue;
            },
        }
    }
}
