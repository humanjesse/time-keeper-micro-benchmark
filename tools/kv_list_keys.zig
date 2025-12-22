// KV List Keys Tool - List all keys in the store (Time-Keeper memory tool)
const std = @import("std");
const ollama = @import("ollama");
const permission = @import("permission");
const context_module = @import("context");
const tools_module = @import("../tools.zig");

const AppContext = context_module.AppContext;
const ToolDefinition = tools_module.ToolDefinition;
const ToolResult = tools_module.ToolResult;

pub fn getDefinition(allocator: std.mem.Allocator) !ToolDefinition {
    return .{
        .ollama_tool = .{
            .type = "function",
            .function = .{
                .name = try allocator.dupe(u8, "kv_list_keys"),
                .description = try allocator.dupe(u8, "List all keys currently stored in the key-value store. Returns a JSON array of key names. Example: returns [\"user_diet\", \"budget\", \"favorite_restaurant\"]"),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {},
                    \\  "required": []
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "kv_list_keys",
            .description = "List keys in key-value store",
            .risk_level = .safe,
            .required_scopes = &.{.todo_management},
            .validator = null,
        },
        .execute = execute,
    };
}

fn execute(allocator: std.mem.Allocator, arguments: []const u8, context: *AppContext) !ToolResult {
    _ = arguments;
    const start_time = std.time.milliTimestamp();

    const keys = context.state.kvListKeys() catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Failed to list keys: {}", .{err});
        defer allocator.free(msg);
        return ToolResult.err(allocator, .internal_error, msg, start_time);
    };
    defer allocator.free(keys);

    if (keys.len == 0) {
        return ToolResult.ok(allocator, "[]", start_time, null);
    }

    // Build JSON array of keys
    var json_builder = std.ArrayListUnmanaged(u8){};
    defer json_builder.deinit(allocator);

    try json_builder.append(allocator, '[');
    for (keys, 0..) |key, i| {
        try json_builder.append(allocator, '"');
        try json_builder.appendSlice(allocator, key);
        try json_builder.append(allocator, '"');
        if (i < keys.len - 1) {
            try json_builder.appendSlice(allocator, ", ");
        }
    }
    try json_builder.append(allocator, ']');

    const result = try json_builder.toOwnedSlice(allocator);
    defer allocator.free(result);
    return ToolResult.ok(allocator, result, start_time, null);
}
