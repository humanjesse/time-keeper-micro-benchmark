// KV Set Tool - Set/update a key-value pair (Time-Keeper memory tool)
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
                .name = try allocator.dupe(u8, "kv_set"),
                .description = try allocator.dupe(u8, "Set or update a key-value pair in the key-value store. Use for structured data that needs quick lookup by key. Example: {\"key\": \"user_diet\", \"value\": \"vegetarian\"} returns {\"key\": \"user_diet\", \"status\": \"created\"}"),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {
                    \\    "key": {
                    \\      "type": "string",
                    \\      "description": "The key to store the value under"
                    \\    },
                    \\    "value": {
                    \\      "type": "string",
                    \\      "description": "The value to store"
                    \\    }
                    \\  },
                    \\  "required": ["key", "value"]
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "kv_set",
            .description = "Set key-value pair in memory",
            .risk_level = .safe,
            .required_scopes = &.{.todo_management},
            .validator = null,
        },
        .execute = execute,
    };
}

fn execute(allocator: std.mem.Allocator, arguments: []const u8, context: *AppContext) !ToolResult {
    const start_time = std.time.milliTimestamp();

    const Args = struct { key: []const u8, value: []const u8 };
    const parsed = std.json.parseFromSlice(Args, allocator, arguments, .{}) catch {
        return ToolResult.err(allocator, .parse_error, "Invalid JSON arguments. Expected: {\"key\": \"...\", \"value\": \"...\"}", start_time);
    };
    defer parsed.deinit();

    const was_created = context.state.kvSet(parsed.value.key, parsed.value.value) catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Failed to set key-value: {}", .{err});
        defer allocator.free(msg);
        return ToolResult.err(allocator, .internal_error, msg, start_time);
    };

    const status = if (was_created) "created" else "updated";
    const result_msg = try std.fmt.allocPrint(allocator, "{{\"key\": \"{s}\", \"status\": \"{s}\"}}", .{ parsed.value.key, status });
    defer allocator.free(result_msg);
    return ToolResult.ok(allocator, result_msg, start_time, null);
}
