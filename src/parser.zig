const std = @import("std");
const HtmlLexer = @import("lexer.zig").HtmlLexer;
const Tokens = @import("tokens.zig").Tokens;
const Nodes = @import("nodes.zig").Nodes;

pub const HtmlParser = struct {
    lexer: HtmlLexer,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, lexer: HtmlLexer) !HtmlParser {
        return .{.lexer=lexer, .allocator=allocator};
    }
    pub fn deinit(self :*HtmlParser) void{
        _ = self.lexer.tokenHandler.getQueueLen();
    }
};
