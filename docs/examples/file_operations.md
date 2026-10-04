---
title: "File Operations Example"
description: "Atomic writes, backups, copy, move, validation, and change detection."
---

# File Operations Example

**Usecase:** the safe file workflows — atomic writes, backups
(`saveWithBackup`), conditional writes (`saveIfChanged`), copy/move with
overwrite control, file validation, and change detection.

**Run:** `zig build run-file_operations`

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Example paths
    const a = "exampleA.zon";
    const b = "exampleB.zon";
    const c = "exampleC.zon";
    const backupExt = ".bak";

    // 1) Create a document and atomically save it
    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("name", "file_ops_example");
    doc.filePath = try allocator.dupe(u8, a);

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
    std.debug.print("Saving document with backup extension {s}\n", .{backupExt});
    try doc.saveWithBackup(backupExt);

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
    const outPath = "stringified.zon";
    const outData = try parsed.toString();
    defer allocator.free(outData);
    std.debug.print("Atomically writing parsed document to {s}\n", .{outPath});
    try zon.writeFileAtomic(allocator, outPath, outData);

    // 10) Cleanup demo files
    zon.deleteFile(a) catch {};
    zon.deleteFile(c) catch {};
    zon.deleteFile(outPath) catch {};
    const backupName = try std.fmt.allocPrint(allocator, "{s}{s}", .{ a, backupExt });
    defer allocator.free(backupName);
    zon.deleteFile(backupName) catch {};

    std.debug.print("File operations demo completed successfully.\n", .{});
}
```

Actual output:

```bash
Read 37 bytes from exampleA.zon
Copying exampleA.zon -> exampleB.zon
Renaming exampleB.zon -> exampleC.zon
Saving document with backup extension .bak
saveIfChanged wrote file? yes
Parsing file exampleA.zon with zon.open
Parsed keys count (root.count): 2
Loaded source length: 61
Atomically writing parsed document to stringified.zon
File operations demo completed successfully.
```
