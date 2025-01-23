const std = @import("std");
const posix = std.posix;
const ui_drawer = @import("ui_drawer.zig");

const TerminalCodes = enum {
    clear,
    cursor_home,
    move_cursor,
    change_cursor_to_bar,

    pub fn str(self: TerminalCodes) [:0]const u8 {
        return switch (self) {
            .clear => "\x1B[2J",
            .cursor_home => "\x1B[H",
            .move_cursor => "\x1B[{d};{d}H",
            .change_cursor_to_bar => "\x1B[6 q",
        };
    }
};

// TODO: Change all these writes to use buffers

fn reset_cursor_position(terminal: std.fs.File) !void {
    _ = try terminal.writeAll(TerminalCodes.cursor_home.str());
}

fn clear_screen(terminal: std.fs.File) !void {
    _ = try terminal.writeAll(TerminalCodes.clear.str());
}

fn get_window_size(terminal: std.fs.File) !posix.winsize {
    const handle = terminal.handle;
    var winsize: posix.winsize = .{ .ws_row = 0, .ws_col = 0, .ws_xpixel = 0, .ws_ypixel = 0 };

    const err = posix.system.ioctl(handle, posix.T.IOCGWINSZ, @intFromPtr(&winsize));

    if (posix.errno(err) != .SUCCESS) {
        std.log.debug("Failed to get terminal size", .{});

        return error.WindowSizeGettingError;
    }

    return winsize;
}

const StartingCoordinates = struct {
    vertical: usize,
    horizontal: usize,
};

fn draw_initial_rectangle(terminal: std.fs.File) !StartingCoordinates {
    const winsize = try get_window_size(terminal);
    const drawer = ui_drawer.RectangleDrawer.init(0, 0, winsize.ws_row, winsize.ws_col, "Mihai's Emoji Picker");

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    var list = std.ArrayList(ui_drawer.UIElement).init(gpa);

    var row_index: usize = 0;

    const middle_row_index: usize = (winsize.ws_row - 1) / 2;
    const middle_col_index: usize = (winsize.ws_col - 1) / 2;
    const input_box_width: usize = winsize.ws_col / 3;
    const input_box_height: usize = 3;

    const input_vertical_start_pos: usize = middle_row_index - (input_box_height / 2);
    const input_horizotal_start_pos: usize = middle_col_index - (input_box_width / 2);

    const input_drawer = ui_drawer.RectangleDrawer.init(input_vertical_start_pos, input_horizotal_start_pos, input_box_height, input_box_width, "Search");

    while (row_index < winsize.ws_row) : (row_index += 1) {
        var col_index: usize = 0;

        while (col_index < winsize.ws_col) : (col_index += 1) {
            const element: ui_drawer.UIElement = input_drawer.get_for_indices(row_index, col_index) catch
                drawer.get_for_indices(row_index, col_index) catch unreachable;

            try list.append(element);
        }
    }

    var byte_list = std.ArrayList(u8).init(gpa);

    for (list.items) |element| {
        const slice = element.text;

        try byte_list.appendSlice(slice);
    }

    _ = try terminal.writeAll(byte_list.items);

    return StartingCoordinates{ .vertical = input_vertical_start_pos, .horizontal = input_horizotal_start_pos };
}

fn move_cursor_to_input(terminal: std.fs.File, starting_coordinates: StartingCoordinates) !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    const move_cursor_code = try std.fmt.allocPrint(gpa, TerminalCodes.move_cursor.str(), .{ starting_coordinates.vertical + 2, starting_coordinates.horizontal + 2 });
    defer gpa.free(move_cursor_code);

    _ = try terminal.writeAll(move_cursor_code);
}

fn change_cursor_shape(terminal: std.fs.File) !void {
    _ = try terminal.writeAll(TerminalCodes.change_cursor_to_bar.str());
}

pub fn main() !void {
    const terminal = std.io.getStdOut();

    try clear_screen(terminal);
    const input_starting_coordinates = try draw_initial_rectangle(terminal);
    try move_cursor_to_input(terminal, input_starting_coordinates);
    try change_cursor_shape(terminal);

    const stdin = std.io.getStdIn().reader();

    const bare_line = try stdin.readUntilDelimiterAlloc(
        std.heap.page_allocator,
        '\n',
        8192,
    );
    defer std.heap.page_allocator.free(bare_line);
}
