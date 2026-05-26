const std = @import("std");
const zon = @import("zon");

/// Example: Walking and mapping values in a ZON document
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Walk Example ===\n\n", .{});

    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try doc.setInt("version", 1);
    try doc.setBool("active", true);
    try doc.setString("config.host", "localhost");
    try doc.setInt("config.port", 8080);

    // Walk all paths and print them
    std.debug.print("All paths in document:\n", .{});

    const Ctx = struct {
        count: usize,
    };
    var ctx = Ctx{ .count = 0 };

    doc.walk(&ctx, struct {
        fn visit(c: *Ctx, path: []const u8, _: *const zon.Value) void {
            std.debug.print("  [{d}] {s}\n", .{ c.count, path });
            c.count += 1;
        }
    }.visit);

    std.debug.print("\n=== Map Values Example ===\n\n", .{});

    // Map all string values to uppercase
    const MapCtx = struct {
        doc: *zon.Document,
        allocator: std.mem.Allocator,
        fn upper(c: *@This(), path: []const u8, value: zon.Value) anyerror!zon.Value {
            _ = path;
            if (value == .string) {
                var owned = value;
                const result_str = try std.ascii.allocUpperString(c.allocator, owned.string);
                owned.deinit(c.allocator);
                return zon.Value{ .string = result_str };
            }
            return value;
        }
    };
    var map_ctx = MapCtx{ .doc = &doc, .allocator = allocator };
    try doc.mapValues(&map_ctx, MapCtx.upper);

    std.debug.print("After uppercasing strings:\n", .{});
    std.debug.print("  name = {s}\n", .{doc.getString("name").?});
    std.debug.print("  config.host = {s}\n", .{doc.getString("config.host").?});

    std.debug.print("\n=== Using paths() ===\n\n", .{});

    const all_paths = try doc.paths();
    defer {
        for (all_paths) |p| allocator.free(p);
        allocator.free(all_paths);
    }

    std.debug.print("Number of paths: {d}\n", .{all_paths.len});
    for (all_paths) |p| {
        std.debug.print("  {s}\n", .{p});
    }
}
