const std = @import("std");
const posix = std.posix;

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

pub const UIElement = struct {
    kind: UIElementKind,
    text: []const u8,

    pub fn init(kind: UIElementKind, text: []const u8) UIElement {
        return UIElement{ .kind = kind, .text = kind.str(text) };
    }
};

pub const DrawingError = error{OutOfBounds};

pub const RectangleDrawer = struct {
    vertical_offset: usize,
    horizontal_offset: usize,
    vertical_size: usize,
    horizontal_size: usize,

    title: []const u8,

    vertical_end: usize,
    horizontal_end: usize,

    pub fn init(vertical_offset: usize, horizontal_offset: usize, vertical_size: usize, horizontal_size: usize, title: []const u8) RectangleDrawer {
        return RectangleDrawer{
            .vertical_offset = vertical_offset,
            .horizontal_offset = horizontal_offset,
            .vertical_size = vertical_size,
            .horizontal_size = horizontal_size,

            .title = title,

            .vertical_end = vertical_offset + vertical_size,
            .horizontal_end = horizontal_offset + horizontal_size,
        };
    }

    pub fn get_for_indices(self: RectangleDrawer, vertical_index: usize, horizontal_index: usize) !UIElement {
        const is_outside_vertical_bounds = vertical_index < self.vertical_offset or vertical_index >= self.vertical_end;
        const is_outside_horizontal_bounds = horizontal_index < self.horizontal_offset or horizontal_index >= self.horizontal_end;

        if (is_outside_vertical_bounds or is_outside_horizontal_bounds) {
            return DrawingError.OutOfBounds;
        }

        var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa = general_purpose_allocator.allocator();

        if (vertical_index == self.vertical_offset and self.title.len != 0) {
            // const row_middle = (self.horizontal_end - 1) / 2;
            const row_middle = self.horizontal_offset + self.horizontal_size / 2;
            const title_starting_pos = row_middle - (self.title.len / 2);
            const title_ending_pos = title_starting_pos + self.title.len;

            if (horizontal_index >= title_starting_pos and horizontal_index < title_ending_pos) {
                // Copying here as to avoid overwriting previous elements
                const temp = self.title[horizontal_index - title_starting_pos];
                const character: []const u8 = try gpa.dupe(u8, &.{temp});

                return UIElement.init(.text, character);
            }
        }

        if (vertical_index == self.vertical_offset and horizontal_index == self.horizontal_offset) {
            return UIElement.init(.top_left_corner, &.{});
        }

        if (vertical_index == self.vertical_end - 1 and horizontal_index == self.horizontal_offset) {
            return UIElement.init(.bottom_left_corner, &.{});
        }

        if (vertical_index == self.vertical_offset and horizontal_index == self.horizontal_end - 1) {
            return UIElement.init(.top_right_corner, &.{});
        }

        if (vertical_index == self.vertical_end - 1 and horizontal_index == self.horizontal_end - 1) {
            return UIElement.init(.bottom_right_corner, &.{});
        }

        if (vertical_index == self.vertical_offset or vertical_index == self.vertical_end - 1) {
            return UIElement.init(.horizontal_line, &.{});
        }

        if (horizontal_index == self.horizontal_offset or horizontal_index == self.horizontal_end - 1) {
            return UIElement.init(.vertical_line, &.{});
        }

        return UIElement.init(.space, &.{});
    }
};
