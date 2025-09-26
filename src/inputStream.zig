const std = @import("std");

// TODO: THIS NEEDS TO HANDLE UNICODE TO BE IN SPEC ascii is ok for now
pub const InputStream = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn init(data: []const u8) InputStream {
        return .{ .data = data };
    }

    pub fn consumeChar(stream: *InputStream) ?u8 {
        if (stream.pos + 1 >= stream.data.len) {
            return null;
        }
        const char_ret = stream.data[stream.pos];
        stream.pos += 1;
        return char_ret; 
    }

    pub fn reconsumeChar(stream: *InputStream) void {
        stream.pos -= 1;
    }

    pub fn peek(stream: *InputStream, offset: usize) ?u8 {
        if (stream.pos + offset >= stream.data.len) {
            return null;
        }
        return stream.data[stream.pos + offset];
    }

    pub fn nextCharsAre(stream: *InputStream, string: []const u8) bool {
        for (string, 0..) |checkChar, i| {
            const maybeChar: ?u8 = stream.peek(i);
            if (maybeChar) |char| {
                if (char != checkChar) {
                    return false;
                }
            } else {
                return false;
            }
        }
        return true;
    }

    pub fn consumeString(stream: *InputStream, string: []const u8) bool {
        if (stream.nextCharsAre(string)) {
            stream.pos += string.len;
            return true;
        }
        return false;
    }
};
