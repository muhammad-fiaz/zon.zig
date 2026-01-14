//! Comprehensive benchmarks for zon.zig covering all features.

const std = @import("std");
const zon = @import("zon");
const builtin = @import("builtin");

/// Benchmark results structure
const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_time_ns: u64,
    ops_per_sec: f64,
    avg_latency_ns: f64,
    category: []const u8,

    // Static categories for grouping
    const categories = [_][]const u8{
        "Parsing",
        "Stringify",
        "Manipulation",
        "Struct Conversion",
    };
};

const ITERATIONS = 10_000;
const WARMUP = 100;

fn printResults(results: []const BenchmarkResult) void {
    std.debug.print("\n", .{});
    std.debug.print("-" ** 100, .{});
    std.debug.print("\n", .{});
    std.debug.print("                                 ZON.ZIG BENCHMARK RESULTS\n", .{});
    std.debug.print("-" ** 100, .{});
    std.debug.print("\n", .{});

    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        std.debug.print("\n[{s}]\n", .{cat});
        std.debug.print("-" ** 100, .{});
        std.debug.print("\n", .{});
        std.debug.print("{s:<40} {s:>25} {s:>25}\n", .{ "Benchmark", "Ops/sec", "Avg Latency (ns)" });
        std.debug.print("-" ** 100, .{});
        std.debug.print("\n", .{});

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                std.debug.print("{s:<50} {d:>25.0} {d:>30.0}\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                });
            }
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("=" ** 130, .{});
    std.debug.print("\n", .{});
}

fn runBenchmark(
    name: []const u8,
    allocator: std.mem.Allocator,
    comptime benchFn: anytype,
    category: []const u8,
) !BenchmarkResult {
    // Warmup
    for (0..WARMUP) |_| {
        try benchFn(allocator);
    }

    // Benchmark
    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        try benchFn(allocator);
    }
    const total_time_ns = timer.read();

    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(total_time_ns)) / 1_000_000_000.0);
    const avg_latency_ns = @as(f64, @floatFromInt(total_time_ns)) / @as(f64, @floatFromInt(ITERATIONS));

    return BenchmarkResult{
        .name = name,
        .iterations = ITERATIONS,
        .total_time_ns = total_time_ns,
        .ops_per_sec = ops_per_sec,
        .avg_latency_ns = avg_latency_ns,
        .category = category,
    };
}

// -- Benchmark Functions --

const PARSE_SOURCE =
    \\.{
    \\    .name = "benchmark_pkg",
    \\    .version = "0.1.0",
    \\    .dependencies = .{
    \\        .foo = .{
    \\            .url = "https://github.com/foo/foo",
    \\            .hash = "1234567890abcdef",
    \\        },
    \\        .bar = .{
    \\            .path = "../bar",
    \\        },
    \\    },
    \\    .paths = .{
    \\        "build.zig",
    \\        "build.zig.zon",
    \\        "src/main.zig",
    \\        "README.md",
    \\    },
    \\    .meta = .{
    \\        .author = "Performance Tester",
    \\        .license = "MIT",
    \\    },
    \\}
;

fn benchParse(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, PARSE_SOURCE);
    doc.deinit();
}

fn benchStringify(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, PARSE_SOURCE);
    defer doc.deinit();

    // We strictly benchmark stringify here, so we include the alloc/free of string
    const s = try doc.toString();
    allocator.free(s);
}

fn benchAccess(allocator: std.mem.Allocator) !void {
    // Note: Creating/destroying doc every iteration might dominate the access time.
    // Ideally we'd reuse the doc, but runBenchmark interface requires self-contained runs.
    // We will parse a smaller doc to minimize overhead.
    var doc = try zon.parse(allocator, ".{ .a = 1, .b = 2, .c = .{ .d = 3 } }");
    defer doc.deinit();

    // Perform multiple accesses to average out parse time
    var sum: i64 = 0;
    for (0..100) |_| {
        sum += doc.getInt("a").?;
        sum += doc.getInt("b").?;
        sum += doc.getInt("c.d").?;
    }
    std.mem.doNotOptimizeAway(sum);
}

fn benchModification(allocator: std.mem.Allocator) !void {
    var doc = zon.create(allocator);
    defer doc.deinit();

    // Perform multiple modifications
    for (0..100) |i| {
        try doc.setInt("count", @intCast(i));
        try doc.setBool("active", i % 2 == 0);
    }
}

const BenchStruct = struct {
    name: []const u8,
    version: []const u8,
    count: u32,
    active: bool,
    tags: []const []const u8,
};

fn benchToStruct(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{
        \\    .name = "bench",
        \\    .version = "1.0.0",
        \\    .count = 42,
        \\    .active = true,
        \\    .tags = .{ "a", "b", "c" },
        \\}
    );
    defer doc.deinit();

    const s = try doc.toStruct(BenchStruct);
    // Cleanup allocated fields
    allocator.free(s.name);
    allocator.free(s.version);
    allocator.free(s.tags);
}

fn benchFromStruct(allocator: std.mem.Allocator) !void {
    const s = BenchStruct{
        .name = "bench",
        .version = "1.0.0",
        .count = 42,
        .active = true,
        .tags = &.{ "a", "b", "c" },
    };

    var doc = try zon.fromStruct(allocator, s);
    doc.deinit();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var results: std.ArrayList(BenchmarkResult) = .empty;
    defer results.deinit(allocator);

    zon.disableUpdateCheck();

    // Parsing
    try results.append(allocator, try runBenchmark("Parse Standard ZON", allocator, benchParse, "Parsing"));

    // Stringify
    try results.append(allocator, try runBenchmark("Stringify to ZON", allocator, benchStringify, "Stringify"));

    // Manipulation
    try results.append(allocator, try runBenchmark("Read Access (100 ops)", allocator, benchAccess, "Manipulation"));
    try results.append(allocator, try runBenchmark("Modification (100 ops)", allocator, benchModification, "Manipulation"));

    // Struct Conversion
    try results.append(allocator, try runBenchmark("Document to Struct", allocator, benchToStruct, "Struct Conversion"));
    try results.append(allocator, try runBenchmark("Struct to Document", allocator, benchFromStruct, "Struct Conversion"));

    // Print all results to console
    printResults(results.items);

    // Summary Statistics
    var total_ops: f64 = 0;
    var max_ops: f64 = 0;
    var min_ops: f64 = std.math.floatMax(f64);
    var count: usize = 0;
    var max_name: []const u8 = "";
    var min_name: []const u8 = "";

    for (results.items) |r| {
        total_ops += r.ops_per_sec;
        count += 1;
        if (r.ops_per_sec > max_ops) {
            max_ops = r.ops_per_sec;
            max_name = r.name;
        }
        if (r.ops_per_sec < min_ops) {
            min_ops = r.ops_per_sec;
            min_name = r.name;
        }
    }

    const avg_ops = if (count > 0) total_ops / @as(f64, @floatFromInt(count)) else 0;
    const avg_latency = if (avg_ops > 0) 1_000_000_000.0 / avg_ops else 0;

    // Write final Markdown report
    const md_file = std.fs.cwd().createFile("benchmark-results.md", .{}) catch |err| {
        std.debug.print("Warning: Could not create benchmark-results.md: {}\n", .{err});
        return;
    };
    defer md_file.close();

    const md_header =
        \\#### 📊 ZON.ZIG BENCHMARK RESULTS
        \\
        \\**Environment Details:**
        \\- **Platform:** {s}
        \\- **Architecture:** {s}
        \\- **Warmup Iterations:** {d}
        \\- **Benchmark Iterations:** {d}
        \\
        \\
    ;

    var header_buf: [1024]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, md_header, .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        WARMUP,
        ITERATIONS,
    }) catch "";
    try md_file.writeAll(header);

    // Write categorized tables
    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        const cat_md = std.fmt.allocPrint(allocator,
            \\
            \\<details>
            \\<summary><strong>{s}</strong></summary>
            \\
            \\| Benchmark | Ops/sec (higher is better) | Avg Latency (ns) (lower is better) |
            \\| :--- | :--- | :--- |
            \\
        , .{cat}) catch continue;
        defer allocator.free(cat_md);
        try md_file.writeAll(cat_md);

        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                var line_buf: [1024]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "| {s} | {d:.0} | {d:.0} |\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                }) catch continue;
                try md_file.writeAll(line);
            }
        }
        try md_file.writeAll("</details>\n");
    }

    if (count > 0) {
        try md_file.writeAll("\n### 📈 Benchmark Summary\n\n");
        var summary_buf: [1024]u8 = undefined;
        const summary = std.fmt.bufPrint(&summary_buf,
            \\- **Total benchmarks run:** {d}
            \\- **Average throughput:** {d:.0} ops/sec
            \\- **Maximum throughput:** {d:.0} ops/sec ({s})
            \\- **Minimum throughput:** {d:.0} ops/sec ({s})
            \\- **Average latency:** {d:.0} ns
            \\
        , .{ count, avg_ops, max_ops, max_name, min_ops, min_name, avg_latency }) catch "";
        try md_file.writeAll(summary);
    }

    std.debug.print("[OK] Benchmarks completed successfully!\n", .{});
}
