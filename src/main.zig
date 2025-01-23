const std = @import("std");
const terminal = @import("terminal.zig");
const screen = @import("screen.zig");

pub fn main() !void {
    const terminal_instance = terminal.Terminal.init();
    const screen_instance = screen.Screen.init(terminal_instance);

    try terminal_instance.clear_screen();
    const input_starting_coordinates = try screen_instance.home();
    try terminal_instance.move_cursor_to_coordinates(input_starting_coordinates);
    try terminal_instance.change_cursor_shape();

    const stdin = std.io.getStdIn().reader();

    const bare_line = try stdin.readUntilDelimiterAlloc(
        std.heap.page_allocator,
        '\n',
        8192,
    );
    defer std.heap.page_allocator.free(bare_line);
}
