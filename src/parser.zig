const std = @import("std");
const HtmlLexer = @import("lexer.zig").HtmlLexer;
const Tokens = @import("tokens.zig").Tokens;
const Nodes = @import("nodes.zig").Nodes;
const InputStream = @import("inputStream.zig").InputStream;

pub const HtmlParser = struct {
    lexer: HtmlLexer,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !HtmlParser {
        const stream = InputStream.init("<!DOCTYPE html> \n <html> <head><meta/></head><body></body></html> \n");
        const lexer = try HtmlLexer.init(allocator, stream);
        return .{ .lexer = lexer, .allocator = allocator };
    }
    pub fn deinit(self: *HtmlParser) void {
        self.lexer.deinit();
    }
};
