const builtin = @import("builtin");
const std = @import("../std.zig");
const posix = std.posix;

const native_os = builtin.os.tag;

/// Cross-platform file-system watcher API.
/// Currently implemented on Linux via inotify.
pub const Watch = switch (native_os) {
    .linux => LinuxWatch,
    else => UnsupportedWatch,
};

pub const Event = struct {
    wd: i32,
    mask: u32,
    cookie: u32,
    name: ?[]const u8,
};

pub const AddError = error{ NameTooLong } || posix.INotifyAddWatchError;
pub const WaitError = posix.ReadError;

pub const Mask = std.os.linux.IN;

const LinuxWatch = struct {
    fd: i32,

    pub fn init() (posix.INotifyInitError || error{Unsupported})!LinuxWatch {
        if (native_os != .linux) return error.Unsupported;
        const fd = try posix.inotify_init1(posix.IN.NONBLOCK | posix.IN.CLOEXEC);
        return .{ .fd = fd };
    }

    pub fn deinit(self: *LinuxWatch) void {
        posix.close(self.fd);
        self.* = undefined;
    }

    pub fn add(self: *LinuxWatch, path: []const u8, mask: Mask) AddError!i32 {
        return try posix.inotify_add_watch(self.fd, path, @bitCast(mask));
    }

    pub fn remove(self: *LinuxWatch, wd: i32) void {
        posix.inotify_rm_watch(self.fd, wd);
    }

    /// Reads one or more events into `buffer` and returns the bytes written.
    pub fn read(self: *LinuxWatch, buffer: []u8) WaitError!usize {
        return try posix.read(self.fd, buffer);
    }

    /// Parse a single event from `buffer[offset..]`.
    /// Returns null when no complete event exists.
    pub fn nextEvent(buffer: []const u8, offset: *usize) ?Event {
        if (buffer.len -| offset.* < @sizeOf(std.os.linux.inotify_event)) return null;
        const raw: *align(1) const std.os.linux.inotify_event = @ptrCast(buffer[offset.*..].ptr);
        const full_len = @sizeOf(std.os.linux.inotify_event) + raw.len;
        if (buffer.len - offset.* < full_len) return null;

        const name = if (raw.len == 0) null else blk: {
            const raw_name = buffer[offset.* + @sizeOf(std.os.linux.inotify_event) ..][0..raw.len];
            const trimmed = std.mem.sliceTo(raw_name, 0);
            break :blk trimmed;
        };
        offset.* += full_len;
        return .{ .wd = raw.wd, .mask = raw.mask, .cookie = raw.cookie, .name = name };
    }
};

const UnsupportedWatch = struct {
    pub fn init() error{Unsupported}!UnsupportedWatch {
        return error.Unsupported;
    }
    pub fn deinit(_: *UnsupportedWatch) void {}
};

test "linux watch parses events" {
    if (native_os != .linux) return error.SkipZigTest;

    var w = try LinuxWatch.init();
    defer w.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const wd = try w.add(tmp.dir_path, .{ .CREATE = true });
    defer w.remove(wd);

    {
        const file = try tmp.dir.createFile("foo.txt", .{});
        file.close();
    }

    var buf: [4096]u8 = undefined;
    var attempts: usize = 0;
    while (attempts < 50) : (attempts += 1) {
        std.time.sleep(10 * std.time.ns_per_ms);
        const n = w.read(&buf) catch |err| switch (err) {
            error.WouldBlock => continue,
            else => return err,
        };
        var off: usize = 0;
        while (LinuxWatch.nextEvent(buf[0..n], &off)) |ev| {
            if (ev.name) |name| {
                if (std.mem.eql(u8, name, "foo.txt")) return;
            }
        }
    }
    return error.TestExpectedEqual;
}
