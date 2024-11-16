const std = @import("std");

pub const ParamDefinition = struct {
    name: []const u8,
    required: bool = true,
};

pub const ResponseType = enum {
    PrintOnly, // Current default behavior - just print the response
    ReturnJson, // Return the parsed JSON for chaining
    Custom, // For special handling cases

};

pub const EndpointMap = struct {
    path: []const u8,
    method: []const u8 = "GET",
    params: []const ParamDefinition,
    response_type: ResponseType = .PrintOnly, // Default to current behavior
    json_field: ?[]const u8 = null, // Add this field to specify which JSON field to extract
    default_user_id_param: ?usize = null, // Which param index should use userId by default

    pub fn formatUrl(
        self: EndpointMap,
        base_url: []const u8,
        params: []const []const u8,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var url = std.ArrayList(u8).init(allocator);
        defer url.deinit();

        try url.appendSlice(base_url);
        try url.appendSlice(self.path);

        for (params, 0..) |param, i| {
            if (i >= self.params.len) break;
            try url.appendSlice("/");
            try url.appendSlice(param);
        }

        return try url.toOwnedSlice();
    }
    pub const ParamValidationResult = struct {
        valid: bool,
        required_params: usize,
        effective_params: usize,
        missing_params: usize,
        filled_params: ?[]const []const u8 = null,
    };

    pub fn validateAndFillParams(
        self: EndpointMap,
        params: []const []const u8,
        user_id: ?[]const u8,
        allocator: std.mem.Allocator,
    ) !ParamValidationResult {
        const base_required = self.requiredParamCount();
        const has_valid_user_id = (self.default_user_id_param != null and user_id != null);

        // If we have a valid user_id and it could be used, let's create new params array
        if (has_valid_user_id and self.default_user_id_param.? < self.params.len) {
            var new_params = try allocator.alloc([]const u8, self.params.len);

            // Copy existing params
            for (params, 0..) |param, i| {
                new_params[i] = param;
            }

            // Fill in user_id where needed
            if (self.default_user_id_param.? >= params.len) {
                new_params[self.default_user_id_param.?] = user_id.?;
            }

            const effective_required = if (self.default_user_id_param.? < base_required)
                base_required - 1
            else
                base_required;

            return .{
                .valid = new_params.len >= effective_required,
                .required_params = base_required,
                .effective_params = new_params.len,
                .missing_params = if (new_params.len < effective_required)
                    effective_required - new_params.len
                else
                    0,
                .filled_params = new_params,
            };
        }

        // If we can't fill in anything, return original validation
        return .{
            .valid = params.len >= base_required,
            .required_params = base_required,
            .effective_params = params.len,
            .missing_params = if (params.len < base_required)
                base_required - params.len
            else
                0,
            .filled_params = null,
        };
    }
    pub fn requiredParamCount(self: EndpointMap) usize {
        var count: usize = 0;
        for (self.params) |param| {
            if (param.required) count += 1;
        }
        return count;
    }
};
