const std = @import("std");
const terminal = @import("terminal.zig");
const screen = @import("screen.zig");
const keys = @import("keys.zig");

pub fn main() !void {
    const terminal_instance = try terminal.Terminal.init();
    const screen_instance = screen.Screen.init(terminal_instance);

    try terminal_instance.clear_screen();
    try terminal_instance.enable_raw_mode();
    try terminal_instance.move_to_alt_screen();
    const input_starting_coordinates = try screen_instance.home();
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
            .character => {
                try terminal_instance.write(&.{key.character});
            },
            .new_line => {
                try terminal_instance.write("\n");
            },
        }
    }
}
