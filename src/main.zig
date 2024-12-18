const std = @import("std");
const clap = @import("clap");
const Uri = std.Uri;
const json = std.json;
const endpoints = @import("endpoint_config").endpoints;
const system_commands = @import("endpoint_config").system_commands;
const command_chains = @import("endpoint_config").command_chains;
const cf = @import("env_config");
const types = @import("types");
const json_formatter = @import("json_formatter");
const utils = @import("utils");
const child_process = std.process; // Add this import

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Define our CLI parameters
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\-p, --prod            Use production environment.
        \\--platform <STR>      Target platform (ios/android).
        \\<COMMAND>            Command to execute (e.g., surgery).
        \\<ARGS>...            Arguments for the command.
        \\
    );

    // Define our parsers
    const parsers = comptime .{
        .COMMAND = clap.parsers.string,
        .ARGS = clap.parsers.string,
        .STR = clap.parsers.string, // Added parser for platform

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
        try utils.printAvailableCommands();
        return error.MissingCommand;
    }

    const command = res.positionals[0];
    if (command_chains.get(command)) |chain| {
        const args = if (res.positionals.len > 1) res.positionals[1..] else &[_][]const u8{};
        const platform = if (res.args.platform) |p| blk: {
            if (std.mem.eql(u8, p, "ios")) {
                break :blk types.Platform.ios;
            } else if (std.mem.eql(u8, p, "android")) {
                break :blk types.Platform.android;
            } else {
                return error.UnsupportedPlatform;
            }
        } else return error.PlatformRequired;

        const context = types.ChainContext{
            .platform = platform,
            .allocator = allocator,
        };
        try executeCommandChain(chain, context, args, res.args.prod != 0);
        return;
    }

    const endpoint = endpoints.get(command) orelse {
        try std.io.getStdErr().writer().print("Error: Unknown command '{s}'\n", .{command});
        try utils.printAvailableCommands();
        return error.UnknownCommand;
    };

    // Get parameters
    const params_slice = if (res.positionals.len > 1) res.positionals[1..] else &[_][]const u8{};

    _ = try handleEndpoint(endpoint, params_slice, allocator, res.args.prod != 0, false);

    // const validation = try endpoint.validateAndFillParams(params_slice, cf.getMyUserId(), allocator);

    // defer if (validation.filled_params) |valiParams| allocator.free(valiParams);

    // if (!validation.valid) {
    //     try std.io.getStdErr().writer().print(
    //         "Error: Command '{s}' requires {d} parameters, but got {d}\n",
    //         .{
    //             command,
    //             validation.required_params,
    //             validation.effective_params,
    //         },
    //     );
    //     try utils.printCommandUsage(command, endpoint);
    //     return error.NotEnoughParameters;
    // }

    // // Use either the filled params or original params
    // const params_to_use = validation.filled_params orelse params_slice;

    // const is_prod = res.args.prod != 0;

    // // Debug prints
    // std.debug.print("Command: {s}\n", .{command});
    // std.debug.print("Arguments: ", .{});
    // for (params_to_use) |param| {
    //     std.debug.print("{s} ", .{param});
    // }
    // std.debug.print("\nProduction mode: {}\n", .{is_prod});

    // // Build URL with parameters
    // const config = cf.getConfig(allocator, if (is_prod) .production else .local);
    // defer config.deinit();

    // const url = try endpoint.formatUrl(config.base_url, params_to_use, allocator);
    // defer allocator.free(url);

    // switch (endpoint.response_type) {
    //     .PrintOnly => {
    //         _ = try makeRequest(allocator, url, config, endpoint);
    //         return;
    //     },
    //     else => {
    //         const maybe_response = try makeRequest(allocator, url, config, endpoint);

    //         if (maybe_response) |response| {
    //             defer allocator.free(response);
    //             const stdout = std.io.getStdOut().writer();
    //             try stdout.writeAll(response);
    //             // how do i give this here to the next person?
    //             return;
    //         }
    //         return error.NoResponse;
    //     },
    // }

    // try makeRequest(allocator, url, config, endpoint.response_type);
}

fn makeRequest(allocator: std.mem.Allocator, url: []const u8, config: cf.Config, endpoint: types.EndpointMap) !?[]const u8 {
    if (config.environment == .local) {
        std.debug.print("\n=== Request Details ===\n", .{});
        std.debug.print("URL: {s}\n", .{url});
        std.debug.print("Header Name: {s}\n", .{config.auth.header_name});
        std.debug.print("Header Value: {s}\n", .{config.auth.header_value});
        std.debug.print("===================\n\n", .{});
    }

    var client = std.http.Client{
        .allocator = allocator,
    };
    defer client.deinit();

    var server_header_buffer: [8192]u8 = undefined;
    const uri = try std.Uri.parse(url);

    var req = client.open(
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
    ) catch |err| {
        if (config.environment == .local) {
            std.debug.print("\n=== Error Opening Request ===\n", .{});
            std.debug.print("Error: {s}\n", .{@errorName(err)});
            // std.debug.print("URI Details:\n", .{});
            //        std.debug.print("  Scheme: {?s}\n", .{uri.scheme});
            //        std.debug.print("  Host: {?s}\n", .{uri.host});
            //        std.debug.print("  Path: {?s}\n", .{uri.path});
            if (uri.port != null) {
                std.debug.print("  Port: {d}\n", .{uri.port.?});
            }
            std.debug.print("=========================\n\n", .{});
        }
        return err;
    };
    defer req.deinit();

    req.send() catch |err| {
        if (config.environment == .local) {
            std.debug.print("\n=== Error Sending Request ===\n", .{});
            std.debug.print("Error: {s}\n", .{@errorName(err)});
            std.debug.print("=========================\n\n", .{});
        }
        return err;
    };

    req.finish() catch |err| {
        if (config.environment == .local) {
            std.debug.print("\n=== Error Finishing Request ===\n", .{});
            std.debug.print("Error: {s}\n", .{@errorName(err)});
            std.debug.print("=========================\n\n", .{});
        }
        return err;
    };

    req.wait() catch |err| {
        if (config.environment == .local) {
            std.debug.print("\n=== Error Waiting for Response ===\n", .{});
            std.debug.print("Error: {s}\n", .{@errorName(err)});
            if (@intFromEnum(req.response.status) != 0) {
                const phrase = req.response.status.phrase();
                std.debug.print("Status: {d} - {s}\n", .{
                    @intFromEnum(req.response.status),
                    if (phrase) |p| p else "Unknown Status",
                });
            }
            std.debug.print("=========================\n\n", .{});
        }
        return err;
    };

    if (config.environment == .local) {
        std.debug.print("\n=== Response Details ===\n", .{});
        const phrase = req.response.status.phrase();
        std.debug.print("Status: {d} - {s}\n", .{
            @intFromEnum(req.response.status),
            if (phrase) |p| p else "Unknown Status",
        });
        std.debug.print("===================\n\n", .{});
    }

    const content = try req.reader().readAllAlloc(allocator, 1024 * 1024);
    // defer allocator.free(content);

    switch (endpoint.response_type) {
        .PrintOnly => {
            // Current behavior
            const stdout = std.io.getStdOut().writer();
            const use_colors = !json_formatter.isOutputPiped();
            const formatted = try json_formatter.formatJson(allocator, content, true, use_colors);
            defer allocator.free(formatted);
            try stdout.writeAll(formatted);
            if (config.environment == .local) {
                std.debug.print("===================\n\n", .{});
            }
            allocator.free(content);
            return null;
        },
        .ReturnJson => {
            std.debug.print("======RETURN JSON\n\n", .{});

            // Return the raw JSON for chaining
            return content;
        },
        .Custom => {
            if (endpoint.json_field) |field| {
                var parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
                defer parsed.deinit();

                if (parsed.value.object.get(field)) |value| {
                    if (value == .string) {
                        // Clone the string to ensure it survives after parsed.deinit()
                        const result = try allocator.dupe(u8, value.string);
                        allocator.free(content);
                        return result;
                    }
                }

                allocator.free(content);
                return error.FieldNotFound;
            }

            return content;
        },
    }

    // if (config.environment == .local) {
    //     std.debug.print("\n=== Response Body ===\n", .{});
    // }
    // const use_colors = !json_formatter.isOutputPiped();

    // const formatted = try json_formatter.formatJson(allocator, content, true, use_colors);
    // defer allocator.free(formatted);

    // try stdout.writeAll(formatted);
    // // try stdout.print("{s}\n", .{content});
    // if (config.environment == .local) {
    //     std.debug.print("===================\n\n", .{});
    // }
    return null;
}

// New function to execute a command chain
fn executeCommandChain(
    chain: types.ChainedCommand,
    context: types.ChainContext,
    args: []const []const u8,
    is_prod: bool,
) !void {
    var current_output: ?[]const u8 = null;
    defer if (current_output) |output| context.allocator.free(output);

    for (chain.steps) |step| {
        switch (step) {
            .endpoint => |endpoint_name| {
                const endpoint = endpoints.get(endpoint_name) orelse {
                    return error.UnknownEndpoint;
                };

                const step_args = if (current_output) |output|
                    &[_][]const u8{output}
                else
                    args;

                if (current_output) |output| context.allocator.free(output);
                current_output = try handleEndpoint(endpoint, step_args, context.allocator, is_prod, true) orelse return error.NoResponse;
            },

            .system => |_| { // We don't even need the cmd_name anymore
                if (current_output) |cmd_str| {
                    var it = std.mem.split(u8, cmd_str, " ");
                    var system_args = std.ArrayList([]const u8).init(context.allocator);
                    defer system_args.deinit();

                    while (it.next()) |arg| {
                        try system_args.append(arg);
                    }

                    var child = child_process.Child.init(system_args.items, context.allocator);
                    _ = try child.spawnAndWait();
                }
            },

            .transform => |maybe_transform| {
                if (maybe_transform) |transform| {
                    if (current_output) |output| {
                        const new_output = try transform(context, output);
                        context.allocator.free(output);
                        current_output = new_output;
                    }
                }
            },
        }
    }
}
fn handleEndpoint(
    endpoint: types.EndpointMap,
    args: []const []const u8,
    allocator: std.mem.Allocator,
    is_prod: bool,
    for_chain: bool, // New parameter to differentiate behavior
) !?[]const u8 {
    const validation = try endpoint.validateAndFillParams(args, cf.getMyUserId(), allocator);
    defer if (validation.filled_params) |valiParams| allocator.free(valiParams);

    if (!validation.valid) {
        return error.NotEnoughParameters;
    }

    const params_to_use = validation.filled_params orelse args;
    const config = cf.getConfig(allocator, if (is_prod) .production else .local);
    defer config.deinit();

    const url = try endpoint.formatUrl(config.base_url, params_to_use, allocator);
    defer allocator.free(url);

    if (for_chain) {
        // For chains, always return the response if available
        return try makeRequest(allocator, url, config, endpoint);
    } else {
        // For direct commands, maintain original behavior
        switch (endpoint.response_type) {
            .PrintOnly => {
                _ = try makeRequest(allocator, url, config, endpoint);
                return null;
            },
            else => {
                const maybe_response = try makeRequest(allocator, url, config, endpoint);
                if (maybe_response) |response| {
                    const stdout = std.io.getStdOut().writer();
                    try stdout.writeAll(response);
                    // Free the response since we've written it
                    allocator.free(response);
                    return null;
                }
                return error.NoResponse;
            },
        }
    }
}
