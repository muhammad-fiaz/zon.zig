---
# https://vitepress.dev/reference/default-theme-home-page
layout: home
title: "zon.zig"
description: "zon.zig is a small, zero-dependency Zig library for parsing, manipulating, and writing ZON configuration files. Supports reading, writing, find & replace, merge & clone, arrays, and pretty printing."
keywords: ["Zig","ZON","zon","configuration","parser","serializer","pretty-print"]

hero:
  name: "ZON.zig"
  text: "ZON File Library"
  tagline: A simple, direct Zig library for reading and writing ZON files
  image:
    src: /logo.svg
    alt: zon.zig
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: API Reference
      link: /api/
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/zon.zig

features:
  - icon: 📦
    title: Simple API
    details: Intuitive getter/setter interface with dot notation for nested paths. Auto-creates intermediate objects automatically.
  - icon: 🔧
    title: Full ZON Support
    details: Supports all ZON types including identifiers (.name = .value), large hex numbers, arrays, and nested objects.
  - icon: 🔍
    title: Find & Replace
    details: Search for values across your document and replace them with a single function call.
  - icon: 🔄
    title: Merge & Clone
    details: Deep clone documents and merge configurations together for environment-specific setups.
  - icon: 🎨
    title: Pretty Print
    details: Configurable output formatting with custom indentation levels or compact output.
  - icon: ⚡
    title: Pure Zig
    details: No dependencies on Zig compiler internals. Cross-platform with Windows, Linux, and macOS support.
---

## Quick Start

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

    try doc.setIdentifier("name", "my_app");
    try doc.setString("version", "1.0.0");
    try doc.setInt("port", 8080);
    try doc.setString("database.host", "localhost");

    try doc.saveAs("config.zon");
}
```

**Output (`config.zon`):**

```zig
.{
    .database = .{
        .host = "localhost",
    },
    .name = .my_app,
    .port = 8080,
    .version = "1.0.0",
}
```

## Installation

```bash
zig fetch --save https://github.com/muhammad-fiaz/zon.zig/archive/refs/tags/v0.0.2.tar.gz
```

Then in your `build.zig`:

```zig
const zon_dep = b.dependency("zon", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zon", zon_dep.module("zon"));
```

## License

MIT License - [View on GitHub](https://github.com/muhammad-fiaz/zon.zig/blob/main/LICENSE)
