const std = @import("std");
const HtmlLexer = @import("lexer.zig").HtmlLexer;
const Token = @import("tokens.zig").Token;
const Node = @import("nodes.zig").Node;
const InputStream = @import("inputStream.zig").InputStream;

const InsertionMode = enum {
    Initial,
    BeforeHtml,
    BeforeHead,
    InHead,
    InHeadNoscript,
    AfterHead,
    InBody,
    Text,
    InTable,
    InTableText,
    InCaption,
    InColumnGroup,
    InTableBody,
    InRow,
    InCell,
    InTemplate,
    AfterBody,
    InFrameset,
    AfterFrameset,
    AfterAfterBody,
    AfterAfterFrameset,
};

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
    pub fn getTree(self: *HtmlParser) !void {
        const insertion_mode: InsertionMode = .Initial;
        const token: *Token = try self.lexer.nextToken();
        // const document: *Node = try Node.createDocument(self.allocator); 
        switch (insertion_mode) {
            .Initial => {
            },
            .BeforeHtml => {},
            .BeforeHead => {},
            .InHead => {},
            .InHeadNoscript => {},
            .AfterHead => {},
            .InBody => {},
            .Text => {},
            .InTable => {},
            .InTableText => {},
            .InCaption => {},
            .InColumnGroup => {},
            .InTableBody => {},
            .InRow => {},
            .InCell => {},
            .InTemplate => {},
            .AfterBody => {},
            .InFrameset => {},
            .AfterFrameset => {},
            .AfterAfterBody => {},
            .AfterAfterFrameset => {},
        }
    }
};
