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

const UIElementKind = enum {
    horizontal_line,
    vertical_line,
    top_right_corner,
    top_left_corner,
    bottom_right_corner,
    bottom_left_corner,
    space,
    text,

    pub fn str(self: UIElementKind, text: []const u8) []const u8 {
        return switch (self) {
            .horizontal_line => "─",
            .vertical_line => "│",
            .top_right_corner => "╮",
            .top_left_corner => "╭",
            .bottom_right_corner => "╯",
            .bottom_left_corner => "╰",
            .space => " ",
            .text => text,
        };
    }
};

const UIElement = struct {
    kind: UIElementKind,
    text: []const u8,

    pub fn init(kind: UIElementKind, text: []const u8) UIElement {
        return UIElement{ .kind = kind, .text = kind.str(text) };
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

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    var list = std.ArrayList(UIElement).init(gpa);

    var row_index: usize = 0;

    const middle_row_index: usize = (winsize.ws_row - 1) / 2;
    const middle_col_index: usize = (winsize.ws_col - 1) / 2;
    const input_box_width: usize = winsize.ws_col / 3;
    const input_box_height: usize = 3;

    const input_vertical_start_pos: usize = middle_row_index - (input_box_height / 2);
    const input_horizotal_start_pos: usize = middle_col_index - (input_box_width / 2);

    const input_vertical_end_pos = input_vertical_start_pos + input_box_height;
    const input_horizontal_end_pos = input_horizotal_start_pos + input_box_width;

    while (row_index < winsize.ws_row) : (row_index += 1) {
        var col_index: usize = 0;

        while (col_index < winsize.ws_col) : (col_index += 1) {
            const element: UIElement = block: {
                const title = "Mihai's Emoji Picker";

                if (row_index == 0) {
                    const row_middle = (winsize.ws_col - 1) / 2;
                    const title_starting_pos = row_middle - (title.len / 2);
                    const title_ending_pos = title_starting_pos + title.len;

                    if (col_index >= title_starting_pos and col_index < title_ending_pos) {
                        // Copying here as to avoid overwriting previous elements
                        const temp = &.{title[col_index - title_starting_pos]};
                        const character: []const u8 = try gpa.dupe(u8, temp);

                        break :block UIElement.init(.text, character);
                    }
                }

                const is_in_row_interval = row_index >= input_vertical_start_pos and row_index < input_vertical_end_pos;
                const is_in_col_interval = col_index >= input_horizotal_start_pos and col_index < input_horizontal_end_pos;

                if (is_in_row_interval and is_in_col_interval) {
                    const input_col_index = col_index - input_horizotal_start_pos;
                    const input_row_index = row_index - input_vertical_start_pos;

                    const input_title = "Search...";

                    if (input_row_index == 0) {
                        const row_middle = (input_horizontal_end_pos - 1 - input_horizotal_start_pos) / 2;
                        const title_starting_pos = row_middle - (input_title.len / 2);
                        const title_ending_pos = title_starting_pos + input_title.len;

                        if (input_col_index >= title_starting_pos and input_col_index < title_ending_pos) {
                            // Copying here as to avoid overwriting previous elements
                            const temp = &.{input_title[input_col_index - title_starting_pos]};
                            const character: []const u8 = try gpa.dupe(u8, temp);

                            break :block UIElement.init(.text, character);
                        }
                    }

                    if (input_col_index == 0 and input_row_index == 0) {
                        break :block UIElement.init(.top_left_corner, &.{});
                    }

                    if (input_col_index == input_box_width - 1 and input_row_index == 0) {
                        break :block UIElement.init(.top_right_corner, &.{});
                    }

                    if (input_col_index == 0 and input_row_index == input_box_height - 1) {
                        break :block UIElement.init(.bottom_left_corner, &.{});
                    }

                    if (input_col_index == input_box_width - 1 and input_row_index == input_box_height - 1) {
                        break :block UIElement.init(.bottom_right_corner, &.{});
                    }

                    if (input_row_index == 0 or input_row_index == input_box_height - 1) {
                        break :block UIElement.init(.horizontal_line, &.{});
                    }

                    if (input_col_index == 0 or input_col_index == input_box_width - 1) {
                        break :block UIElement.init(.vertical_line, &.{});
                    }

                    break :block UIElement.init(.space, &.{});
                }

                if (col_index == 0 and row_index == 0) {
                    break :block UIElement.init(.top_left_corner, &.{});
                }
                if (col_index == winsize.ws_col - 1 and row_index == 0) {
                    break :block UIElement.init(.top_right_corner, &.{});
                }
                if (col_index == 0 and row_index == winsize.ws_row - 1) {
                    break :block UIElement.init(.bottom_left_corner, &.{});
                }
                if (col_index == winsize.ws_col - 1 and row_index == winsize.ws_row - 1) {
                    break :block UIElement.init(.bottom_right_corner, &.{});
                }
                if (col_index == 0 or col_index == winsize.ws_col - 1) {
                    break :block UIElement.init(.vertical_line, &.{});
                }
                if (row_index == 0 or row_index == winsize.ws_row - 1) {
                    break :block UIElement.init(.horizontal_line, &.{});
                }

                break :block UIElement.init(.space, &.{});
            };

            try list.append(element);
        }
    }

    var byte_list = std.ArrayList(u8).init(gpa);

    for (list.items) |element| {
        const slice = element.text;

        try byte_list.appendSlice(slice);
    }

    _ = try terminal.writeAll(byte_list.items);

    const moveCursorToInput = try std.fmt.allocPrint(gpa, TerminalCodes.move_cursor.str(), .{ input_vertical_start_pos + 2, input_horizotal_start_pos + 2 });
    defer gpa.free(moveCursorToInput);

    _ = try terminal.writeAll(moveCursorToInput);

    _ = try terminal.writeAll(TerminalCodes.change_cursor_to_bar.str());
}

fn draw_initial_rectangle(terminal: std.fs.File) !void {
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
}

pub fn main() !void {
    const terminal = std.io.getStdOut();

    try clear_screen(terminal);
    try draw_initial_rectangle(terminal);
    // try print_rectangle(terminal);

    const stdin = std.io.getStdIn().reader();

    const bare_line = try stdin.readUntilDelimiterAlloc(
        std.heap.page_allocator,
        '\n',
        8192,
    );
    defer std.heap.page_allocator.free(bare_line);
}
