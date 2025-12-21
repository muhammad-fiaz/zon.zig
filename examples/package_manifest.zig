const std = @import("std");
const zon = @import("zon");

/// Example: Parsing and modifying a build.zig.zon file
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Parsing build.zig.zon format ===\n\n", .{});

    const source =
        \\.{
        \\    .name = .my_package,
        \\    .version = "0.1.0",
        \\    .fingerprint = 0xee480fa30d50cbf6,
        \\    .minimum_zig_version = "0.15.0",
        \\    .paths = .{
        \\        "build.zig",
        \\        "build.zig.zon",
        \\        "src",
        \\        "README.md",
        \\        "LICENSE",
        \\    },
        \\    .dependencies = .{
        \\        .http = .{
        \\            .url = "https://github.com/example/http.git",
        \\            .hash = "abc123def456",
        \\        },
        \\    },
        \\}
    ;

    var doc = try zon.parse(allocator, source);
    defer doc.deinit();

    std.debug.print("Package name: {s}\n", .{doc.getString("name").?});
    std.debug.print("Version: {s}\n", .{doc.getString("version").?});
    std.debug.print("Min Zig version: {s}\n", .{doc.getString("minimum_zig_version").?});

    if (doc.getUint("fingerprint")) |fp| {
        std.debug.print("Fingerprint: 0x{x}\n", .{fp});
    }

    std.debug.print("\nPaths ({d} items):\n", .{doc.arrayLen("paths").?});
    var i: usize = 0;
    while (doc.getArrayString("paths", i)) |path| : (i += 1) {
        std.debug.print("  - {s}\n", .{path});
    }

    std.debug.print("\nDependency URL: {s}\n", .{doc.getString("dependencies.http.url").?});
    std.debug.print("Dependency hash: {s}\n", .{doc.getString("dependencies.http.hash").?});

    std.debug.print("\n=== Modifying the package ===\n\n", .{});

    try doc.setString("version", "0.2.0");
    try doc.setString("dependencies.json.url", "https://github.com/example/json.git");
    try doc.setString("dependencies.json.hash", "xyz789");

    std.debug.print("New version: {s}\n", .{doc.getString("version").?});
    std.debug.print("Added JSON dependency: {s}\n", .{doc.getString("dependencies.json.url").?});

    std.debug.print("\n=== Final ZON ===\n\n", .{});

    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});
}
