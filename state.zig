// Application state management (Phase 1: Todo tracking for master loop)
// Extended with Time-Keeper memory tools: scratchpad, key-value store, vector database
const std = @import("std");
const mem = std.mem;

/// Compute cosine similarity between two embedding vectors
/// Returns value between -1.0 and 1.0 (typically 0.0 to 1.0 for normalized embeddings)
fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    if (a.len != b.len) return 0.0;

    var dot_product: f32 = 0.0;
    var norm_a: f32 = 0.0;
    var norm_b: f32 = 0.0;

    for (a, b) |av, bv| {
        dot_product += av * bv;
        norm_a += av * av;
        norm_b += bv * bv;
    }

    const denominator = @sqrt(norm_a) * @sqrt(norm_b);
    if (denominator == 0.0) return 0.0;

    return dot_product / denominator;
}

/// Todo status enum for tracking progress
pub const TodoStatus = enum { pending, in_progress, completed };

/// Entry in vector memory database (simple dictionary approach for Time-Keeper)
pub const VectorMemoryEntry = struct {
    id: []const u8, // owned string ID like "vec_1", "vec_2"
    text: []const u8, // owned text content
    embedding: []f32, // owned embedding vector
};

/// Result from vector similarity search
pub const VectorSearchResult = struct {
    id: []const u8, // borrowed from VectorMemoryEntry
    text: []const u8, // borrowed from VectorMemoryEntry
    similarity: f32, // cosine similarity score (0.0 to 1.0)
};

/// Individual todo with ID, content, and status
pub const Todo = struct {
    id: []const u8, // String ID like "todo_1", "todo_2", etc.
    content: []const u8,
    status: TodoStatus,
};

/// Pending file to be indexed by Graph RAG
pub const PendingIndexFile = struct {
    path: []const u8, // owned
    content: []const u8, // owned
};

/// Timer notification that has fired and is waiting to be injected as system message
pub const TimerNotification = struct {
    label: []const u8, // owned string, e.g., "check_breakfast_order"
    duration_ms: u64, // original duration for logging
    fired_at: i64, // timestamp when timer expired
};

/// Benchmark metrics for tracking tool usage and loop completions
pub const BenchmarkMetrics = struct {
    set_timer_calls: usize = 0,
    kv_set_calls: usize = 0,
    get_current_time_calls: usize = 0,
    complete_loops: usize = 0,
    benchmark_start_time: ?i64 = null,

    pub fn reset(self: *BenchmarkMetrics) void {
        self.set_timer_calls = 0;
        self.kv_set_calls = 0;
        self.get_current_time_calls = 0;
        self.complete_loops = 0;
        self.benchmark_start_time = null;
    }

    pub fn incrementToolCall(self: *BenchmarkMetrics, tool_name: []const u8) void {
        if (std.mem.eql(u8, tool_name, "set_timer")) {
            self.set_timer_calls += 1;
        } else if (std.mem.eql(u8, tool_name, "kv_set")) {
            self.kv_set_calls += 1;
        } else if (std.mem.eql(u8, tool_name, "get_current_time")) {
            self.get_current_time_calls += 1;
        }
    }

    pub fn incrementLoops(self: *BenchmarkMetrics) void {
        self.complete_loops += 1;
    }
};

/// Session-ephemeral application state
pub const AppState = struct {
    allocator: mem.Allocator,
    todos: std.ArrayListUnmanaged(Todo),
    next_todo_id: usize,
    session_start: i64,
    read_files: std.StringHashMapUnmanaged(void), // Track files read in this session
    indexed_files: std.StringHashMapUnmanaged(void), // Track files indexed in Graph RAG
    pending_index_files: std.ArrayListUnmanaged(PendingIndexFile), // Queue for background indexing

    // Time-Keeper Memory Tools (session-ephemeral)
    scratchpad: std.ArrayListUnmanaged(u8), // Free-form text buffer
    kv_store: std.StringHashMapUnmanaged([]const u8), // key -> owned value
    vector_memory: std.StringHashMapUnmanaged(VectorMemoryEntry), // id -> entry
    next_vector_id: usize, // Auto-incrementing ID for vector entries

    // Timer System (for async notifications)
    timer_notifications: std.ArrayListUnmanaged(TimerNotification), // Queue of fired timers
    timer_mutex: std.Thread.Mutex, // Protects timer_notifications

    // Benchmark Metrics (for tracking tool usage and loop completions)
    benchmark_metrics: BenchmarkMetrics,

    pub fn init(allocator: mem.Allocator) AppState {
        return .{
            .allocator = allocator,
            .todos = .{},
            .next_todo_id = 1,
            .session_start = std.time.milliTimestamp(),
            .read_files = .{},
            .indexed_files = .{},
            .pending_index_files = .{},
            // Time-Keeper Memory Tools
            .scratchpad = .{},
            .kv_store = .{},
            .vector_memory = .{},
            .next_vector_id = 1,
            // Timer System
            .timer_notifications = .{},
            .timer_mutex = .{},
            // Benchmark Metrics
            .benchmark_metrics = .{},
        };
    }

    pub fn addTodo(self: *AppState, content: []const u8) ![]const u8 {
        // Generate string ID like "todo_1", "todo_2", etc.
        const todo_id = try std.fmt.allocPrint(self.allocator, "todo_{d}", .{self.next_todo_id});
        errdefer self.allocator.free(todo_id);

        self.next_todo_id += 1;

        const owned_content = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(owned_content);

        try self.todos.append(self.allocator, .{
            .id = todo_id,
            .content = owned_content,
            .status = .pending,
        });

        return todo_id;
    }

    pub fn updateTodo(self: *AppState, todo_id: []const u8, new_status: TodoStatus) !void {
        for (self.todos.items) |*todo| {
            if (mem.eql(u8, todo.id, todo_id)) {
                todo.status = new_status;
                return;
            }
        }
        return error.TodoNotFound;
    }

    pub fn getTodos(self: *AppState) []const Todo {
        return self.todos.items;
    }

    pub fn markFileAsRead(self: *AppState, path: []const u8) !void {
        // Check if already tracked to avoid duplicate allocations
        if (self.read_files.contains(path)) {
            return; // Already marked, nothing to do
        }

        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);
        try self.read_files.put(self.allocator, owned_path, {});
    }

    pub fn wasFileRead(self: *AppState, path: []const u8) bool {
        return self.read_files.contains(path);
    }

    pub fn markFileAsIndexed(self: *AppState, path: []const u8) !void {
        // Check if already indexed to avoid duplicate allocations
        if (self.indexed_files.contains(path)) {
            return; // Already indexed
        }

        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);
        try self.indexed_files.put(self.allocator, owned_path, {});
    }

    pub fn wasFileIndexed(self: *AppState, path: []const u8) bool {
        return self.indexed_files.contains(path);
    }

    /// Queue a file for background Graph RAG indexing
    pub fn queueFileForIndexing(self: *AppState, path: []const u8, content: []const u8) !void {
        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);

        const owned_content = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(owned_content);

        try self.pending_index_files.append(self.allocator, .{
            .path = owned_path,
            .content = owned_content,
        });
    }

    /// Check if there are files pending indexing
    pub fn hasPendingIndexing(self: *AppState) bool {
        return self.pending_index_files.items.len > 0;
    }

    /// Pop the next pending file from the indexing queue
    /// Returns null if queue is empty
    /// Caller owns returned memory and must free path and content
    pub fn popPendingIndexFile(self: *AppState) ?PendingIndexFile {
        if (self.pending_index_files.items.len == 0) return null;
        return self.pending_index_files.orderedRemove(0);
    }

    // ============================================================
    // Time-Keeper Memory Tools: Scratchpad
    // ============================================================

    /// Write/replace entire scratchpad content
    pub fn writeScratchpad(self: *AppState, text: []const u8) !void {
        self.scratchpad.clearRetainingCapacity();
        try self.scratchpad.appendSlice(self.allocator, text);
    }

    /// Append text to scratchpad
    pub fn appendScratchpad(self: *AppState, text: []const u8) !void {
        try self.scratchpad.appendSlice(self.allocator, text);
    }

    /// Read scratchpad content (returns borrowed slice)
    pub fn readScratchpad(self: *AppState) []const u8 {
        return self.scratchpad.items;
    }

    /// Clear scratchpad
    pub fn clearScratchpad(self: *AppState) void {
        self.scratchpad.clearRetainingCapacity();
    }

    // ============================================================
    // Time-Keeper Memory Tools: Key-Value Store
    // ============================================================

    /// Set/update a key-value pair (makes owned copies)
    /// Returns true if key was created, false if updated
    pub fn kvSet(self: *AppState, key: []const u8, value: []const u8) !bool {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        if (self.kv_store.getPtr(key)) |existing_value| {
            // Update existing - free old value
            self.allocator.free(existing_value.*);
            existing_value.* = owned_value;
            return false; // updated
        } else {
            // Create new - also need to copy the key
            const owned_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(owned_key);
            try self.kv_store.put(self.allocator, owned_key, owned_value);
            return true; // created
        }
    }

    /// Get value by key (returns borrowed slice, null if not found)
    pub fn kvGet(self: *AppState, key: []const u8) ?[]const u8 {
        return self.kv_store.get(key);
    }

    /// Delete key-value pair, returns true if key existed
    pub fn kvDelete(self: *AppState, key: []const u8) bool {
        if (self.kv_store.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
            return true;
        }
        return false;
    }

    /// List all keys in KV store
    /// Caller must free the returned slice (but not the key strings inside)
    pub fn kvListKeys(self: *AppState) ![][]const u8 {
        var keys = std.ArrayListUnmanaged([]const u8){};
        errdefer keys.deinit(self.allocator);

        var iter = self.kv_store.keyIterator();
        while (iter.next()) |key| {
            try keys.append(self.allocator, key.*);
        }

        return try keys.toOwnedSlice(self.allocator);
    }

    // ============================================================
    // Time-Keeper Memory Tools: Vector Database
    // ============================================================

    /// Add text with embedding to vector memory
    /// Returns the auto-generated ID (owned by state, borrowed by caller)
    pub fn vectorAdd(self: *AppState, text: []const u8, embedding: []const f32) ![]const u8 {
        // Generate string ID like "vec_1", "vec_2", etc.
        const vec_id = try std.fmt.allocPrint(self.allocator, "vec_{d}", .{self.next_vector_id});
        errdefer self.allocator.free(vec_id);

        self.next_vector_id += 1;

        const owned_text = try self.allocator.dupe(u8, text);
        errdefer self.allocator.free(owned_text);

        const owned_embedding = try self.allocator.dupe(f32, embedding);
        errdefer self.allocator.free(owned_embedding);

        const entry = VectorMemoryEntry{
            .id = vec_id,
            .text = owned_text,
            .embedding = owned_embedding,
        };

        try self.vector_memory.put(self.allocator, vec_id, entry);

        return vec_id;
    }

    /// Search vector memory by cosine similarity
    /// Returns top_k results sorted by similarity (descending)
    /// Caller must free the returned slice
    pub fn vectorSearch(self: *AppState, query_embedding: []const f32, top_k: usize) ![]VectorSearchResult {
        // Collect all entries with their similarities
        var results = std.ArrayListUnmanaged(VectorSearchResult){};
        defer results.deinit(self.allocator);

        var iter = self.vector_memory.valueIterator();
        while (iter.next()) |entry| {
            const similarity = cosineSimilarity(query_embedding, entry.embedding);
            try results.append(self.allocator, .{
                .id = entry.id,
                .text = entry.text,
                .similarity = similarity,
            });
        }

        // Sort by similarity descending
        std.mem.sort(VectorSearchResult, results.items, {}, struct {
            fn lessThan(_: void, a: VectorSearchResult, b: VectorSearchResult) bool {
                return a.similarity > b.similarity; // Descending order
            }
        }.lessThan);

        // Take top_k results
        const result_count = @min(top_k, results.items.len);
        const final_results = try self.allocator.alloc(VectorSearchResult, result_count);
        @memcpy(final_results, results.items[0..result_count]);

        return final_results;
    }

    /// Delete vector entry by ID, returns true if ID existed
    pub fn vectorDelete(self: *AppState, id: []const u8) bool {
        if (self.vector_memory.fetchRemove(id)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value.id);
            self.allocator.free(kv.value.text);
            self.allocator.free(kv.value.embedding);
            return true;
        }
        return false;
    }

    /// Get vector entry by ID (returns null if not found)
    pub fn vectorGet(self: *AppState, id: []const u8) ?VectorMemoryEntry {
        return self.vector_memory.get(id);
    }

    // ============================================================
    // Timer System (for async notifications)
    // ============================================================

    /// Add a timer notification (called by timer thread when timer expires)
    /// Thread-safe via mutex
    pub fn addTimerNotification(self: *AppState, label: []const u8, duration_ms: u64) !void {
        self.timer_mutex.lock();
        defer self.timer_mutex.unlock();

        const owned_label = try self.allocator.dupe(u8, label);
        errdefer self.allocator.free(owned_label);

        try self.timer_notifications.append(self.allocator, .{
            .label = owned_label,
            .duration_ms = duration_ms,
            .fired_at = std.time.milliTimestamp(),
        });
    }

    /// Pop all pending timer notifications (called by main loop)
    /// Thread-safe via mutex. Caller owns returned slice and must free labels.
    /// Returns empty slice if no notifications pending.
    pub fn popTimerNotifications(self: *AppState) ![]TimerNotification {
        self.timer_mutex.lock();
        defer self.timer_mutex.unlock();

        if (self.timer_notifications.items.len == 0) {
            return &[_]TimerNotification{};
        }

        const result = try self.timer_notifications.toOwnedSlice(self.allocator);
        self.timer_notifications = .{};
        return result;
    }

    /// Check if there are pending timer notifications (non-destructive)
    /// Thread-safe via mutex.
    pub fn hasTimerNotifications(self: *AppState) bool {
        self.timer_mutex.lock();
        defer self.timer_mutex.unlock();
        return self.timer_notifications.items.len > 0;
    }

    pub fn deinit(self: *AppState) void {
        for (self.todos.items) |todo| {
            self.allocator.free(todo.id);
            self.allocator.free(todo.content);
        }
        self.todos.deinit(self.allocator);

        // Free read_files hashmap
        var iter = self.read_files.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.read_files.deinit(self.allocator);

        // Free indexed_files hashmap
        var indexed_iter = self.indexed_files.keyIterator();
        while (indexed_iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.indexed_files.deinit(self.allocator);

        // Free pending index files queue
        for (self.pending_index_files.items) |pending| {
            self.allocator.free(pending.path);
            self.allocator.free(pending.content);
        }
        self.pending_index_files.deinit(self.allocator);

        // Free Time-Keeper Memory Tools
        // Scratchpad
        self.scratchpad.deinit(self.allocator);

        // KV Store - free both keys and values
        var kv_iter = self.kv_store.iterator();
        while (kv_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.kv_store.deinit(self.allocator);

        // Vector Memory - free all entry fields
        // Note: entry.id is the same pointer as the key, so only free key (not .id)
        var vec_iter = self.vector_memory.iterator();
        while (vec_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*); // This is also entry.value_ptr.id
            self.allocator.free(entry.value_ptr.text);
            self.allocator.free(entry.value_ptr.embedding);
        }
        self.vector_memory.deinit(self.allocator);

        // Timer notifications - free labels
        self.timer_mutex.lock();
        for (self.timer_notifications.items) |notif| {
            self.allocator.free(notif.label);
        }
        self.timer_notifications.deinit(self.allocator);
        self.timer_mutex.unlock();
    }
};
