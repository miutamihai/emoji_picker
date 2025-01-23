const std = @import("std");
const posix = std.posix;
const types = @import("types.zig");

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

pub const Terminal = struct {
    instance: std.fs.File,

    pub fn init() Terminal {
        return Terminal{ .instance = std.io.getStdOut() };
    }

    // TODO: Change all these writes to use buffers

    pub fn reset_cursor_position(self: Terminal) !void {
        _ = try self.instance.writeAll(TerminalCodes.cursor_home.str());
    }

    pub fn clear_screen(seld: Terminal) !void {
        _ = try seld.instance.writeAll(TerminalCodes.clear.str());
    }

    pub fn get_window_size(self: Terminal) !posix.winsize {
        const handle = self.instance.handle;
        var winsize: posix.winsize = .{ .ws_row = 0, .ws_col = 0, .ws_xpixel = 0, .ws_ypixel = 0 };

        const err = posix.system.ioctl(handle, posix.T.IOCGWINSZ, @intFromPtr(&winsize));

        if (posix.errno(err) != .SUCCESS) {
            std.log.debug("Failed to get terminal size", .{});

            return error.WindowSizeGettingError;
        }

        return winsize;
    }

    pub fn move_cursor_to_coordinates(self: Terminal, starting_coordinates: types.StartingCoordinates) !void {
        var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa = general_purpose_allocator.allocator();

        const move_cursor_code = try std.fmt.allocPrint(gpa, TerminalCodes.move_cursor.str(), .{ starting_coordinates.vertical + 2, starting_coordinates.horizontal + 2 });
        defer gpa.free(move_cursor_code);

        _ = try self.instance.writeAll(move_cursor_code);
    }

    pub fn change_cursor_shape(self: Terminal) !void {
        _ = try self.instance.writeAll(TerminalCodes.change_cursor_to_bar.str());
    }

    pub fn write(self: Terminal, bytes: []const u8) !void {
        _ = try self.instance.writeAll(bytes);
    }
};
