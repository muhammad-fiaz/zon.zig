const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Example paths
    const a = "example_a.zon";
    const b = "example_b.zon";
    const c = "example_c.zon";
    const backup_ext = ".bak";

    // 1) Create a document and atomically save it
    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("name", "file_ops_example");
    doc.file_path = try allocator.dupe(u8, a);

    std.debug.print("Saving document atomically to {s}\n", .{a});
    try doc.saveAsAtomic(a);

    // 2) Read the saved file
    const data = try zon.readFile(allocator, a);
    defer allocator.free(data);
    std.debug.print("Read {d} bytes from {s}\n", .{ data.len, a });

    // 3) Copy file (with overwrite)
    std.debug.print("Copying {s} -> {s}\n", .{ a, b });
    try zon.copyFile(a, b, true);

    // 4) Move file (rename) with overwrite
    std.debug.print("Renaming {s} -> {s}\n", .{ b, c });
    try zon.moveFile(b, c, true);

    // 5) Save with backup
    std.debug.print("Saving document with backup extension {s}\n", .{backup_ext});
    try doc.saveWithBackup(backup_ext);

    // 6) Modify and save only when changed
    try doc.setString("version", "1.0.0");
    const written = try doc.saveIfChanged();
    std.debug.print("saveIfChanged wrote file? {s}\n", .{if (written) "yes" else "no"});

    // 7) Demonstrate parser.parseFile
    std.debug.print("Parsing file {s} with zon.open\n", .{a});
    var parsed = try zon.open(allocator, a);
    defer parsed.deinit();
    std.debug.print("Parsed keys count (root.count): {d}\n", .{parsed.count()});

    // 8) Demonstrate reading source (tokenizer helper available as tokenizer.loadSourceFromFile)
    const src = try zon.readFile(allocator, a);
    defer allocator.free(src);
    std.debug.print("Loaded source length: {d}\n", .{src.len});

    // 9) Demonstrate stringify.writeToFileAtomic via zon.writeFileAtomic helper
    const out_path = "stringified.zon";
    const out_data = try parsed.toString();
    defer allocator.free(out_data);
    std.debug.print("Atomically writing parsed document to {s}\n", .{out_path});
    try zon.writeFileAtomic(allocator, out_path, out_data);

    // 10) Cleanup demo files
    _ = std.fs.cwd().deleteFile(a) catch null;
    _ = std.fs.cwd().deleteFile(c) catch null;
    _ = std.fs.cwd().deleteFile(out_path) catch null;
    const backup_name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ a, backup_ext });
    defer allocator.free(backup_name);
    _ = std.fs.cwd().deleteFile(backup_name) catch null;

    std.debug.print("File operations demo completed successfully.\n", .{});
}
