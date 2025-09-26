const std = @import("std");

pub const Token = union(enum) {
    DOCTYPE: struct {
        name: std.ArrayList(u8),
        publicIdent: std.ArrayList(u8),
        systemIdent: std.ArrayList(u8),
        forceQuirks: bool,
    },
    Tag: struct {
        type: enum { StartTag, EndTag },
        tagName: std.ArrayList(u8),
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
    pub fn emitToken(token: *Token) void {
        switch (token.*) {
            .DOCTYPE => |tok| {
                std.debug.print("DOCTYPE TKN\n", .{});
                std.debug.print("   name:{s}\n", .{tok.name.items});
                std.debug.print("   publicIdent : {s}\n", .{tok.publicIdent.items});
                std.debug.print("   systemIdent : {s}\n", .{tok.systemIdent.items});
                std.debug.print("   forceQuirks : {}\n", .{tok.forceQuirks});
            },
            .Tag => |tok| {
                if (tok.type == .StartTag) {
                    std.debug.print("StartTag TKN\n", .{});
                    std.debug.print("   tagName : {s}\n", .{tok.tagName.items});
                    std.debug.print("   selfClosing : {}\n", .{tok.selfClosing});
                    std.debug.print("   selfClosing : {}\n", .{tok.selfClosing});
                } else {
                    std.debug.print("EndTag TKN\n", .{});
                    std.debug.print("   tagName : {s}\n", .{tok.tagName.items});
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

pub const TokenHandler = struct {
    allocator: std.mem.Allocator,
    tokenRefList: std.ArrayList(*Token),
    emitList: std.ArrayList(*Token),
    pub fn init(allocator: std.mem.Allocator) !TokenHandler {
        // #TODO: optimize the size of the "Token List" that best represents the how we should keep on hand,
        // maybe move emit to this struct and we can dealloc from emit ???
        const tokenRefList = try std.ArrayList(*Token).initCapacity(allocator, 30);
        const emitList = try std.ArrayList(*Token).initCapacity(allocator, 30);
        return .{ .allocator = allocator, .tokenRefList = tokenRefList, .emitList = emitList };
    }
    pub fn deinit(self: *TokenHandler) void {
        for (self.tokenRefList.items) |tok| {
            if (tok.* == .Tag) {
                tok.Tag.tagName.deinit(self.allocator);
            }
            if (tok.* == .DOCTYPE) {}
            self.allocator.destroy(tok);
        }
        self.tokenRefList.deinit(self.allocator);
    }
    pub fn emit(self: *TokenHandler, tok: *Token) !void {
        Token.emitToken(tok);
        self.emitList.append(self.allocator, tok);
    }
    pub fn createDOCTYPEToken(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        const nameList = try std.ArrayList(u8).initCapacity(self.allocator, 1);
        const publicIdentList = try std.ArrayList(u8).initCapacity(self.allocator, 1);
        const systemIdentList = try std.ArrayList(u8).initCapacity(self.allocator, 1);

        tok.* = .{ .DOCTYPE = .{ .name = nameList, .publicIdent = publicIdentList, .systemIdent = systemIdentList, .forceQuirks = false } };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }
    pub fn createStartTag(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        const tagName = try std.ArrayList(u8).initCapacity(self.allocator, 1);
        tok.* = .{ .Tag = .{
            .type = .StartTag,
            .tagName = tagName,
            .selfClosing = false,
            .attributes = &[_]Attributes{},
        } };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }

    pub fn createEndTag(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        const tagName = try std.ArrayList(u8).initCapacity(self.allocator, 1);
        tok.* = .{ .Tag = .{
            .type = .EndTag,
            .tagName = tagName,
            .selfClosing = false,
            .attributes = &[_]Attributes{},
        } };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }

    pub fn createComment(self: *TokenHandler, data: u8) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .Comment = .{ .data = &[1]u8{data} } };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }
    pub fn createCharacter(self: *TokenHandler, data: u8) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .Character = .{ .data = &[1]u8{data} } };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }
    pub fn createEOF(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .EndOfFile = {} };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }
};

pub const Attributes = struct {
    name: []const u8,
    value: []const u8,
};
