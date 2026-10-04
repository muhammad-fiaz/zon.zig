const std = @import("std");
const zon = @import("zon");

/// Example: explicit client-side I/O with `std.Io`.
///
/// This example never touches the library's internal file helpers.
/// The client opens, reads, stats, renames, and deletes files directly
/// with `std.Io`, owns every buffer, and only hands plain bytes to the
/// library for parsing (`zon.parse`) and serialization (`doc.toString`).
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // The client owns I/O explicitly: one `std.Io` handle for everything.
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();

    const path = "explicit_io.zon";
    defer std.Io.Dir.deleteFile(cwd, io, path) catch {};

    // Explicit CREATE + WRITE with std.io.
    const created = try std.Io.Dir.createFile(cwd, io, path, .{});
    defer created.close(io);
    try std.Io.File.writeStreamingAll(created, io, ".{ .app = \"demo\" }\n");

    // Explicit READ with std.io: the client owns the returned bytes.
    const source = try std.Io.Dir.readFileAlloc(cwd, io, path, allocator, .limited(1024 * 1024));
    defer allocator.free(source);
    std.debug.print("read {d} bytes\n", .{source.len});

    // Hand the bytes to the library for parsing (no I/O inside).
    var doc = try zon.parse(allocator, source);
    defer doc.deinit();

    // EDIT fully in memory (no I/O).
    try doc.setString("app.owner", "zon");
    try doc.setInt("app.port", 8080);
    std.debug.print("owner: {s}\n", .{doc.getString("app.owner").?});

    // Serialize (no I/O), then WRITE the bytes back explicitly with std.io.
    const out = try doc.toString();
    defer allocator.free(out);
    const rewritten = try std.Io.Dir.createFile(cwd, io, path, .{});
    defer rewritten.close(io);
    try std.Io.File.writeStreamingAll(rewritten, io, out);
    try std.Io.File.writeStreamingAll(rewritten, io, "\n");

    // Explicit STAT / EXISTS / RENAME with std.io.
    const stat = try std.Io.Dir.statFile(cwd, io, path, .{});
    std.debug.print("size: {d} bytes\n", .{stat.size});
    std.Io.Dir.access(cwd, io, path, .{}) catch unreachable;
    std.debug.print("exists: {}\n", .{true});

    const renamed = "explicit_io_renamed.zon";
    defer std.Io.Dir.deleteFile(cwd, io, renamed) catch {};
    try std.Io.Dir.rename(cwd, path, cwd, renamed, io);

    // Explicit READ of the renamed file, then a round-trip check.
    const moved = try std.Io.Dir.readFileAlloc(cwd, io, renamed, allocator, .limited(1024 * 1024));
    defer allocator.free(moved);
    var check = try zon.parse(allocator, moved);
    defer check.deinit();
    std.debug.print("round-trip port: {d}\n", .{check.getInt("app.port").?});
}
