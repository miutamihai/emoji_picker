const std = @import("std");
const posix = std.posix;

const TerminalCodes = enum {
    clear,
    cursor_home,

    pub fn str(self: TerminalCodes) [:0]const u8 {
        return switch (self) {
            .clear => "\x1B[2J",
            .cursor_home => "\x1B[H",
        };
    }
};

const UICharacters = enum {
    horizontal_line,
    vertical_line,
    top_right_corner,
    top_left_corner,
    bottom_right_corner,
    bottom_left_corner,
    space,

    pub fn str(self: UICharacters) [:0]const u8 {
        return switch (self) {
            .horizontal_line => "─",
            .vertical_line => "│",
            .top_right_corner => "╮",
            .top_left_corner => "╭",
            .bottom_right_corner => "╯",
            .bottom_left_corner => "╰",
            .space => " ",
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

fn print_rectangle(terminal: std.fs.File) !void {
    const winsize = try get_window_size(terminal);

    var list = std.ArrayList([]const u8).init(std.heap.page_allocator);

    var row_index: u8 = 0;

    while (row_index < winsize.ws_row) : (row_index += 1) {
        var col_index: u8 = 0;

        while (col_index < winsize.ws_col) : (col_index += 1) {
            const character: UICharacters = block: {
                if (col_index == 0 and row_index == 0) {
                    break :block .top_left_corner;
                }
                if (col_index == winsize.ws_col - 1 and row_index == 0) {
                    break :block .top_right_corner;
                }
                if (col_index == 0 and row_index == winsize.ws_row - 1) {
                    break :block .bottom_left_corner;
                }
                if (col_index == winsize.ws_col - 1 and row_index == winsize.ws_row - 1) {
                    break :block .bottom_right_corner;
                }
                if (col_index == 0 or col_index == winsize.ws_col - 1) {
                    break :block .vertical_line;
                }
                if (row_index == 0 or row_index == winsize.ws_row - 1) {
                    break :block .horizontal_line;
                }

                break :block .space;
            };

            try list.append(character.str());
        }
    }

    var byte_list = std.ArrayList(u8).init(std.heap.page_allocator);

    for (list.items) |slice| {
        try byte_list.appendSlice(slice);
    }

    _ = try terminal.writeAll(byte_list.items);
}

pub fn main() !void {
    const terminal = std.io.getStdOut();

    try clear_screen(terminal);
    try print_rectangle(terminal);

    const stdin = std.io.getStdIn().reader();

    const bare_line = try stdin.readUntilDelimiterAlloc(
        std.heap.page_allocator,
        '\n',
        8192,
    );
    defer std.heap.page_allocator.free(bare_line);
}
