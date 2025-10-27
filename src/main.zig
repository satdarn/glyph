const std = @import("std");
const HtmlLexer = @import("lexer.zig").HtmlLexer;
const InputStream = @import("inputStream.zig").InputStream;
const Token = @import("tokens.zig").Token;
pub fn main() !void {
    // just playing arround with fucntionality, real test will be writen later
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const stream = InputStream.init("<!DOCTYPE html> \n <html> <p> </p>\n </html> \n");
    var lexer = try HtmlLexer.init(allocator, stream);
    defer lexer.deinit();

    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());
    Token.emitToken(try lexer.nextToken());

}
