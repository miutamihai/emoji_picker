const std = @import("std");
const posix = std.posix;

pub const UIElementKind = enum {
    horizontal_line,
    vertical_line,
    top_right_corner,
    top_left_corner,
    bottom_right_corner,
    bottom_left_corner,
    space,
    text,

    const Self = @This();

    // FIXME Change all these []const u8 to a single u21
    pub fn str(self: Self, text: []const u8) []const u8 {
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

pub const UIElementBackground = enum {
    white,
    default,

    const Self = @This();

    pub fn str(self: Self) [:0]const u8 {
        return switch (self) {
            .white => "\x1B[30;47m",
            .default => "\x1B[39;49m",
        };
    }
};

pub const UIElement = struct {
    kind: UIElementKind,
    text: []const u8,
    background: ?UIElementBackground,

    const Self = @This();

    pub fn init(kind: UIElementKind, text: []const u8) Self {
        return UIElement{ .kind = kind, .text = kind.str(text), .background = null };
    }

    pub fn init_with_background(kind: UIElementKind, text: []const u8, background: UIElementBackground) Self {
        return UIElement{ .kind = kind, .text = kind.str(text), .background = background };
    }
};

pub const DrawingError = error{OutOfBounds};

pub const RectangleDrawer = struct {
    allocator: std.mem.Allocator,

    vertical_offset: usize,
    horizontal_offset: usize,
    vertical_size: usize,
    horizontal_size: usize,

    title: []const u8,

    vertical_end: usize,
    horizontal_end: usize,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, vertical_offset: usize, horizontal_offset: usize, vertical_size: usize, horizontal_size: usize, title: []const u8) Self {
        return Self{
            .allocator = allocator,
            .vertical_offset = vertical_offset,
            .horizontal_offset = horizontal_offset,
            .vertical_size = vertical_size,
            .horizontal_size = horizontal_size,

            .title = title,

            .vertical_end = vertical_offset + vertical_size,
            .horizontal_end = horizontal_offset + horizontal_size,
        };
    }

    pub fn is_within_bounds(self: Self, vertical_index: usize, horizontal_index: usize) bool {
        const is_within_vertical_bounds = vertical_index >= self.vertical_offset and vertical_index < self.vertical_end;
        const is_within_horizontal_bounds = horizontal_index >= self.horizontal_offset and horizontal_index < self.horizontal_end;

        return is_within_vertical_bounds and is_within_horizontal_bounds;
    }

    pub fn is_within_bounds_exclusive(self: Self, vertical_index: usize, horizontal_index: usize) bool {
        const is_within_vertical_bounds = vertical_index > self.vertical_offset and vertical_index < self.vertical_end - 1;
        const is_within_horizontal_bounds = horizontal_index > self.horizontal_offset and horizontal_index < self.horizontal_end - 1;

        return is_within_vertical_bounds and is_within_horizontal_bounds;
    }

    pub fn get_for_indices(self: Self, vertical_index: usize, horizontal_index: usize) !UIElement {
        if (!self.is_within_bounds(vertical_index, horizontal_index)) {
            return DrawingError.OutOfBounds;
        }

        if (vertical_index == self.vertical_offset and self.title.len != 0) {
            // const row_middle = (self.horizontal_end - 1) / 2;
            const row_middle = self.horizontal_offset + self.horizontal_size / 2;
            const title_starting_pos = row_middle - (self.title.len / 2);
            const title_ending_pos = title_starting_pos + self.title.len;

            if (horizontal_index >= title_starting_pos and horizontal_index < title_ending_pos) {
                // Copying here as to avoid overwriting previous elements
                const temp = self.title[horizontal_index - title_starting_pos];
                const character: []const u8 = try self.allocator.dupe(u8, &.{temp});

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
