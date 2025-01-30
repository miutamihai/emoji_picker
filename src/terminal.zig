const std = @import("std");
const fs = std.fs;
const posix = std.posix;
const types = @import("types.zig");
const Mutex = std.Thread.Mutex;

const c = @cImport(@cInclude("termios.h"));

const TerminalCodes = enum {
    clear,
    cursor_home,
    move_cursor,
    change_cursor_to_bar,
    toggle_alt_screen_on,
    toggle_alt_screen_off,
    delete_character,

    pub fn str(self: TerminalCodes) [:0]const u8 {
        return switch (self) {
            .clear => "\x1B[2J",
            .cursor_home => "\x1B[H",
            .move_cursor => "\x1B[{d};{d}H",
            .change_cursor_to_bar => "\x1B[6 q",
            .toggle_alt_screen_on => "\x1B[?1049h",
            .toggle_alt_screen_off => "\x1B[?1049l",
            .delete_character => &.{ 0x08, ' ', 0x08 },
        };
    }
};

const OrigTermiosMutex = struct {
    mutex: Mutex = Mutex{},
    _orig_termios: ?c.termios = null,

    inline fn lock(self: *OrigTermiosMutex) *?c.termios {
        self.mutex.lock();
        return &self._orig_termios;
    }

    inline fn unlock(self: *OrigTermiosMutex) void {
        self.mutex.unlock();
    }
};

var orig_termios_mutex = OrigTermiosMutex{};

const TerminalErrors = error{ ClearScreenFailure, GetTermiosAttrError, SetTermiosAttrError };

fn wrapAsErrorUnion(return_no: i32, comptime ERROR_VARIANT: TerminalErrors) !void {
    if (return_no == -1) {
        return ERROR_VARIANT;
    }
}
pub const Terminal = struct {
    terminal_file_handle: std.fs.File,

    pub fn init() !Terminal {
        const handle = try fs.openFileAbsolute("/dev/tty", .{
            .mode = .read_write,
            .allow_ctty = true,
        });

        return Terminal{ .terminal_file_handle = handle };
    }

    // TODO: Change all these writes to use buffers

    pub fn reset_cursor_position(self: Terminal) !void {
        _ = try self.terminal_file_handle.writeAll(TerminalCodes.cursor_home.str());
    }

    pub fn clear_screen(seld: Terminal) !void {
        _ = try seld.terminal_file_handle.writeAll(TerminalCodes.clear.str());
    }

    pub fn get_window_size(self: Terminal) !posix.winsize {
        const handle = self.terminal_file_handle.handle;
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

        _ = try self.terminal_file_handle.writeAll(move_cursor_code);
    }

    pub fn change_cursor_shape(self: Terminal) !void {
        _ = try self.terminal_file_handle.writeAll(TerminalCodes.change_cursor_to_bar.str());
    }

    pub fn write(self: Terminal, bytes: []const u8) !void {
        _ = try self.terminal_file_handle.writeAll(bytes);
    }

    pub fn enable_raw_mode(self: Terminal) !void {
        const orig_termios = orig_termios_mutex.lock();
        defer orig_termios_mutex.unlock();
        if (orig_termios.*) |_| {
            return;
        }

        var ios: c.termios = undefined;
        try wrapAsErrorUnion(c.tcgetattr(self.terminal_file_handle.handle, &ios), TerminalErrors.GetTermiosAttrError);
        const orig = ios;

        c.cfmakeraw(&ios);
        try wrapAsErrorUnion(c.tcsetattr(self.terminal_file_handle.handle, c.TCSANOW, &ios), TerminalErrors.SetTermiosAttrError);

        // Set the orig_termios if needed
        orig_termios.* = orig;
    }

    pub fn disable_raw_mode(self: Terminal) !void {
        const orig_termios = orig_termios_mutex.lock();
        defer orig_termios_mutex.unlock();
        if (orig_termios.*) |orig_ios| {
            try wrapAsErrorUnion(c.tcsetattr(self.terminal_file_handle.handle, c.TCSANOW, &orig_ios), TerminalErrors.SetTermiosAttrError);
        }
    }

    pub fn move_to_alt_screen(self: Terminal) !void {
        _ = try self.terminal_file_handle.write(TerminalCodes.toggle_alt_screen_on.str());
    }

    pub fn move_to_original_screen(self: Terminal) !void {
        _ = try self.terminal_file_handle.write(TerminalCodes.toggle_alt_screen_off.str());
    }

    pub fn delete_character(self: Terminal) !void {
        _ = try self.terminal_file_handle.write(TerminalCodes.delete_character.str());
    }
};
