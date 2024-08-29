const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    _ = b.addModule("zDisplay", .{
        .root_source_file = b.path("src/zDisplay.zig"),
        .target = target,
        .optimize = optimize,
    });
}
