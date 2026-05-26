//! Library Version Information
//!
//! Provides the library version string and comparison utilities.

const std = @import("std");

/// Current library version.
pub const version = "0.0.5";

/// Get the version string.
pub fn getVersion() []const u8 {
    return version;
}

/// Compare two semantic version strings.
/// Returns: -1 if a < b, 0 if a == b, 1 if a > b
pub fn compareVersions(a: []const u8, b: []const u8) i8 {
    const ver_a = std.SemanticVersion.parse(a) catch return 0;
    const ver_b = std.SemanticVersion.parse(b) catch return 0;
    return switch (ver_a.order(ver_b)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

test "version constants" {
    try std.testing.expect(std.mem.eql(u8, version, "0.0.5"));
}

test "version comparison" {
    try std.testing.expectEqual(@as(i8, 0), compareVersions("1.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i8, -1), compareVersions("1.0.0", "2.0.0"));
    try std.testing.expectEqual(@as(i8, 1), compareVersions("2.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i8, -1), compareVersions("1.0.0", "1.1.0"));
    try std.testing.expectEqual(@as(i8, 1), compareVersions("1.1.0", "1.0.0"));
}
