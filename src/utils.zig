const std = @import("std");
const endpoints = @import("endpoint_config").endpoints;
const types = @import("types");

pub fn printAvailableCommands() !void {
    const stderr = std.io.getStdErr().writer();
    try stderr.print("\nAvailable commands:\n", .{});

    // Direct access to the struct fields instead of using get()
    inline for (comptime std.meta.declarations(endpoints)) |decl| {
        // Skip non-endpoint declarations (like the get function)
        if (@typeInfo(@TypeOf(@field(endpoints, decl.name))) != .Struct) {
            continue;
        }
        const endpoint = @field(endpoints, decl.name);
        try stderr.print("  {s}", .{decl.name});
        for (endpoint.params) |param| {
            if (param.required) {
                try stderr.print(" <{s}>", .{param.name});
            } else {
                try stderr.print(" [{s}]", .{param.name});
            }
        }
        try stderr.print("\n", .{});
    }
}

pub fn printCommandUsage(command: []const u8, endpoint: types.EndpointMap) !void {
    const stderr = std.io.getStdErr().writer();
    try stderr.print("\nUsage: vlcli {s}", .{command});
    for (endpoint.params) |param| {
        if (param.required) {
            try stderr.print(" <{s}>", .{param.name});
        } else {
            try stderr.print(" [{s}]", .{param.name});
        }
    }
    try stderr.print("\n", .{});
}
