const std = @import("std");
const terminal = @import("terminal.zig");
const types = @import("types.zig");
const ui_drawer = @import("ui_drawer.zig");
const emoji = @import("emoji.zig");

pub const ScreenType = enum { home, search };

pub const Screen = struct {
    terminal: terminal.Terminal,
    allocator: std.mem.Allocator,
    current_screen: ScreenType,

    pub fn init(allocator: std.mem.Allocator, terminal_instance: terminal.Terminal) Screen {
        return Screen{ .terminal = terminal_instance, .current_screen = ScreenType.home, .allocator = allocator };
    }

    pub fn navigate(self: *Screen, destination: ScreenType, input: std.ArrayList(u8)) !types.StartingCoordinates {
        try self.terminal.clear_screen();
        try self.terminal.reset_cursor_position();
        self.current_screen = destination;

        return switch (destination) {
            .home => self.home(input),
            .search => self.search(input),
        };
    }

    fn home(self: Screen, input: std.ArrayList(u8)) !types.StartingCoordinates {
        const winsize = try self.terminal.get_window_size();
        const drawer = ui_drawer.RectangleDrawer.init(self.allocator, 0, 0, winsize.ws_row, winsize.ws_col, "Mihai's Emoji Picker");

        var list = std.ArrayList(ui_drawer.UIElement).init(self.allocator);

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

                try list.append(element);
            }
        }

        var byte_list = std.ArrayList(u8).init(self.allocator);

        for (list.items) |element| {
            const slice = element.text;

            try byte_list.appendSlice(slice);
        }

        _ = try self.terminal.write(byte_list.items);

        return types.StartingCoordinates{ .vertical = input_vertical_start_pos, .horizontal = input_horizotal_start_pos + input.items.len };
    }

    fn search(self: Screen, input: std.ArrayList(u8)) !types.StartingCoordinates {
        const winsize = try self.terminal.get_window_size();
        const drawer = ui_drawer.RectangleDrawer.init(self.allocator, 0, 0, winsize.ws_row, winsize.ws_col, "Mihai's Emoji Picker");

        var list = std.ArrayList(ui_drawer.UIElement).init(self.allocator);

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

                            break :blk ui_drawer.UIElement.init(ui_drawer.UIElementKind.text, character);
                        } else {
                            break :blk ui_drawer.UIElement.init(ui_drawer.UIElementKind.space, "");
                        }
                    }

                    if (search_box_drawer.is_within_bounds_exclusive(row_index, col_index)) {
                        const current_index = row_index - search_box_vertical_start_pos;
                        if (current_index >= emoji_view.len) {
                            break :blk ui_drawer.UIElement.init(ui_drawer.UIElementKind.space, "");
                        }

                        const current_emoji = emoji_view[row_index - search_box_vertical_start_pos];
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

                        break :blk ui_drawer.UIElement.init(ui_drawer.UIElementKind.text, target_chars);
                    } else {
                        break :blk input_drawer.get_for_indices(row_index, col_index) catch search_box_drawer.get_for_indices(row_index, col_index) catch drawer.get_for_indices(row_index, col_index) catch unreachable;
                    }
                };

                try list.append(element);
            }
        }

        var byte_list = std.ArrayList(u8).init(self.allocator);

        for (list.items) |element| {
            const slice = element.text;

            try byte_list.appendSlice(slice);
        }

        _ = try self.terminal.write(byte_list.items);

        return types.StartingCoordinates{ .vertical = input_vertical_start_pos, .horizontal = input_horizontal_start_pos + input.items.len };
    }
};
