const std = @import("std");
const game_lib = @import("game.zig");
const Game = @import("game.zig").Game;
const update_game_t = @TypeOf(game_lib.update_game);
const LIB_PATH = "zig-out/lib/hotreload.dll";
const LIB_DEST_DIR = "libs";
const LIB_WATCH_PATH = "zig-out/lib";
// for automatically detecting when a new dll is compiled
var change_detected = false;
// for naming the dlls to avoid name clash
var count: if (HOTRELOAD) usize else void = undefined;
var dll_file: if (HOTRELOAD) std.DynLib else void = undefined;
var update_game: if (HOTRELOAD) *update_game_t else void = undefined;

const HOTRELOAD = true;

pub fn main() !void {
    if (HOTRELOAD) {
        // clear libs dir - delete it, and recreate
        std.fs.Dir.deleteTree(std.fs.cwd(), LIB_DEST_DIR) catch unreachable;
        std.fs.Dir.makeDir(std.fs.cwd(), LIB_DEST_DIR) catch unreachable;
        count = 0;
        reloadLibrary(false) catch unreachable;
    }
    // var watcher_thread = std.Thread.spawn(.{}, dllWatcher, .{}) catch unreachable;
    // watcher_thread.detach();
    var game = Game.init();
    while (!game.quit) {
        if (HOTRELOAD) {
            if (game.should_reload_libs) {
                reloadLibrary(true) catch unreachable;
                game.should_reload_libs = false;
            }
            update_game(&game);
        } else {
            game.update();
        }
    }
    game.deinit();
}

/// Move library from zig-out to libs folder, and rename it with the count suffix
fn reloadLibrary(should_close: bool) !void {
    if (should_close) dll_file.close();
    var buffer: [128]u8 = undefined;
    const out_path = std.fmt.bufPrintZ(&buffer, "{s}/game_{d}.dll", .{ LIB_DEST_DIR, count }) catch unreachable;
    try std.fs.Dir.copyFile(std.fs.cwd(), LIB_PATH, std.fs.cwd(), out_path, .{});
    dll_file = try std.DynLib.open(out_path);
    update_game = dll_file.lookup(*update_game_t, "update_game").?;
    count += 1;
    std.debug.print("reloading dll: {s}\n", .{out_path});
}

// ---
// stuff that doesn't work for various reasons

// zig 0.12.0-dev.25+36c57c3ba - Not implemented async, so the default watcher doesnt work.
fn dllWatcherAsync() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var watch = try std.fs.Watch(void).init(arena.allocator(), 8);
    defer watch.deinit();
    _ = watch.addFile(LIB_PATH, {}) catch unreachable;
    var event = watch.channel.get();
    switch (event.id) {
        .CloseWrite => {
            std.debug.print("dll closewrite\n", .{});
            change_detected = true;
        },
        .Delete => {
            std.debug.print("dll delete\n", .{});
        },
    }
}

// attempted to implement the watch functionality synchronously.
// couldn't get it to work. a windows error throws unreachable because of invalid flags
fn dllWatcher() void {
    const dir_handle = std.os.windows.OpenFile(&[_]u16{'.'}, .{
        .dir = std.fs.cwd().fd,
        .access_mask = std.os.windows.FILE_LIST_DIRECTORY,
        .creation = std.os.windows.FILE_FLAG_BACKUP_SEMANTICS,
        .io_mode = .blocking,
        .filter = .dir_only,
    }) catch unreachable;
    var event_buf: [4096]u8 align(@alignOf(std.os.windows.FILE_NOTIFY_INFORMATION)) = undefined;
    var num_bytes: u32 = 0;
    _ = std.os.windows.kernel32.ReadDirectoryChangesW(
        dir_handle,
        &event_buf,
        event_buf.len,
        std.os.windows.FALSE, // watch subtree
        std.os.windows.FILE_NOTIFY_CHANGE_FILE_NAME | std.os.windows.FILE_NOTIFY_CHANGE_DIR_NAME |
            std.os.windows.FILE_NOTIFY_CHANGE_ATTRIBUTES | std.os.windows.FILE_NOTIFY_CHANGE_SIZE |
            std.os.windows.FILE_NOTIFY_CHANGE_LAST_WRITE | std.os.windows.FILE_NOTIFY_CHANGE_LAST_ACCESS |
            std.os.windows.FILE_NOTIFY_CHANGE_CREATION | std.os.windows.FILE_NOTIFY_CHANGE_SECURITY,
        &num_bytes, // number of bytes transferred (unused for async)
        null,
        null, // completion routine - unused because we use IOCP
    );
    std.debug.print("hi\n", .{});
}
