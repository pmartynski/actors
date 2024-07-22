/// Represents a receipt for a sent message.
pub const Receipt = struct {
    msg_id: u64,
};

/// Creates a channel producer for the specified type `T`.
///
/// The channel producer allows sending messages of type `T` through the channel.
///
pub fn ChannelProducer(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr: *anyopaque,
        sendFn: *const fn (self: *anyopaque, message: T) anyerror!Receipt,
        closeFn: *const fn (self: *anyopaque) void,

        /// Sends a message through the channel.
        ///
        /// Returns a receipt that can be used to track the status of the sent message.
        pub fn send(self: Self, message: T) anyerror!Receipt {
            return self.sendFn(self.ptr, message);
        }

        /// Closes the channel.
        ///
        /// This function is used to close the channel.
        pub fn close(self: Self) void {
            self.closeFn(self.ptr);
        }
    };
}

/// Creates a channel consumer for the specified type `T`.
///
/// The channel consumer allows receiving messages of type `T` from the channel.
///
pub fn ChannelConsumer(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr: *anyopaque,
        popOrNullFn: *const fn (self: *anyopaque) ?T,
        closeFn: *const fn (self: *anyopaque) void,

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
        pub fn popOrNull(self: Self) ?T {
            return self.popOrNullFn(self.ptr);
        }

        /// Closes the channel.
        ///
        /// This function is used to close the channel.
        ///
        pub fn close(self: Self) void {
            self.closeFn(self.ptr);
        }
    };
}
