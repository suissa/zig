const std = @import("std");
const posix = std.posix;

const WatchMap = std.AutoHashMap(i32, []const u8);

fn addWatchForDir(inotify_fd: i32, dir_path: []const u8, allocator: std.mem.Allocator, map: *WatchMap) !void {
    const mask = posix.linux.IN.CREATE |
        posix.linux.IN.MODIFY |
        posix.linux.IN.CLOSE_WRITE |
        posix.linux.IN.MOVED_TO |
        posix.linux.IN.MOVED_FROM |
        posix.linux.IN.DELETE |
        posix.linux.IN.DELETE_SELF |
        posix.linux.IN.MOVE_SELF;

    const wd = try posix.inotify_add_watch(inotify_fd, dir_path, mask);
    const copy = try allocator.dupe(u8, dir_path);
    try map.put(wd, copy);
}

fn addRecursive(inotify_fd: i32, root: []const u8, allocator: std.mem.Allocator, map: *WatchMap) !void {
    try addWatchForDir(inotify_fd, root, allocator, map);

    var dir = try std.fs.cwd().openDir(root, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.eql(u8, entry.name, ".") or std.mem.eql(u8, entry.name, "..")) continue;

        const child = try std.fs.path.join(allocator, &.{ root, entry.name });
        defer allocator.free(child);
        try addRecursive(inotify_fd, child, allocator, map);
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next();
    const root = args.next() orelse {
        std.log.err("uso: zig run watch_fileserver.zig -- <pasta>", .{});
        return;
    };

    var root_dir = std.fs.cwd().openDir(root, .{}) catch {
        std.log.err("erro: caminho '{s}' não é uma pasta válida", .{root});
        return;
    };
    root_dir.close();

    const inotify_fd = try posix.inotify_init1(posix.linux.IN.CLOEXEC);
    defer posix.close(inotify_fd);

    var map = WatchMap.init(allocator);
    defer {
        var it = map.valueIterator();
        while (it.next()) |p| allocator.free(p.*);
        map.deinit();
    }

    try addRecursive(inotify_fd, root, allocator, &map);
    std.log.info("monitorando {s} (incluindo subpastas)", .{root});

    var buf: [4096]u8 align(@alignOf(posix.linux.inotify_event)) = undefined;
    while (true) {
        const n = try posix.read(inotify_fd, &buf);
        var off: usize = 0;

        while (off < n) {
            const ev: *const posix.linux.inotify_event = @ptrCast(@alignCast(buf[off..].ptr));
            const wd_path = map.get(ev.wd) orelse "<desconhecido>";
            const name_slice = if (ev.len > 0)
                std.mem.sliceTo(@as([*:0]const u8, @ptrCast(buf[off + @sizeOf(posix.linux.inotify_event) ..].ptr)), 0)
            else
                "";

            if ((ev.mask & posix.linux.IN.ISDIR) != 0 and (ev.mask & (posix.linux.IN.CREATE | posix.linux.IN.MOVED_TO)) != 0 and name_slice.len > 0) {
                const new_dir = try std.fs.path.join(allocator, &.{ wd_path, name_slice });
                defer allocator.free(new_dir);
                addWatchForDir(inotify_fd, new_dir, allocator, &map) catch {};
            }

            std.log.info("evento mask=0x{x} pasta={s} nome={s}", .{ ev.mask, wd_path, name_slice });

            off += @sizeOf(posix.linux.inotify_event) + ev.len;
        }
    }
}
