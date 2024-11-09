const std = @import("std");
const clap = @import("clap");
const Uri = std.Uri;
const json = std.json;
const endpoints = @import("endpoint_config").endpoints;
const cf = @import("env_config");
const types = @import("types");

// These need to be public so endpoint_config can use them
pub const ParamDefinition = struct {
    name: []const u8,
    required: bool = true,
};
// Parameter definition for endpoint

// Endpoint mapping with parameter definitions
const EndpointMap = struct {
    path: []const u8,
    method: []const u8 = "GET",
    params: []const ParamDefinition,

    // Helper to format URL with parameters
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        // Define our CLI parameters
        const params = comptime clap.parseParamsComptime(
            \\-h, --help            Display this help and exit.
            \\-p, --prod            Use production environment.
            \\<COMMAND>            Command to execute (e.g., surgery).
            \\<ARGS>...            Arguments for the command.
            \\
        );

        // Define our parsers
        const parsers = comptime .{
            .COMMAND = clap.parsers.string,
            .ARGS = clap.parsers.string,
        };

        var diag = clap.Diagnostic{};
        var res = clap.parse(clap.Help, &params, parsers, .{
            .diagnostic = &diag,
            .allocator = allocator,
        }) catch |err| {
            diag.report(std.io.getStdErr().writer(), err) catch {};
            return err;
        };
        defer res.deinit();

        if (res.args.help != 0) {
            try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
            return;
        }

        // Need at least a command
        if (res.positionals.len == 0) {
            std.debug.print("Error: Command required\n", .{});
            try printAvailableCommands();
            return error.MissingCommand;
        }

        const command = res.positionals[0];
        const endpoint = endpoints.get(command) orelse {
            try std.io.getStdErr().writer().print("Error: Unknown command '{s}'\n", .{command});
            try printAvailableCommands();
            return error.UnknownCommand;
        };

        // Get parameters
        const params_slice = if (res.positionals.len > 1) res.positionals[1..] else &[_][]const u8{};
        if (params_slice.len < endpoint.requiredParamCount()) {
            try std.io.getStdErr().writer().print(
                "Error: Command '{s}' requires {d} parameters, but got {d}\n",
                .{ command, endpoint.requiredParamCount(), params_slice.len },
            );
            try printCommandUsage(command, endpoint);
            return error.NotEnoughParameters;
        }

        const is_prod = res.args.prod != 0;

        // Debug prints
        std.debug.print("Command: {s}\n", .{command});
        std.debug.print("Arguments: ", .{});
        for (params_slice) |param| {
            std.debug.print("{s} ", .{param});
        }
        std.debug.print("\nProduction mode: {}\n", .{is_prod});

        // Build URL with parameters
        const config = cf.getConfig(allocator, if (is_prod) .production else .local);
        defer config.deinit();

        const url = try endpoint.formatUrl(config.base_url, params_slice, allocator);
        defer allocator.free(url);

        try makeRequest(allocator, url, config);

}

fn printAvailableCommands() !void {
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

fn printCommandUsage(command: []const u8, endpoint: types.EndpointMap) !void {
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

fn makeRequest(allocator: std.mem.Allocator, url: []const u8, config: cf.Config) !void {
    var client = std.http.Client{
           .allocator = allocator,
       };
       defer client.deinit();

       var server_header_buffer: [8192]u8 = undefined;

       const uri = try std.Uri.parse(url);

       var req = try client.open(
           .GET,
           uri,
           .{
               .server_header_buffer = &server_header_buffer,
               .headers = .{
                   .authorization = .{ .override = config.auth.header_value },
               },
               .extra_headers = &[_]std.http.Header{.{
                   .name = config.auth.header_name,
                   .value = config.auth.header_value,
               }},
           },
       );
       defer req.deinit();

       try req.send();
       try req.finish();
       try req.wait();

       const stdout = std.io.getStdOut().writer();
       const content = try req.reader().readAllAlloc(allocator, 1024 * 1024);
       defer allocator.free(content);
       try stdout.print("{s}\n", .{content});

}
