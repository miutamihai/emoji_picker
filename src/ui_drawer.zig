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
        if (text.len > 0) {
            std.log.debug("str got text {s}", .{text});
        }

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

pub const RectangleDrawer = struct {
    vertical_offset: u16,
    horizontal_offset: u16,
    vertical_size: u16,
    horizontal_size: u16,

    title: []const u8,

    vertical_end: u16,
    horizontal_end: u16,

    pub fn init(vertical_offset: u16, horizontal_offset: u16, vertical_size: u16, horizontal_size: u16, title: []const u8) RectangleDrawer {
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
        var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa = general_purpose_allocator.allocator();

        if (vertical_index == 0 and self.title.len != 0) {
            const row_middle = (self.horizontal_end - 1) / 2;
            const title_starting_pos = row_middle - (self.title.len / 2);
            const title_ending_pos = title_starting_pos + self.title.len;

            if (horizontal_index >= title_starting_pos and horizontal_index < title_ending_pos) {
                // Copying here as to avoid overwriting previous elements
                const temp = self.title[horizontal_index - title_starting_pos];
                const character: []const u8 = try gpa.dupe(u8, &.{temp});

                return UIElement.init(.text, character);
            }
        }

        if (vertical_index == 0 and horizontal_index == 0) {
            return UIElement.init(.top_left_corner, &.{});
        }

        if (vertical_index == self.vertical_end - 1 and horizontal_index == 0) {
            return UIElement.init(.bottom_left_corner, &.{});
        }

        if (vertical_index == 0 and horizontal_index == self.horizontal_end - 1) {
            return UIElement.init(.top_right_corner, &.{});
        }

        if (vertical_index == self.vertical_end - 1 and horizontal_index == self.horizontal_end - 1) {
            return UIElement.init(.bottom_right_corner, &.{});
        }

        if (vertical_index == 0 or vertical_index == self.vertical_end - 1) {
            return UIElement.init(.horizontal_line, &.{});
        }

        if (horizontal_index == 0 or horizontal_index == self.horizontal_end - 1) {
            return UIElement.init(.vertical_line, &.{});
        }

        return UIElement.init(.space, &.{});
    }
};
