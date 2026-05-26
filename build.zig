const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the zon module
    const zon_module = b.createModule(.{
        .root_source_file = b.path("src/zon.zig"),
    });

    // Expose the module for external projects that depend on this package.
    _ = b.addModule("zon", .{
        .root_source_file = b.path("src/zon.zig"),
    });

    const examples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "basic", .path = "examples/basic.zig" },
        .{ .name = "package_manifest", .path = "examples/package_manifest.zig" },
        .{ .name = "find_replace", .path = "examples/find_replace.zig" },
        .{ .name = "arrays", .path = "examples/arrays.zig" },
        .{ .name = "pretty_print", .path = "examples/pretty_print.zig" },
        .{ .name = "merge_clone", .path = "examples/merge_clone.zig" },
        .{ .name = "config_management", .path = "examples/config_management.zig" },
        .{ .name = "error_handling", .path = "examples/error_handling.zig" },
        .{ .name = "file_operations", .path = "examples/file_operations.zig" },
        .{ .name = "nested_creation", .path = "examples/nested_creation.zig" },
        .{ .name = "identifier_values", .path = "examples/identifier_values.zig" },
        .{ .name = "allocators", .path = "examples/allocators.zig" },
        .{ .name = "struct_conversion", .path = "examples/struct_conversion.zig" },
        .{ .name = "walk_map", .path = "examples/walk_map.zig" },
        .{ .name = "pick_omit", .path = "examples/pick_omit.zig" },
        .{ .name = "sort_format", .path = "examples/sort_format.zig" },
        .{ .name = "validation_sort", .path = "examples/validation_sort.zig" },
    };

    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("zon", zon_module);

        const install_exe = b.addInstallArtifact(exe, .{});
        const example_step = b.step("example-" ++ example.name, "Build " ++ example.name ++ " example");
        example_step.dependOn(&install_exe.step);

        // Add run step for each example
        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        const run_step = b.step("run-" ++ example.name, "Run " ++ example.name ++ " example");
        run_step.dependOn(&run_exe.step);
    }

    // Backward compatibility: "example" runs basic example
    const basic_exe = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    basic_exe.root_module.addImport("zon", zon_module);
    const run_basic = b.addRunArtifact(basic_exe);
    const example_step = b.step("example", "Run basic example");
    example_step.dependOn(&run_basic.step);

    const run_all_examples = b.step("run-all-examples", "Run all examples sequentially (one at a time)");

    // Alias: "examples" runs all examples
    const examples_step = b.step("examples", "Run all examples");
    examples_step.dependOn(run_all_examples);

    // Unit tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zon.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Create comprehensive test-all step that runs everything sequentially
    const test_all_step = b.step("test-all", "Run all tests and examples sequentially");
    test_all_step.dependOn(test_step);
    test_all_step.dependOn(run_all_examples);

    // Benchmark step
    const bench_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    bench_exe.root_module.addImport("zon", zon_module);

    const run_bench = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Install step for library
    const lib = b.addLibrary(.{
        .name = "zon",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zon.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);
}
