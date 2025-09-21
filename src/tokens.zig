const std = @import("std");

pub const Token = union(enum) {
    DOCTYPE: struct {
        name: []const u8,
        publicIdent: []const u8,
        systemIdent: []const u8,
        forceQuirks: bool,
    },
    Tag: struct {
        type: enum { StartTag, EndTag },
        tagName: []const u8,
        selfClosing: bool,
        attributes: []Attributes,
    },
    Comment: struct {
        data: []const u8,
    },
    Character: struct {
        data: []const u8,
    },
    EndOfFile: void,
    pub fn emitToken(token: Token) void {
        switch (token) {
            .DOCTYPE => |tok| {
                std.debug.print("DOCTYPE TKN\n", .{});
                std.debug.print("   name:{s}\n", .{tok.name});
                std.debug.print("   publicIdent : {s}\n", .{tok.publicIdent});
                std.debug.print("   systemIdent : {s}\n", .{tok.systemIdent});
                std.debug.print("   forceQuirks : {}\n", .{tok.forceQuirks});
            },
            .Tag => |tok| {
                if (tok.type == .StartTag) {
                    std.debug.print("StartTag TKN\n", .{});
                    std.debug.print("   tagName : {s}\n", .{tok.tagName});
                    std.debug.print("   selfClosing : {}\n", .{tok.selfClosing});
                    std.debug.print("   selfClosing : {}\n", .{tok.selfClosing});
                } else {
                    std.debug.print("EndTag TKN\n", .{});
                    std.debug.print("   tagName : {s}\n", .{tok.tagName});
                    std.debug.print("   selfClosing : {}\n", .{tok.selfClosing});
                    std.debug.print("   selfClosing : {}\n", .{tok.selfClosing});
                }
            },
            .Comment => |tok| {
                std.debug.print("Comment TKN\n", .{});
                std.debug.print("   data: {s}\n", .{tok.data});
            },
            .Character => |tok| {
                std.debug.print("Character TKN\n", .{});
                std.debug.print("   data: {s}\n", .{tok.data});
            },
            .EndOfFile => std.debug.print("EOF TKN\n", .{}),
        }
    }
};

const TokenHandler = struct {
    allocator: std.mem.Allocator,
    tokList: std.ArrayList(*Token),

    pub fn init(allocator: std.mem.Allocator) TokenHandler {
        return .{ .allocator = allocator, .tokList = std.ArrayList(*Token).init(allocator) };
    }
    pub fn deinit(self: *TokenHandler) void {
        for (self.tokList) |tok| {
            if (tok == .Tag) {
                tok.tagName.deinit();
            }
            self.allocator.destroy(tok);
        }
    }
    pub fn createDOCTYPEToken(self: *TokenHandler, name: []const u8, publicIdent: []const u8, systemIdent: []const u8, forceQuirks: bool) !*Token {
        var tok: *Token = try self.allocator.create(Token);
        tok = .{ .DOCTYPE = .{ .name = name, .publicIdent = publicIdent, .systemIdent = systemIdent, .forceQuirks = forceQuirks } };
        self.tokList.append(tok);
        return tok;
    }
    pub fn createStartTag(self: *TokenHandler, firstChar: u8, selfClosing: bool) !*Token {
        var tok: *Token = try self.allocator.create(Token);
        const tagName = std.ArrayList(u8).init(self.allocator);
        tagName.append(firstChar);
        tok = .{ .Tag = .{
            .type = .StartTag,
            .tagName = tagName,
            .selfClosing = selfClosing,
            .attributes = &[_]Attributes{},
        } };
        self.tokList.append(tok);
        return tok;
    }

    pub fn createEndTag(self: *TokenHandler, firstChar: u8, selfClosing: bool) !*Token {
        var tok: *Token = try self.allocator.create(Token);
        const tagName = std.ArrayList(u8).init(self.allocator);
        tagName.append(firstChar);
        tok = .{ .Tag = .{
            .type = .EndTag,
            .tagName = tagName,
            .selfClosing = selfClosing,
            .attributes = &[_]Attributes{},
        } };
        self.tokList.append(tok);
        return tok;
    }

    pub fn createComment(self: *TokenHandler, data: u8) !*Token {
        var tok: *Token = try self.allocator.create(Token);
        tok = .{ .Comment = .{ .data = [_]u8{data} } };
        self.tokList.append(tok);
        return tok;
    }
    pub fn createCharacter(self: *TokenHandler, data: u8) !*Token {
        var tok: *Token = try self.allocator.create(Token);
        tok = .{ .Character = .{ .data = [_]u8{data} } };
        self.tokList.append(tok);
        return tok;
    }
    pub fn createEOF(self: *TokenHandler)!*Token {
        var tok: *Token = try self.allocator.create(Token);
        tok = .{ .EndOfFile = {} };
        self.tokList.append(tok);
        return tok;
    }
};

pub const Attributes = struct {
    name: []const u8,
    value: []const u8,
};
