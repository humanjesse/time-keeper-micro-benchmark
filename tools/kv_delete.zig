// KV Delete Tool - Delete a key-value pair (Time-Keeper memory tool)
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
                .name = try allocator.dupe(u8, "kv_delete"),
                .description = try allocator.dupe(u8, "Delete a key-value pair from the store. Example: {\"key\": \"user_diet\"} returns {\"key\": \"user_diet\", \"status\": \"deleted\"}"),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {
                    \\    "key": {
                    \\      "type": "string",
                    \\      "description": "The key to delete"
                    \\    }
                    \\  },
                    \\  "required": ["key"]
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "kv_delete",
            .description = "Delete key-value pair from memory",
            .risk_level = .safe,
            .required_scopes = &.{.todo_management},
            .validator = null,
        },
        .execute = execute,
    };
}

fn execute(allocator: std.mem.Allocator, arguments: []const u8, context: *AppContext) !ToolResult {
    const start_time = std.time.milliTimestamp();

    const Args = struct { key: []const u8 };
    const parsed = std.json.parseFromSlice(Args, allocator, arguments, .{}) catch {
        return ToolResult.err(allocator, .parse_error, "Invalid JSON arguments. Expected: {\"key\": \"...\"}", start_time);
    };
    defer parsed.deinit();

    if (context.state.kvDelete(parsed.value.key)) {
        const result_msg = try std.fmt.allocPrint(allocator, "{{\"key\": \"{s}\", \"status\": \"deleted\"}}", .{parsed.value.key});
        defer allocator.free(result_msg);
        return ToolResult.ok(allocator, result_msg, start_time, null);
    } else {
        const msg = try std.fmt.allocPrint(allocator, "Key '{s}' not found. Nothing to delete.", .{parsed.value.key});
        defer allocator.free(msg);
        return ToolResult.err(allocator, .not_found, msg, start_time);
    }
}
