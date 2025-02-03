const std = @import("std");
const terminal = @import("terminal.zig");
const screen = @import("screen.zig");
const keys = @import("keys.zig");

pub fn main() !void {
    const terminal_instance = try terminal.Terminal.init();
    var screen_instance = screen.Screen.init(terminal_instance);

    try terminal_instance.clear_screen();
    try terminal_instance.enable_raw_mode();
    try terminal_instance.move_to_alt_screen();
    var input_starting_coordinates = try screen_instance.navigate(screen.ScreenType.home);
    try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
    try terminal_instance.change_cursor_shape();

    const stdin = std.io.getStdIn().reader();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    var input = std.ArrayList(u8).init(gpa);

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
                    input_starting_coordinates = try screen_instance.navigate(screen.ScreenType.home);
                    try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
                }
            },
            .character => {
                if (screen_instance.current_screen == screen.ScreenType.home) {
                    input_starting_coordinates = try screen_instance.navigate(screen.ScreenType.search);
                    try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
                }

                try input.append(key.character);
                try terminal_instance.write(&.{key.character});
            },
            .new_line => {
                try terminal_instance.write("\n");
            },
            .unknown => {
                continue;
            },
        }
    }
}
