const std = @import("std");
const terminal = @import("terminal.zig");
const types = @import("types.zig");
const ui_drawer = @import("ui_drawer.zig");
const emoji = @import("emoji.zig");

const c = @cImport(@cInclude("wchar.h"));

// TODO find the following functions a new home
fn get_elements_matrix(allocator: std.mem.Allocator, terminal_instance: terminal.Terminal) ![][]ui_drawer.UIElement {
    const winsize = try terminal_instance.get_window_size();

    const matrix = try allocator.alloc([]ui_drawer.UIElement, winsize.ws_row);

    var index: usize = 0;

    while (index < winsize.ws_row) : (index += 1) {
        matrix[index] = try allocator.alloc(ui_drawer.UIElement, winsize.ws_col);
    }

    return matrix;
}

fn get_character_width(char: u21) usize {
    return c.wcwidth(char);
}

pub const ScreenType = enum { home, search };

pub const Screen = struct {
    terminal: terminal.Terminal,
    allocator: std.mem.Allocator,
    current_screen: ScreenType,
    element_matrix: [][]ui_drawer.UIElement,

    highlighted_line_index: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, terminal_instance: terminal.Terminal) !Self {
        const element_matrix = try get_elements_matrix(allocator, terminal_instance);

        return Self{ .terminal = terminal_instance, .current_screen = ScreenType.home, .allocator = allocator, .highlighted_line_index = 0, .element_matrix = element_matrix };
    }

    pub fn navigate(self: *Self, destination: ScreenType, input: std.ArrayList(u8)) !types.StartingCoordinates {
        try self.terminal.clear_screen();
        try self.terminal.reset_cursor_position();
        self.current_screen = destination;

        return switch (destination) {
            .home => self.home(input),
            .search => self.search(input),
        };
    }

    fn home(self: Self, input: std.ArrayList(u8)) !types.StartingCoordinates {
        const winsize = try self.terminal.get_window_size();
        const drawer = ui_drawer.RectangleDrawer.init(self.allocator, 0, 0, winsize.ws_row, winsize.ws_col, "Mihai's Emoji Picker");

        var row_index: usize = 0;

        const middle_row_index: usize = (winsize.ws_row - 1) / 2;
        const middle_col_index: usize = (winsize.ws_col - 1) / 2;
        const input_box_width: usize = winsize.ws_col / 3;
        const input_box_height: usize = 3;

        const input_vertical_start_pos: usize = middle_row_index - (input_box_height / 2);
        const input_horizotal_start_pos: usize = middle_col_index - (input_box_width / 2);

        const input_drawer = ui_drawer.RectangleDrawer.init(self.allocator, input_vertical_start_pos, input_horizotal_start_pos, input_box_height, input_box_width, "Search");

        while (row_index < winsize.ws_row) : (row_index += 1) {
            var col_index: usize = 0;

            while (col_index < winsize.ws_col) : (col_index += 1) {
                const element: ui_drawer.UIElement = input_drawer.get_for_indices(row_index, col_index) catch
                    drawer.get_for_indices(row_index, col_index) catch unreachable;

                self.element_matrix[row_index][col_index] = element;
            }
        }

        try self.write_elements();

        return types.StartingCoordinates{ .vertical = input_vertical_start_pos, .horizontal = input_horizotal_start_pos + input.items.len };
    }

    fn search(self: *Self, input: std.ArrayList(u8)) !types.StartingCoordinates {
        self.highlighted_line_index = 0;

        const winsize = try self.terminal.get_window_size();
        const drawer = ui_drawer.RectangleDrawer.init(self.allocator, 0, 0, winsize.ws_row, winsize.ws_col, "Mihai's Emoji Picker");

        var row_index: usize = 0;

        // TODO: Shit name incoming
        const middle_row_index: usize = (winsize.ws_row - 1) / 6;
        const middle_col_index: usize = (winsize.ws_col - 1) / 2;

        const input_box_width: usize = winsize.ws_col / 3;
        const input_box_height: usize = 3;

        const input_vertical_start_pos: usize = middle_row_index - (input_box_height / 2);
        const input_horizontal_start_pos: usize = middle_col_index - (input_box_width / 2);

        const search_box_width: usize = ((winsize.ws_col - 1) / 3) * 2;
        const search_box_height: usize = ((winsize.ws_row - 1) / 3) * 2;

        const search_box_vertical_start_pos: usize = input_vertical_start_pos + input_box_height + 2;
        const search_box_horizontal_start_pos: usize = middle_col_index - (search_box_width / 2);

        const input_drawer = ui_drawer.RectangleDrawer.init(self.allocator, input_vertical_start_pos, input_horizontal_start_pos, input_box_height, input_box_width, "Search");
        const search_box_drawer = ui_drawer.RectangleDrawer.init(self.allocator, search_box_vertical_start_pos, search_box_horizontal_start_pos, search_box_height, search_box_width, "");

        const emoji_list = try emoji.get_matching_input(self.allocator, input);

        const emoji_view = emoji_list[0..@min(search_box_height, emoji_list.len)];

        while (row_index < winsize.ws_row) : (row_index += 1) {
            var col_index: usize = 0;

            while (col_index < winsize.ws_col) : (col_index += 1) {
                const element: ui_drawer.UIElement = blk: {
                    if (input_drawer.is_within_bounds_exclusive(row_index, col_index)) {
                        const current_index = col_index - input_horizontal_start_pos - 1;

                        if (current_index < input.items.len) {
                            const temp = &.{input.items[current_index]};
                            const character: []const u8 = try self.allocator.dupe(u8, temp);

                            break :blk ui_drawer.UIElement.init(.{ .character = character });
                        } else {
                            break :blk ui_drawer.UIElement.init(.{ .kind = ui_drawer.UIElementKind.space });
                        }
                    }

                    if (search_box_drawer.is_within_bounds_exclusive(row_index, col_index)) {
                        const current_index = row_index - search_box_vertical_start_pos - 1;
                        if (current_index >= emoji_view.len or current_index < 0) {
                            break :blk ui_drawer.UIElement.init(.{ .kind = ui_drawer.UIElementKind.space });
                        }

                        self.highlighted_line_index = row_index * col_index;

                        const current_emoji = emoji_view[current_index];
                        const description = current_emoji.description;
                        const target_emoji = current_emoji.emoji;

                        const total_text_len = description.len + 1;
                        const text_start_pos = middle_col_index - (total_text_len / 2);
                        const text_end_pos = text_start_pos + total_text_len;

                        const target_chars = inner_blk: {
                            if (col_index < text_start_pos or col_index >= text_end_pos) {
                                break :inner_blk " ";
                            } else {
                                const target_array_index = col_index - text_start_pos;

                                const temp = temp_blk: {
                                    if (target_array_index < description.len) {
                                        break :temp_blk &.{description[target_array_index]};
                                    } else {
                                        // Emojis can take 2 visual spaces (if they're 4 bytes long),
                                        //  so need to skip one character here

                                        // FIXME: There are some emojis for which this is not enough
                                        // TODO: use the new getCharWidth function to determine how to do this properly
                                        if (target_emoji.len > 3) {
                                            col_index += 1;
                                        }

                                        break :temp_blk target_emoji;
                                    }
                                };
                                const character: []const u8 = try self.allocator.dupe(u8, temp);
                                break :inner_blk character;
                            }
                        };

                        if (current_index == 0) {
                            break :blk ui_drawer.UIElement.init_with_background(.{ .character = target_chars }, ui_drawer.UIElementBackground.white);
                        }

                        break :blk ui_drawer.UIElement.init(.{ .character = target_chars });
                    } else {
                        break :blk input_drawer.get_for_indices(row_index, col_index) catch search_box_drawer.get_for_indices(row_index, col_index) catch drawer.get_for_indices(row_index, col_index) catch unreachable;
                    }
                };

                self.element_matrix[row_index][col_index] = element;
            }
        }

        try self.write_elements();

        return types.StartingCoordinates{ .vertical = input_vertical_start_pos, .horizontal = input_horizontal_start_pos + input.items.len };
    }

    pub fn change_highlight(self: *Self, addend: isize) !void {
        const cannot_go_up = self.highlighted_line_index == 0 and addend < 0;
        const cannot_go_down = self.highlighted_line_index == self.element_matrix[self.element_matrix.len - 1].len - 1 and addend > 0;

        if (cannot_go_up or cannot_go_down) {
            return;
        }

        const winsize = try self.terminal.get_window_size();

        // TODO: Find a better way of doing this
        const new_highlighted_index = if (addend < 0) self.highlighted_line_index - (winsize.ws_col - 1) else self.highlighted_line_index + (winsize.ws_col - 1);

        try self.terminal.clear_screen();
        try self.terminal.reset_cursor_position();

        var row_index: usize = 0;
        var col_index: usize = 0;

        while (row_index < self.element_matrix.len) : (row_index += 1) {
            while (col_index < self.element_matrix[row_index].len) : (col_index += 1) {
                self.element_matrix[row_index][col_index].background = null;

                if (row_index == new_highlighted_index) {
                    self.element_matrix[row_index][col_index].background = ui_drawer.UIElementBackground.white;
                }
            }
        }

        self.highlighted_line_index = new_highlighted_index;

        try self.write_elements();
    }

    fn write_elements(self: Self) !void {
        var byte_list = std.ArrayList(u8).init(self.allocator);

        for (self.element_matrix) |row| {
            for (row) |element| {
                const bytes = try element.to_bytes(self.allocator);
                try byte_list.appendSlice(bytes);
            }
        }

        _ = try self.terminal.write(byte_list.items);
    }
};
