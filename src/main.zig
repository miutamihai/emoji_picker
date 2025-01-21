const std = @import("std");
const posix = std.posix;

fn clear_screen(terminal: std.fs.File) !void {
    const CLEAR_CODE = "\x1B[2J\x1B[H";

    _ = try terminal.writeAll(CLEAR_CODE);
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

    var list = std.ArrayList(u8).init(std.heap.page_allocator);

    var row_index: u8 = 0;

    while (row_index < winsize.ws_row) : (row_index += 1) {
        var col_index: u8 = 0;

        while (col_index < winsize.ws_col) : (col_index += 1) {
            const character: u8 = if (col_index == 0 or col_index == winsize.ws_col - 1)
                '|'
            else if (row_index == 0 or row_index == winsize.ws_row - 1)
                '-'
            else
                ' ';

            try list.append(character);
        }
    }

    _ = try terminal.writeAll(list.items);
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
