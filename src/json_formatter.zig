const std = @import("std");
const Allocator = std.mem.Allocator;

// ANSI color codes
const Colors = struct {
    const reset = "\x1b[0m";
    const red = "\x1b[31m";
    const green = "\x1b[32m";
    const yellow = "\x1b[33m";
    const blue = "\x1b[34m";
    const magenta = "\x1b[35m";
    const cyan = "\x1b[36m";
    const gray = "\x1b[90m";
};

/// Formats a JSON string with proper indentation and colors
pub fn formatJson(allocator: Allocator, input: []const u8, collapse_arrays: bool, use_colors: bool) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, input, .{});
    defer parsed.deinit();

    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    try formatValue(parsed.value, &list, 0, collapse_arrays, use_colors);

    if (use_colors) {
        try list.appendSlice(Colors.reset);
    }

    return list.toOwnedSlice();
}

fn formatValue(value: std.json.Value, writer: *std.ArrayList(u8), indent: usize, collapse_arrays: bool, use_colors: bool) !void {
    switch (value) {
        .object => |obj| {
            try writer.append('{');
            var first = true;

            var it = obj.iterator();
            while (it.next()) |entry| {
                if (!first) {
                    try writer.append(',');
                }
                try writer.append('\n');
                try writer.appendNTimes(' ', indent + 2);

                // Write key with blue color
                if (use_colors) try writer.appendSlice(Colors.blue);
                try writer.append('"');
                try writer.appendSlice(entry.key_ptr.*);
                try writer.append('"');
                if (use_colors) try writer.appendSlice(Colors.reset);
                try writer.appendSlice(": ");

                // Write value
                try formatValue(entry.value_ptr.*, writer, indent + 2, collapse_arrays, use_colors);
                first = false;
            }

            if (!first) {
                try writer.append('\n');
                try writer.appendNTimes(' ', indent);
            }
            try writer.append('}');
        },
        .array => |array| {
            try writer.append('[');

            if (array.items.len == 0) {
                try writer.append(']');
                return;
            }

            const should_collapse = collapse_arrays and array.items.len <= 5 and
                for (array.items) |item|
            {
                if (item == .object or item == .array) break false;
            } else true;

            if (should_collapse) {
                // Collapse simple arrays
                for (array.items, 0..) |item, i| {
                    if (i > 0) try writer.appendSlice(", ");
                    try formatValue(item, writer, indent, collapse_arrays, use_colors);
                }
                try writer.append(']');
            } else {
                // Format arrays with newlines
                for (array.items, 0..) |item, i| {
                    if (i > 0) try writer.append(',');
                    try writer.append('\n');
                    try writer.appendNTimes(' ', indent + 2);
                    try formatValue(item, writer, indent + 2, collapse_arrays, use_colors);
                }
                try writer.append('\n');
                try writer.appendNTimes(' ', indent);
                try writer.append(']');
            }
        },
        .string => |string| {
            if (use_colors) try writer.appendSlice(Colors.green);
            try writer.append('"');
            try writer.appendSlice(string);
            try writer.append('"');
            if (use_colors) try writer.appendSlice(Colors.reset);
        },
        .integer => |integer| {
            if (use_colors) try writer.appendSlice(Colors.yellow);
            var buf: [20]u8 = undefined;
            const slice = try std.fmt.bufPrint(&buf, "{d}", .{integer});
            try writer.appendSlice(slice);
            if (use_colors) try writer.appendSlice(Colors.reset);
        },
        .float => |float| {
            if (use_colors) try writer.appendSlice(Colors.yellow);
            var buf: [20]u8 = undefined;
            const slice = try std.fmt.bufPrint(&buf, "{d}", .{float});
            try writer.appendSlice(slice);
            if (use_colors) try writer.appendSlice(Colors.reset);
        },
        .bool => |b| {
            if (use_colors) try writer.appendSlice(Colors.magenta);
            try writer.appendSlice(if (b) "true" else "false");
            if (use_colors) try writer.appendSlice(Colors.reset);
        },
        .null => {
            if (use_colors) try writer.appendSlice(Colors.gray);
            try writer.appendSlice("null");
            if (use_colors) try writer.appendSlice(Colors.reset);
        },
        else => unreachable,
    }
}

// Function to check if output is being piped
pub fn isOutputPiped() bool {
    return !std.posix.isatty(std.posix.STDOUT_FILENO);
}
