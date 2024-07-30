const std = @import("std");
const testing = std.testing;

const channel_interface = @import("channel_interface.zig");
const Receipt = channel_interface.Receipt;
pub const ChannelWriter = channel_interface.ChannelWriter;
pub const ChannelReader = channel_interface.ChannelReader;

/// Represents an error that can occur when operating on the channel.
pub const ChannelError = error{
    BufferOverflow,
    ChannelClosed,
};

/// Creates a single-publisher-single-consumer channel with the specified element type and capacity.
///
/// Example
/// ```
/// var channel = try SimpleChannel(u8, 100).init(my_allocator);
/// defer channel.deinit();
/// ```
///
/// The channel is a fixed-size buffer that allows sending and receiving messages of type `T`.
/// The capacity determines the maximum number of messages that can be stored in the channel.
pub fn SimpleChannel(comptime T: type, comptime capacity: u64) type {
    return struct {
        const Self = @This();
        const SelfWriter = ChannelWriter(T);
        const SelfReader = ChannelReader(T);

        allocator: std.mem.Allocator,

        /// WARNING: private field, external modifications will cause unspecified behavior
        /// Message buffer. Once sent message should not be ever changed.
        items: []T,

        /// WARNING: private field, external modifications will cause unspecified behavior
        /// Indicates the channel state. Once closed, shouldn't be open!
        is_open: bool,

        /// WARNING: private field, external modifications will cause unspecified behavior
        /// Holds a message ID of last consumed item
        head_id: ?u64 = null,

        /// WARNING: private field, external modifications will cause unspecified behavior
        /// Holds a message ID of last sent item
        tail_id: ?u64 = null,

        /// Initializes a new channel with the specified allocator.
        ///
        /// The allocator is used to allocate memory for the channel's internal buffer.
        /// Returns an error if memory allocation fails.
        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .items = try allocator.alloc(T, capacity),
                .is_open = true,
            };
        }

        /// Deinitializes the channel and frees the allocated memory.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }

        /// Returns the number of messages currently stored in the channel.
        pub fn size(self: Self) u64 {
            if (self.head_id == null and self.tail_id == null) {
                return 0;
            }

            if (self.head_id) |h| {
                return self.tail_id.? - h;
            }

            return self.tail_id.? + 1;
        }

        /// Sends a message through the channel.
        ///
        /// Returns a receipt for the sent message if successful.
        /// Returns a `SendError.BufferOverflow` error if the channel is full.
        pub fn send(self: *Self, item: T) ChannelError!Receipt {
            if (!self.is_open) {
                return ChannelError.ChannelClosed;
            }

            if (self.size() == capacity) {
                return ChannelError.BufferOverflow;
            }

            const new_tail_id = if (self.tail_id) |oldTailPtr| oldTailPtr + 1 else 0;
            self.items[calcIdx(new_tail_id)] = item;
            self.tail_id = new_tail_id;
            return .{ .msg_id = new_tail_id };
        }

        fn sendFn(ptr: *anyopaque, item: T) ChannelError!Receipt {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return self.send(item);
        }

        /// Removes and returns the next item from the channel, or returns `null` if the channel is empty.
        ///
        /// If the channel is empty, this function returns `null`. Otherwise, it removes the next item from
        /// the channel and returns it.
        ///
        /// # Examples
        ///
        /// ```
        /// const item = channel.popOrNull();
        /// if (item) |m| {
        ///     // Process the item
        /// }
        /// ```
        pub fn popOrNull(self: *Self) ?*const T {
            if (self.head_id == self.tail_id) {
                return null;
            }

            const new_head_id = if (self.head_id) |h| h + 1 else 0;
            self.head_id = new_head_id;
            return &self.items[calcIdx(new_head_id)];
        }

        fn popOrNullFn(ptr: *anyopaque) ?*const T {
            const self: *Self = @ptrCast(@alignCast(ptr));
            return self.popOrNull();
        }

        /// Closes the channel.
        ///
        /// This function closes the channel, preventing further sending of messages.
        pub fn close(self: *Self) void {
            self.is_open = false;
        }

        fn closeFn(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.close();
        }

        /// Creates a writer interface instance for the channel.
        pub fn channelWriter(self: *Self) SelfWriter {
            return .{
                .ptr = self,
                .sendFn = Self.sendFn,
                .closeFn = Self.closeFn,
            };
        }

        /// Creates a consumer interface instance for the channel.
        pub fn channelReader(self: *Self) SelfReader {
            return .{
                .ptr = self,
                .popOrNullFn = Self.popOrNullFn,
                .closeFn = Self.closeFn,
            };
        }

        fn calcIdx(msgId: u64) u64 {
            return msgId % capacity;
        }
    };
}

test "init check" {
    var channel = try SimpleChannel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    try testing.expect(channel.is_open);
    try testing.expectEqual(channel.head_id, null);
    try testing.expectEqual(channel.tail_id, null);
}

test "produce up to capacity should pass" {
    var channel = try SimpleChannel(u8, 10).init(testing.allocator);
    defer channel.deinit();

    inline for (0..10) |n| {
        const r = try channel.send(@intCast(n));
        try testing.expectEqual(n, r.msg_id);
        try testing.expectEqual(n + 1, channel.size());
    }
}

test "produce above capacity should return error" {
    var channel = try SimpleChannel(u8, 1).init(testing.allocator);
    defer channel.deinit();
    _ = try channel.send(0);

    const result = channel.send(1);

    try testing.expectError(ChannelError.BufferOverflow, result);
}

test "popOrNull should dequeue an item if available or return null if not" {
    var channel = try SimpleChannel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    _ = try channel.send(1);

    var r = channel.popOrNull();
    try testing.expectEqual(1, r.?.*);

    r = channel.popOrNull();
    try testing.expectEqual(null, r);
}

test "pop releases the buffer slot, making it available for rewrite" {
    var channel = try SimpleChannel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        _ = try channel.send(1);
    }

    _ = channel.popOrNull();

    const r = try channel.send(1);
    try testing.expectEqual(10, r.msg_id);
    try testing.expectEqual(10, channel.size());
}

test "closed channel should error on publishing when closed but should allow for draining the channel" {
    var channel = try SimpleChannel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    _ = try channel.send(1);

    channel.close();

    const sr = channel.send(1);
    try testing.expectError(ChannelError.ChannelClosed, sr);

    const pr = channel.popOrNull();
    try testing.expect(pr != null);
}

test "channel writer should be able to produce messages and close the channel" {
    var channel = try SimpleChannel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    var ch_writer = channel.channelWriter();
    _ = try ch_writer.send(1);

    try testing.expectEqual(1, channel.size());

    ch_writer.close();
    try testing.expect(!channel.is_open);
}

test "channel reader should be able to consume messages and close the channel" {
    var channel = try SimpleChannel(u8, 10).init(testing.allocator);
    defer channel.deinit();

    _ = try channel.send(1);

    var ch_reader = channel.channelReader();
    const r = ch_reader.popOrNull();
    try testing.expectEqual(1, r.?.*);

    ch_reader.close();
    try testing.expect(!channel.is_open);
}
