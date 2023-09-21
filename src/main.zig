const std = @import("std");
const game_lib = @import("game.zig");
const Game = @import("game.zig").Game;
const build_options = @import("build_options");
const updateGame_t = @TypeOf(game_lib.updateGame);
// for automatically detecting when a new dll is compiled
var change_detected = false;
var dll_file: if (HOTRELOAD) std.DynLib else void = undefined;
var updateGame: if (HOTRELOAD) *updateGame_t else void = undefined;
var watcher_thread: std.Thread = undefined;

const HOTRELOAD = build_options.hotreload;
const LIB_SRC_DIR = "zig-out/lib";
const LIB_DEST_DIR = "libs";
const LIB_WATCH_PATH = "zig-out\\lib";
const CopyFile = struct { src: []const u8, dst: []const u8 };
const FILES_TO_COPY = [_]CopyFile{
    .{ .src = LIB_SRC_DIR ++ "/hotreload.pdb", .dst = LIB_DEST_DIR ++ "/hotreload.pdb" },
    .{ .src = LIB_SRC_DIR ++ "/hotreload.dll", .dst = LIB_DEST_DIR ++ "/hotreload.dll" },
    .{ .src = LIB_SRC_DIR ++ "/hotreload.lib", .dst = LIB_DEST_DIR ++ "/hotreload.lib" },
};

pub fn main() !void {
    if (HOTRELOAD) {
        reloadLibrary(false) catch unreachable;
        spawnWatcher();
    }
    var game = Game.init();
    defer game.deinit();
    while (!game.quit) {
        if (HOTRELOAD) {
            if (change_detected) {
                reloadLibrary(true) catch unreachable;
                change_detected = false;
                spawnWatcher();
            }
            updateGame(&game);
        } else {
            game.update();
        }
    }
}

/// Move library from zig-out to libs folder
/// When first loading, run with close_dll = false. On hotreload, close_dll = true
fn reloadLibrary(close_dll: bool) !void {
    if (close_dll) dll_file.close();
    for (FILES_TO_COPY) |paths| try std.fs.Dir.copyFile(std.fs.cwd(), paths.src, std.fs.cwd(), paths.dst, .{});
    const out_path = LIB_DEST_DIR ++ "/hotreload.dll";
    dll_file = try std.DynLib.open(out_path);
    std.debug.print("reloaded dll: {s}\n", .{out_path});
    updateGame = dll_file.lookup(*updateGame_t, "updateGame").?;
}

/// Spawn a thread that runs the dllWatcher function. The function is blocking, so we
/// run it in a different thread.
fn spawnWatcher() void {
    watcher_thread = std.Thread.spawn(.{}, dllWatcher, .{}) catch unreachable;
    watcher_thread.detach();
}

/// Directory watcher for windows. Copied from std.fs.Watch, and then hacked around
/// a bit to get it to work. May not be ideal, but gets the job done.
fn dllWatcher() void {
    var dirname_path_space: std.os.windows.PathSpace = undefined;
    dirname_path_space.len = std.unicode.utf8ToUtf16Le(&dirname_path_space.data, LIB_WATCH_PATH) catch unreachable;
    dirname_path_space.data[dirname_path_space.len] = 0;
    const dir_handle = std.os.windows.OpenFile(dirname_path_space.span(), .{
        .dir = std.fs.cwd().fd,
        .access_mask = std.os.windows.GENERIC_READ,
        .creation = std.os.windows.FILE_OPEN,
        .io_mode = .blocking,
        .filter = .dir_only,
        .follow_symlinks = false,
    }) catch |err| {
        std.debug.print("Error in opening file: {any}\n", .{err});
        unreachable;
    };
    var event_buf: [4096]u8 align(@alignOf(std.os.windows.FILE_NOTIFY_INFORMATION)) = undefined;
    var num_bytes: u32 = 0;
    _ = std.os.windows.kernel32.ReadDirectoryChangesW(
        dir_handle,
        &event_buf,
        event_buf.len,
        std.os.windows.FALSE,
        std.os.windows.FILE_NOTIFY_CHANGE_FILE_NAME | std.os.windows.FILE_NOTIFY_CHANGE_DIR_NAME |
            std.os.windows.FILE_NOTIFY_CHANGE_ATTRIBUTES | std.os.windows.FILE_NOTIFY_CHANGE_SIZE |
            std.os.windows.FILE_NOTIFY_CHANGE_LAST_WRITE | std.os.windows.FILE_NOTIFY_CHANGE_LAST_ACCESS |
            std.os.windows.FILE_NOTIFY_CHANGE_CREATION | std.os.windows.FILE_NOTIFY_CHANGE_SECURITY,
        &num_bytes,
        null,
        null,
    );
    change_detected = true;
}

// ---
// stuff that doesn't work for various reasons

// // zig 0.12.0-dev.25+36c57c3ba - Not implemented async, so the default watcher doesnt work.
// fn dllWatcherAsync() void {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     var watch = try std.fs.Watch(void).init(arena.allocator(), 8);
//     defer watch.deinit();
//     _ = watch.addFile(LIB_PATH, {}) catch unreachable;
//     var event = watch.channel.get();
//     switch (event.id) {
//         .CloseWrite => {
//             std.debug.print("dll closewrite\n", .{});
//             change_detected = true;
//         },
//         .Delete => {
//             std.debug.print("dll delete\n", .{});
//         },
//     }
// }
