const std = @import("std");
const testing = std.testing;

const simple_channel = @import("simple_channel.zig");
pub const SimpleChannel = simple_channel.SimpleChannel;
pub const Receipt = simple_channel.Receipt;
pub const ChannelError = simple_channel.ChannelError;

test {
    testing.refAllDecls(@This());
}
