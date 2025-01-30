const std = @import("std");
const terminal = @import("terminal.zig");
const types = @import("types.zig");
const ui_drawer = @import("ui_drawer.zig");

pub const ScreenType = enum { home, search };

pub const Screen = struct {
    terminal: terminal.Terminal,
    current_screen: ScreenType,

    pub fn init(terminal_instance: terminal.Terminal) Screen {
        return Screen{ .terminal = terminal_instance, .current_screen = ScreenType.home };
    }

    pub fn navigate(self: *Screen, destination: ScreenType) !types.StartingCoordinates {
        try self.terminal.clear_screen();
        try self.terminal.reset_cursor_position();
        self.current_screen = destination;

        return switch (destination) {
            .home => self.home(),
            .search => self.search(),
        };
    }

    fn home(self: Screen) !types.StartingCoordinates {
        const winsize = try self.terminal.get_window_size();
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

        _ = try self.terminal.write(byte_list.items);

        return types.StartingCoordinates{ .vertical = input_vertical_start_pos, .horizontal = input_horizotal_start_pos };
    }

    fn search(self: Screen) !types.StartingCoordinates {
        const winsize = try self.terminal.get_window_size();
        const drawer = ui_drawer.RectangleDrawer.init(0, 0, winsize.ws_row, winsize.ws_col, "Mihai's Emoji Picker");

        var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa = general_purpose_allocator.allocator();

        var list = std.ArrayList(ui_drawer.UIElement).init(gpa);

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

        const input_drawer = ui_drawer.RectangleDrawer.init(input_vertical_start_pos, input_horizontal_start_pos, input_box_height, input_box_width, "Search");
        const search_box_drawer = ui_drawer.RectangleDrawer.init(search_box_vertical_start_pos, search_box_horizontal_start_pos, search_box_height, search_box_width, "");

        while (row_index < winsize.ws_row) : (row_index += 1) {
            var col_index: usize = 0;

            while (col_index < winsize.ws_col) : (col_index += 1) {
                const element: ui_drawer.UIElement = input_drawer.get_for_indices(row_index, col_index) catch search_box_drawer.get_for_indices(row_index, col_index) catch drawer.get_for_indices(row_index, col_index) catch unreachable;

                try list.append(element);
            }
        }

        var byte_list = std.ArrayList(u8).init(gpa);

        for (list.items) |element| {
            const slice = element.text;

            try byte_list.appendSlice(slice);
        }

        _ = try self.terminal.write(byte_list.items);

        return types.StartingCoordinates{ .vertical = input_vertical_start_pos, .horizontal = input_horizontal_start_pos };
    }
};
