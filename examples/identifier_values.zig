//! Identifier Values Example
//!
//! Demonstrates reading and writing ZON identifier values like `.name = .value`

const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Identifier Values Example ===\n\n", .{});

    // Parse a build.zig.zon style document with identifier values
    const source =
        \\.{
        \\    .name = .my_package,
        \\    .version = "1.0.0",
        \\    .fingerprint = 0xee480fa30d50cbf6,
        \\    .minimum_zig_version = "0.17.0",
        \\    .dependencies = .{
        \\        .http = .{
        \\            .url = "https://github.com/example/http.git",
        \\            .hash = "abc123def456",
        \\        },
        \\    },
        \\    .paths = .{
        \\        "build.zig",
        \\        "build.zig.zon",
        \\        "src",
        \\    },
        \\}
    ;

    std.debug.print("=== Parsing ZON with identifier values ===\n", .{});
    var doc = try zon.parse(allocator, source);
    defer doc.deinit();

    // Read identifier value - returns the value without the dot
    if (doc.getIdentifier("name")) |name| {
        std.debug.print("Package name (identifier): .{s}\n", .{name});
    }

    // getString also works for identifiers
    if (doc.getString("name")) |name| {
        std.debug.print("Package name (string): {s}\n", .{name});
    }

    // Check if value is an identifier
    if (doc.isIdentifier("name")) {
        std.debug.print("'name' is an identifier type\n", .{});
    }

    // Get type
    if (doc.getType("name")) |t| {
        std.debug.print("Type of 'name': {s}\n", .{t});
    }

    // Read version string
    if (doc.getString("version")) |ver| {
        std.debug.print("Version: {s}\n", .{ver});
    }

    // Read large hex fingerprint
    if (doc.getInt("fingerprint")) |fp| {
        const unsigned: u64 = @bitCast(fp);
        std.debug.print("Fingerprint: 0x{x}\n", .{unsigned});
    }

    // Read nested dependency
    if (doc.getString("dependencies.http.url")) |url| {
        std.debug.print("HTTP dependency: {s}\n", .{url});
    }

    // Read array elements
    std.debug.print("\nPaths:\n", .{});
    var i: usize = 0;
    while (doc.getArrayString("paths", i)) |path| : (i += 1) {
        std.debug.print("  - {s}\n", .{path});
    }

    // Create a new document with identifier-style values
    std.debug.print("\n=== Creating document with setIdentifier ===\n", .{});

    var newDoc = zon.create(allocator);
    defer newDoc.deinit();

    // Use setIdentifier for .name = .value syntax
    try newDoc.setIdentifier("name", "downloader");
    try newDoc.setString("version", "0.1.0");
    try newDoc.setString("minimum_zig_version", "0.17.0");

    // Set fingerprint as large integer
    const fingerprint: u64 = 0xaabbccdd11223344;
    try newDoc.setInt("fingerprint", @bitCast(fingerprint));

    // Add paths array
    try newDoc.setArray("paths");
    try newDoc.appendToArray("paths", "build.zig");
    try newDoc.appendToArray("paths", "build.zig.zon");
    try newDoc.appendToArray("paths", "src");

    // Add dependencies
    try newDoc.setString("dependencies.http.url", "https://github.com/example/http");
    try newDoc.setString("dependencies.http.hash", "abc123");

    const output = try newDoc.toString();
    defer allocator.free(output);

    std.debug.print("\nGenerated ZON (note .name = .downloader):\n{s}\n", .{output});

    // Verify the identifier
    std.debug.print("\n=== Verifying identifier ===\n", .{});
    std.debug.print("isIdentifier('name'): {}\n", .{newDoc.isIdentifier("name")});
    std.debug.print("getIdentifier('name'): .{s}\n", .{newDoc.getIdentifier("name").?});
    std.debug.print("getType('name'): {s}\n", .{newDoc.getType("name").?});
}
