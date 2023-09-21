const std = @import("std");

pub const BuildMode = enum {
    /// Build static executable
    static_exe,
    /// Build dynamic executable and dynamic library
    dynamic_exe,
    /// Build dynamic library
    hotreload,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_mode = b.option(BuildMode, "build_mode", "Can be static_exe, dynamic_exe or hotreload") orelse .static_exe;

    const build_exe = (build_mode == .static_exe or build_mode == .dynamic_exe);
    const build_lib = (build_mode == .hotreload or build_mode == .dynamic_exe);
    const hotreload = build_lib;
    var options = b.addOptions();
    options.addOption(bool, "hotreload", hotreload);

    const exe = b.addExecutable(.{
        .name = "reload",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.addOptions("build_options", options);
    exe.addSystemIncludePath(.{ .path = "C:/SDL2-2.26.5/include" });
    exe.addLibraryPath(.{ .path = "C:/SDL2-2.26.5/lib/x64" });
    exe.linkSystemLibrary("sdl2");
    exe.linkLibC();
    if (build_exe) b.installArtifact(exe);

    const lib = b.addSharedLibrary(.{
        .name = "hotreload",
        .root_source_file = .{ .path = "src/game.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.addOptions("build_options", options);
    lib.addSystemIncludePath(.{ .path = "C:/SDL2-2.26.5/include" });
    lib.addLibraryPath(.{ .path = "C:/SDL2-2.26.5/lib/x64" });
    lib.linkSystemLibrary("sdl2");
    lib.linkLibC();
    if (build_lib) b.installArtifact(lib);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
