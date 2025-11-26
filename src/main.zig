const std = @import("std");
const HtmlLexer = @import("lexer.zig").HtmlLexer;
const InputStream = @import("inputStream.zig").InputStream;
const HtmlParser = @import("parser.zig").HtmlParser;

pub fn main() !void {
    // just playing arround with fucntionality, real test will be writen later
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var parser = try HtmlParser.init(allocator, "test.html");
    defer parser.deinit();
    try parser.getTree();
}
