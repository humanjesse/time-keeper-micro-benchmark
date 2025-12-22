// Vector Delete Tool - Remove entry from vector memory (Time-Keeper memory tool)
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
                .name = try allocator.dupe(u8, "vector_delete"),
                .description = try allocator.dupe(u8, "Delete an entry from vector memory by ID. Example: {\"id\": \"vec_1\"} returns {\"id\": \"vec_1\", \"status\": \"deleted\"}"),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {
                    \\    "id": {
                    \\      "type": "string",
                    \\      "description": "The ID of the vector entry to delete"
                    \\    }
                    \\  },
                    \\  "required": ["id"]
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "vector_delete",
            .description = "Delete entry from vector memory",
            .risk_level = .safe,
            .required_scopes = &.{.todo_management},
            .validator = null,
        },
        .execute = execute,
    };
}

fn execute(allocator: std.mem.Allocator, arguments: []const u8, context: *AppContext) !ToolResult {
    const start_time = std.time.milliTimestamp();

    const Args = struct { id: []const u8 };
    const parsed = std.json.parseFromSlice(Args, allocator, arguments, .{}) catch {
        return ToolResult.err(allocator, .parse_error, "Invalid JSON arguments. Expected: {\"id\": \"...\"}", start_time);
    };
    defer parsed.deinit();

    if (context.state.vectorDelete(parsed.value.id)) {
        const result_msg = try std.fmt.allocPrint(allocator, "{{\"id\": \"{s}\", \"status\": \"deleted\"}}", .{parsed.value.id});
        defer allocator.free(result_msg);
        return ToolResult.ok(allocator, result_msg, start_time, null);
    } else {
        const msg = try std.fmt.allocPrint(allocator, "Vector entry '{s}' not found. Use vector_search to find valid IDs.", .{parsed.value.id});
        defer allocator.free(msg);
        return ToolResult.err(allocator, .not_found, msg, start_time);
    }
}
