pub const ParamDefinition = struct {
    name: []const u8,
    required: bool = true,
};

pub const EndpointMap = struct {
    path: []const u8,
    method: []const u8 = "GET",
    params: []const ParamDefinition,

    pub fn formatUrl(
        self: EndpointMap,
        base_url: []const u8,
        params: []const []const u8,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        if (params.len < self.requiredParamCount()) {
            return error.NotEnoughParameters;
        }

        var url = std.ArrayList(u8).init(allocator);
        defer url.deinit();

        // Add base URL
        try url.appendSlice(base_url);
        try url.appendSlice(self.path);

        // Replace parameter placeholders with actual values
        var param_index: usize = 0;
        for (self.params) |param| {
            if (param_index >= params.len and param.required) {
                return error.MissingRequiredParameter;
            }
            if (param_index < params.len) {
                try url.appendSlice("/");
                try url.appendSlice(params[param_index]);
            }
            param_index += 1;
        }

        return try url.toOwnedSlice();
    }

    pub fn requiredParamCount(self: EndpointMap) usize {
        var count: usize = 0;
        for (self.params) |param| {
            if (param.required) count += 1;
        }
        return count;
    }
};

const std = @import("std");
