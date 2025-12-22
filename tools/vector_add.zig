// Vector Add Tool - Add text to vector memory with embeddings (Time-Keeper memory tool)
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
                .name = try allocator.dupe(u8, "vector_add"),
                .description = try allocator.dupe(u8, "Add text to vector memory with automatic embedding generation for semantic search. Use for information that needs to be retrieved by meaning/similarity later. Example: {\"text\": \"User loves Thai food, especially Pad Thai Palace\"} returns {\"id\": \"vec_1\", \"embedding_dim\": 768}"),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {
                    \\    "text": {
                    \\      "type": "string",
                    \\      "description": "The text to store and embed for semantic search"
                    \\    }
                    \\  },
                    \\  "required": ["text"]
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "vector_add",
            .description = "Add text to vector memory",
            .risk_level = .safe,
            .required_scopes = &.{.todo_management},
            .validator = null,
        },
        .execute = execute,
    };
}

fn execute(allocator: std.mem.Allocator, arguments: []const u8, context: *AppContext) !ToolResult {
    const start_time = std.time.milliTimestamp();

    // Check if embedder is available
    if (context.embedder == null) {
        return ToolResult.err(allocator, .internal_error, "Vector memory requires embeddings. Ensure embeddings are configured and Ollama is running with an embedding model.", start_time);
    }

    const Args = struct { text: []const u8 };
    const parsed = std.json.parseFromSlice(Args, allocator, arguments, .{}) catch {
        return ToolResult.err(allocator, .parse_error, "Invalid JSON arguments. Expected: {\"text\": \"...\"}", start_time);
    };
    defer parsed.deinit();

    if (parsed.value.text.len == 0) {
        return ToolResult.err(allocator, .invalid_input, "Text cannot be empty", start_time);
    }

    // Generate embedding for the text
    const embedding = context.embedder.?.embed(context.config.embeddings_model, parsed.value.text) catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Failed to generate embedding: {}. Ensure model '{s}' is available.", .{ err, context.config.embeddings_model });
        defer allocator.free(msg);
        return ToolResult.err(allocator, .internal_error, msg, start_time);
    };

    // Add to vector memory (returns the ID string directly)
    const vec_id = context.state.vectorAdd(parsed.value.text, embedding) catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Failed to add to vector memory: {}", .{err});
        defer allocator.free(msg);
        return ToolResult.err(allocator, .internal_error, msg, start_time);
    };

    const result_msg = try std.fmt.allocPrint(allocator, "{{\"id\": \"{s}\", \"embedding_dim\": {d}}}", .{ vec_id, embedding.len });
    defer allocator.free(result_msg);
    return ToolResult.ok(allocator, result_msg, start_time, null);
}
