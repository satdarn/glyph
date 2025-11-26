const std = @import("std");

// TODO: THIS NEEDS TO HANDLE UNICODE TO BE IN SPEC ascii is ok for now
pub const InputStream = struct {
    data: []const u8,
    pos: usize = 0,
    case_sensitive: bool = true,
    allocator: std.mem.Allocator, 

    pub fn init(allocator: std.mem.Allocator, data: []const u8) InputStream {
        return .{ .data = data, .allocator = allocator };
    }

    pub fn initFromFile(allocator: std.mem.Allocator, file_path: []const u8) !InputStream {
        // Open the file
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        // Get file size
        const file_size = try file.getEndPos();

        // Allocate buffer
        const buffer = try allocator.alloc(u8, file_size);
        errdefer allocator.free(buffer);

        // Read entire file into buffer
        const bytes_read = try file.readAll(buffer);

        // Optionally verify we read everything
        if (bytes_read != file_size) {
            allocator.free(buffer);
            return error.IncompleteRead;
        }

        return .{
            .data = buffer,
            .allocator = allocator,
        };
    }

    pub fn deinit(stream: *InputStream) void {
        stream.allocator.free(stream.data);
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
        const stream_string = stream.data[stream.pos .. stream.pos + string.len];
        if (!stream.case_sensitive) {
            for (stream_string, 0..) |streamChar, i| {
                if (std.ascii.toLower(streamChar) != std.ascii.toLower(string[i])) {
                    return false;
                }
            }
            return true;
        }
        return std.mem.eql(u8, stream_string, string);
    }

    pub fn consumeString(stream: *InputStream, string: []const u8) bool {
        if (stream.nextCharsAre(string)) {
            stream.pos += string.len;
            return true;
        }
        return false;
    }
};
