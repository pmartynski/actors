const std = @import("std");
const testing = std.testing;

/// Represents a receipt for a sent message.
const Receipt = struct {
    msgId: usize,
};

/// Represents an error that can occur when operating on the channel.
const ChannelError = error{
    BufferOverflow,
};

/// Creates a channel type with the specified element type and capacity.
///
/// The channel is a fixed-size buffer that allows sending and receiving messages of type `T`.
/// The capacity determines the maximum number of messages that can be stored in the channel.
pub fn Channel(comptime T: type, comptime capacity: usize) type {
    return struct {
        allocator: std.mem.Allocator,

        /// WARNING: private field, external modifications will cause unspecified behavior
        /// Message buffer. Once sent message should not be ever changed.
        items: []T,

        // TODO handle channel close
        /// WARNING: private field, external modifications will cause unspecified behavior
        /// Indicates the channel state.
        isOpen: bool,

        // TODO consider replacing usize to u64: if a message is produced every 1ms, it will last ~49 days for 32-bit architecture
        // u64 translates to 584 years even if a message is produced every 1ns
        // TODO rename fields according to zig naming convention (snake case)
        // TODO prepend private fields with _
        // TODO snake case for variables

        /// WARNING: private field, external modifications will cause unspecified behavior
        /// Holds a message ID of last consumed item
        headPtr: ?usize = null,

        /// WARNING: private field, external modifications will cause unspecified behavior
        /// Holds a message ID of last sent item
        tailPtr: ?usize = null,

        const Self = @This();

        /// Initializes a new channel with the specified allocator.
        ///
        /// The allocator is used to allocate memory for the channel's internal buffer.
        /// Returns an error if memory allocation fails.
        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .items = try allocator.alloc(T, capacity),
                .isOpen = true,
            };
        }

        /// Deinitializes the channel and frees the allocated memory.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }

        /// Returns the number of messages currently stored in the channel.
        pub fn size(self: Self) usize {
            if (self.headPtr == null and self.tailPtr == null) {
                return 0;
            }

            if (self.headPtr) |h| {
                return self.tailPtr.? - h;
            }

            return self.tailPtr.? + 1;
        }

        /// Sends a message through the channel.
        ///
        /// Returns a receipt for the sent message if successful.
        /// Returns a `SendError.BufferOverflow` error if the channel is full.
        pub fn send(self: *Self, item: T) ChannelError!Receipt {
            if (self.size() == capacity) {
                return ChannelError.BufferOverflow;
            }

            const newTailPtr = if (self.tailPtr) |oldTailPtr| oldTailPtr + 1 else 0;
            self.items[calcIdx(newTailPtr)] = item;
            self.tailPtr = newTailPtr;
            return .{ .msgId = newTailPtr };
        }

        pub fn popOrNull(self: *Self) ?T {
            if (self.headPtr == self.tailPtr) {
                return null;
            }

            const newHeadPtr = if (self.headPtr) |h| h + 1 else 0;
            self.headPtr = newHeadPtr;
            return self.items[calcIdx(newHeadPtr)];
        }

        fn calcIdx(msgId: usize) usize {
            return msgId % capacity;
        }
    };
}

test "init check" {
    var channel = try Channel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    try testing.expect(channel.isOpen);
    try testing.expectEqual(channel.headPtr, null);
    try testing.expectEqual(channel.tailPtr, null);
}

test "produce up to capacity should pass" {
    var channel = try Channel(u8, 10).init(testing.allocator);
    defer channel.deinit();

    inline for (0..10) |n| {
        const r = try channel.send(@intCast(n));
        try testing.expectEqual(n, r.msgId);
        try testing.expectEqual(n + 1, channel.size());
    }
}

test "produce above capacity should return error" {
    var channel = try Channel(u8, 1).init(testing.allocator);
    defer channel.deinit();
    _ = try channel.send(0);

    const result = channel.send(1);

    try testing.expectError(ChannelError.BufferOverflow, result);
}

test "popOrNull should dequeue an item if available or return null if not" {
    var channel = try Channel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    _ = try channel.send(1);

    var r = channel.popOrNull();
    try testing.expectEqual(1, r);

    r = channel.popOrNull();
    try testing.expectEqual(null, r);
}

test "pop releases the buffer slot, making it available for rewrite" {
    var channel = try Channel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        _ = try channel.send(1);
    }

    _ = channel.popOrNull();

    const r = try channel.send(1);
    try testing.expectEqual(10, r.msgId);
    try testing.expectEqual(10, channel.size());
}
