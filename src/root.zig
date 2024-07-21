const std = @import("std");
const testing = std.testing;

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

        consPtr: usize,
        sendPtr: usize,

        pub fn init(allocator: std.mem.Allocator) !@This() {
            return .{
                .allocator = allocator,
                .items = try allocator.alloc(T, capacity),
                .isOpen = true,
                .consPtr = 0,
                .sendPtr = 0,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.items);
        }
    };
}

test "init check" {
    var channel = try Channel(u8, 10).init(testing.allocator);
    defer channel.deinit();
    try testing.expect(channel.isOpen);
    try testing.expectEqual(channel.consPtr, 0);
    try testing.expectEqual(channel.sendPtr, 0);
}

test "producer consumer test" {}
