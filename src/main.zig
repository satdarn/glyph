const std = @import("std");
const HtmlLexer = @import("lexer.zig").HtmlLexer;
const InputStream = @import("inputStream.zig").InputStream;
pub fn main() !void {
    // just playing arround with fucntionality, real test will be writen later
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const stream = InputStream.init("<!DOCTYPE html> \n <html> \n </html> \n");
    _ = HtmlLexer.init(allocator, stream);
}
