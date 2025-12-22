// Vector Search Tool - Semantic search in vector memory (Time-Keeper memory tool)
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
                .name = try allocator.dupe(u8, "vector_search"),
                .description = try allocator.dupe(u8, "Search vector memory by semantic similarity. Returns the most relevant stored texts based on meaning. Example: {\"query\": \"restaurant preferences\", \"top_k\": 3} returns [{\"id\": \"vec_1\", \"text\": \"User loves Thai food...\", \"similarity\": 0.89}, ...]"),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {
                    \\    "query": {
                    \\      "type": "string",
                    \\      "description": "The search query text"
                    \\    },
                    \\    "top_k": {
                    \\      "type": "integer",
                    \\      "description": "Number of results to return (default: 5)"
                    \\    }
                    \\  },
                    \\  "required": ["query"]
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "vector_search",
            .description = "Search vector memory by similarity",
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

    const Args = struct { query: []const u8, top_k: ?i64 = null };
    const parsed = std.json.parseFromSlice(Args, allocator, arguments, .{}) catch {
        return ToolResult.err(allocator, .parse_error, "Invalid JSON arguments. Expected: {\"query\": \"...\", \"top_k\": 5}", start_time);
    };
    defer parsed.deinit();

    if (parsed.value.query.len == 0) {
        return ToolResult.err(allocator, .invalid_input, "Query cannot be empty", start_time);
    }

    const top_k: usize = if (parsed.value.top_k) |k| @intCast(@max(1, k)) else 5;

    // Generate embedding for the query
    const query_embedding = context.embedder.?.embed(context.config.embeddings_model, parsed.value.query) catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Failed to generate query embedding: {}. Ensure model '{s}' is available.", .{ err, context.config.embeddings_model });
        defer allocator.free(msg);
        return ToolResult.err(allocator, .internal_error, msg, start_time);
    };

    // Search vector memory
    const results = context.state.vectorSearch(query_embedding, top_k) catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Vector search failed: {}", .{err});
        defer allocator.free(msg);
        return ToolResult.err(allocator, .internal_error, msg, start_time);
    };
    defer allocator.free(results);

    if (results.len == 0) {
        return ToolResult.ok(allocator, "[]", start_time, null);
    }

    // Build JSON array of results
    var json_builder = std.ArrayListUnmanaged(u8){};
    defer json_builder.deinit(allocator);

    try json_builder.append(allocator, '[');
    for (results, 0..) |result, i| {
        try json_builder.appendSlice(allocator, "{\"id\": \"");
        try json_builder.appendSlice(allocator, result.id);
        try json_builder.appendSlice(allocator, "\", \"text\": \"");
        // Escape the text for JSON
        for (result.text) |c| {
            switch (c) {
                '"' => try json_builder.appendSlice(allocator, "\\\""),
                '\\' => try json_builder.appendSlice(allocator, "\\\\"),
                '\n' => try json_builder.appendSlice(allocator, "\\n"),
                '\r' => try json_builder.appendSlice(allocator, "\\r"),
                '\t' => try json_builder.appendSlice(allocator, "\\t"),
                else => try json_builder.append(allocator, c),
            }
        }
        try json_builder.appendSlice(allocator, "\", \"similarity\": ");
        var buf: [32]u8 = undefined;
        const sim_str = try std.fmt.bufPrint(&buf, "{d:.4}", .{result.similarity});
        try json_builder.appendSlice(allocator, sim_str);
        try json_builder.append(allocator, '}');
        if (i < results.len - 1) {
            try json_builder.appendSlice(allocator, ", ");
        }
    }
    try json_builder.append(allocator, ']');

    const json_result = try json_builder.toOwnedSlice(allocator);
    defer allocator.free(json_result);
    return ToolResult.ok(allocator, json_result, start_time, null);
}
