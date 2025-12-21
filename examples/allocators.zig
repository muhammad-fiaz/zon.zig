const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    // Demo 1: Using GeneralPurposeAllocator (GPA)
    // Best for: Long-running applications where you modify documents over time
    // and want to detect memory leaks.
    try demoGPA();

    // Demo 2: Using ArenaAllocator
    // Best for: CLI tools or tasks where you load a document, do some work,
    // and want to free everything at once. Extremely fast.
    try demoArena();
}

fn demoGPA() !void {
    std.debug.print("--- Demo: GeneralPurposeAllocator (GPA) ---\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create or open a document
    var doc = zon.create(allocator);
    // When using GPA, explicit cleanup is important to avoid leaks
    defer doc.close();

    try doc.setString("project", "GPA Demo");
    try doc.setInt("timestamp", std.time.timestamp());

    const output = try doc.toString();
    defer allocator.free(output);

    std.debug.print("Document created with GPA: {s}", .{output});
}

fn demoArena() !void {
    std.debug.print("\n--- Demo: ArenaAllocator (Backing: Page Allocator) ---\n", .{});

    // An ArenaAllocator is a wrapper. It needs a "child" allocator to request
    // memory blocks from. Using page_allocator is the fastest way for one-off tasks.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // Everything allocated via 'allocator' will be freed here in one go.
    defer arena.deinit();
    const allocator = arena.allocator();

    // Open an existing file if it exists, or create a mock string to parse
    const source =
        \\.{
        \\    .name = "Arena Example",
        \\    .features = .{ "Fast", "Simple", "Safe" },
        \\}
    ;

    var doc = try zon.parse(allocator, source);
    // doc.close() is optional here because the arena handles it,
    // but it's still good practice or if you want to be explicit.
    // defer doc.close();

    std.debug.print("Reading from Arena-allocated document:\n", .{});
    std.debug.print("  Name: {s}\n", .{doc.getString("name").?});

    var i: usize = 0;
    std.debug.print("  Features: ", .{});
    while (doc.getArrayString("features", i)) |feature| : (i += 1) {
        std.debug.print("{s}{s}", .{ feature, if (i < 2) ", " else "" });
    }
    std.debug.print("\n", .{});

    // Demo 3: Opening an existing file with Arena
    std.debug.print("\n--- Demo: Open Existing File with Arena ---\n", .{});

    // Write a temporary file for the demo
    try std.fs.cwd().writeFile(.{ .sub_path = "existing.zon", .data = ".{ .os = \"Zig\", .version = \"0.15.0\" }" });
    defer std.fs.cwd().deleteFile("existing.zon") catch {};

    var file_doc = try zon.open(allocator, "existing.zon");
    // Result
    std.debug.print("Opened existing.zon:\n", .{});
    std.debug.print("  OS: {s}\n", .{file_doc.getString("os").?});
    std.debug.print("  Version: {s}\n", .{file_doc.getString("version").?});
}
