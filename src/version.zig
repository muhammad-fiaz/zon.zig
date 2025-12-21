//! Library Version Information
//!
//! Provides compile-time version constants and comparison utilities
//! for the zon.zig library.

const std = @import("std");

/// Current library version.
pub const version = "0.0.3";
pub const major: u32 = 0;
pub const minor: u32 = 0;
pub const patch: u32 = 3;

/// Pre-release identifier (empty for stable releases).
pub const pre_release: []const u8 = "";

/// Build metadata (empty if not applicable).
pub const build_metadata: []const u8 = "";

/// Get the semantic version struct.
pub fn semanticVersion() std.SemanticVersion {
    return .{
        .major = major,
        .minor = minor,
        .patch = patch,
        .pre = if (pre_release.len > 0) pre_release else null,
        .build = if (build_metadata.len > 0) build_metadata else null,
    };
}

/// Get the full version string.
pub fn fullVersion() []const u8 {
    return version;
}

/// Get the version string (alias).
pub fn getVersion() []const u8 {
    return version;
}

/// Get version info struct.
pub fn getVersionInfo() struct { major: u32, minor: u32, patch: u32, string: []const u8 } {
    return .{
        .major = major,
        .minor = minor,
        .patch = patch,
        .string = version,
    };
}

/// Compare two semantic version strings.
/// Returns: -1 if a < b, 0 if a == b, 1 if a > b
pub fn compareVersions(a: []const u8, b: []const u8) i8 {
    const ver_a = std.SemanticVersion.parse(a) catch return 0;
    const ver_b = std.SemanticVersion.parse(b) catch return 0;

    if (ver_a.major != ver_b.major) {
        return if (ver_a.major > ver_b.major) 1 else -1;
    }
    if (ver_a.minor != ver_b.minor) {
        return if (ver_a.minor > ver_b.minor) 1 else -1;
    }
    if (ver_a.patch != ver_b.patch) {
        return if (ver_a.patch > ver_b.patch) 1 else -1;
    }
    return 0;
}

test "version constants" {
    try std.testing.expect(major == 0);
    try std.testing.expect(minor == 0);
    try std.testing.expect(patch == 3);
    try std.testing.expect(std.mem.eql(u8, version, "0.0.3"));
}

test "semantic version" {
    const sv = semanticVersion();
    try std.testing.expect(sv.major == 0);
    try std.testing.expect(sv.minor == 0);
    try std.testing.expect(sv.patch == 3);
}

test "version comparison" {
    try std.testing.expectEqual(@as(i8, 0), compareVersions("1.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i8, -1), compareVersions("1.0.0", "2.0.0"));
    try std.testing.expectEqual(@as(i8, 1), compareVersions("2.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i8, -1), compareVersions("1.0.0", "1.1.0"));
    try std.testing.expectEqual(@as(i8, 1), compareVersions("1.1.0", "1.0.0"));
}
