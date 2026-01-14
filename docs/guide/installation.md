---
title: "Installation"
description: "Installation instructions for zon.zig: using `zig fetch` or adding as a dependency in your `build.zig.zon`."
---

# Installation

## Package Manager

### Step 1: Add Dependency

Add to your `build.zig.zon`:

```zig
.{
    .name = .your_project,
    .version = "0.1.0",
    .dependencies = .{
        .zon = .{
            .url = "https://github.com/muhammad-fiaz/zon.zig/archive/refs/tags/0.0.4.tar.gz",
            .hash = "...",
        },
    },
    .paths = .{ "build.zig", "build.zig.zon", "src" },
}
```

### Step 2: Fetch Hash

Run this command to get the hash:

```bash
zig fetch --save https://github.com/muhammad-fiaz/zon.zig/archive/refs/tags/0.0.4.tar.gz
```

or

for nightly installation, use this command:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zon.zig.git
```

This automatically updates your `build.zig.zon` with the correct hash.

### Step 3: Update build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add zon.zig dependency
    const zon_dep = b.dependency("zon", .{
        .target = target,
        .optimize = optimize,
    });

    // Create executable
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Import zon module
    exe.root_module.addImport("zon", zon_dep.module("zon"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
```

### Step 4: Use in Code

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("hello", "world");

    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});
}
```

### Step 5: Build and Run

```bash
zig build run
```

**Output:**

```zig
.{
    .hello = "world",
}
```

## Manual Installation

### Clone Repository

```bash
git clone https://github.com/muhammad-fiaz/zon.zig.git
```

### Add as Local Dependency

In your `build.zig.zon`:

```zig
.dependencies = .{
    .zon = .{
        .path = "../zon.zig",
    },
},
```

## Prebuilt Libraries

Download prebuilt static libraries from [GitHub Releases](https://github.com/muhammad-fiaz/zon.zig/releases).

| Platform | Architecture | File                     |
| -------- | ------------ | ------------------------ |
| Windows  | x86_64       | `zon-x86_64-windows.lib` |
| Windows  | x86          | `zon-x86-windows.lib`    |
| Linux    | x86_64       | `libzon-x86_64-linux.a`  |
| Linux    | aarch64      | `libzon-aarch64-linux.a` |
| macOS    | x86_64       | `libzon-x86_64-macos.a`  |
| macOS    | aarch64      | `libzon-aarch64-macos.a` |

### Using Prebuilt Library

```zig
exe.addLibraryPath(b.path("libs"));
exe.linkSystemLibrary("zon");
```

## Verify Installation

Create `test.zig`:

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    std.debug.print("zon.zig version: {s}\n", .{zon.version});
}
```

Run:

```bash
zig build run
```

**Output:**

```
zon.zig version: 0.0.4
```

## Requirements

- **Zig 0.15.0** or later
- No external dependencies
- Cross-platform: Windows, Linux, macOS

## Troubleshooting

### Hash Mismatch

If you get a hash mismatch error:

```bash
zig fetch --save https://github.com/muhammad-fiaz/zon.zig/archive/refs/tags/0.0.4.tar.gz
```

### Module Not Found

Ensure you've added the import in your `build.zig`:

```zig
exe.root_module.addImport("zon", zon_dep.module("zon"));
```

### Compiler Version

Check your Zig version:

```bash
zig version
```

Requires 0.15.0 or later.
