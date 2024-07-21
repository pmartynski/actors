const std = @import("std");
const testing = std.testing;

const Receipt = struct {
    msgId: usize,
};

const SendError = error{
    BufferOverflow,
};

pub fn Channel(comptime T: type, comptime capacity: usize) type {
    return struct {
        // Create a rolling buffer:
        // - fixed size array of delcared capacity
        // - items must be immutable after dequeue
        // - stored on the heap?
        // - two indexes (refered as IDs), top and bottom (or three for ack)
        //   + consPtr
        //   + sendPtr
        //   + ackPtr
        // - capacity declared in the begining
        // - size = sendPtr - consPtr or sendPtr - ackPtr, to prevent from overwriting items under processing
        allocator: std.mem.Allocator,
        items: []T,
        isOpen: bool,

        headPtr: ?usize = null,
        tailPtr: ?usize = null,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .allocator = allocator,
                .items = try allocator.alloc(T, capacity),
                .isOpen = true,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }

        pub fn size(self: Self) usize {
            if (self.headPtr == null and self.tailPtr == null) {
                return 0;
            }

            if (self.headPtr) |h| {
                return self.tailPtr.? - h;
            }

            return self.tailPtr.? + 1;
        }

        pub fn send(self: *Self, item: T) SendError!Receipt {
            if (self.size() == capacity) {
                return SendError.BufferOverflow;
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

    try testing.expectError(SendError.BufferOverflow, result);
}
