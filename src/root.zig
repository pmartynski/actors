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
        items: []T,
        isOpen: bool,

        headPtr: ?usize = null,
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
            self.items[newTailPtr] = item;
            self.tailPtr = newTailPtr;
            return .{ .msgId = newTailPtr };
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
