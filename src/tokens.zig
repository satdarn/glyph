const std = @import("std");

const tokErrors = error{
    WrongTagType,
    NoAttribute,
    NoElementsInQueue,
};

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
        attributes: AttributeList,
    },
    Comment: struct {
        data: std.ArrayList(u8),
    },
    Character: struct {
        data: []const u8,
    },
    ReplacementCharacter: void, // REPLACEMENT CHARACTER character token U+FFFD
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
                } else {
                    std.debug.print("EndTag TKN\n", .{});
                    std.debug.print("   tagName : {s}\n", .{tok.tagName.items});
                    std.debug.print("   selfClosing : {}\n", .{tok.selfClosing});
                }
            },
            .Comment => |tok| {
                std.debug.print("Comment TKN\n", .{});
                std.debug.print("   data: {s}\n", .{tok.data.items});
            },
            .Character => |tok| {
                std.debug.print("Character TKN\n", .{});
                std.debug.print("   data: {s}\n", .{tok.data});
            },
            .ReplacementCharacter => std.debug.print("EOF TKN\n", .{}),
            .EndOfFile => std.debug.print("EOF TKN\n", .{}),
        }
    }
};

pub const TokenHandler = struct {
    allocator: std.mem.Allocator,
    tokenRefList: std.ArrayList(*Token),
    tokenQueue: std.ArrayList(*Token),
    pub fn init(allocator: std.mem.Allocator) !TokenHandler {
        // #TODO: optimize the size of the "Token List" that best represents the how we should keep on hand,
        // maybe move emit to this struct and we can dealloc from emit ???
        const tokenRefList = try std.ArrayList(*Token).initCapacity(allocator, 30);
        const tokenQueue = try std.ArrayList(*Token).initCapacity(allocator, 30);
        return .{
            .allocator = allocator,
            .tokenRefList = tokenRefList,
            .tokenQueue = tokenQueue,
        };
    }
    pub fn deinit(self: *TokenHandler) void {
        for (self.tokenRefList.items) |tok| {
            if (tok.* == .Tag) {
                tok.Tag.tagName.deinit(self.allocator);
                tok.Tag.attributes.deinit();
            }
            if (tok.* == .DOCTYPE) {
                tok.DOCTYPE.name.deinit(self.allocator);
                tok.DOCTYPE.publicIdent.deinit(self.allocator);
                tok.DOCTYPE.systemIdent.deinit(self.allocator);
            }
            if (tok.* == .Comment) {
                tok.Comment.data.deinit(self.allocator);
            }
            self.allocator.destroy(tok);
        }
        self.tokenRefList.deinit(self.allocator);
        self.tokenQueue.deinit(self.allocator);
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
            .attributes = try AttributeList.init(self.allocator),
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
            .attributes = try AttributeList.init(self.allocator),
        } };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }

    pub fn createComment(self: *TokenHandler, data: u8) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .Comment = .{ .data = try std.ArrayList(u8).initCapacity(self.allocator, 32) } };
        try self.tokenRefList.append(self.allocator, tok);
        if (data != 0) try tok.Comment.data.append(self.allocator, data);
        return tok;
    }
    pub fn createCharacter(self: *TokenHandler, data: u8) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .Character = .{ .data = &[1]u8{data} } };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }
    pub fn createReplacement(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .ReplacementCharacter = {} };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }
    pub fn createEOF(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .EndOfFile = {} };
        try self.tokenRefList.append(self.allocator, tok);
        return tok;
    }

    pub fn enqueue(self: *TokenHandler, new: *Token) !void{
        try self.tokenQueue.append(self.allocator, new);
    }
    pub fn dequeue(self: *TokenHandler) !*Token{
        if (self.tokenQueue.items.len == 0) return tokErrors.NoElementsInQueue;
        const tok = self.tokenQueue.items[0];
        _ = self.tokenQueue.orderedRemove(0);
        return tok;
    }
    pub fn getQueueLen(self: *TokenHandler) usize{
        return self.tokenQueue.items.len; 
    }
};

pub const Attribute = struct {
    name: ?std.ArrayList(u8),
    value: ?std.ArrayList(u8),
};

pub const AttributeList = struct {
    list: std.ArrayList(Attribute),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !AttributeList {
        return .{ .list = try std.ArrayList(Attribute).initCapacity(allocator, 3), .allocator = allocator };
    }
    pub fn deinit(self: *AttributeList) void {
        var i: usize = 0;
        while (i < self.list.items.len) : (i += 1) {
            if (self.list.items[i].name) |*name| {
                name.deinit(self.allocator);
            }
            if (self.list.items[i].value) |*value| {
                value.deinit(self.allocator);
            }
        }
        self.list.deinit(self.allocator);
    }

    pub fn addAttribute(self: *AttributeList) !void {
        try self.list.append(self.allocator, .{ .name = null, .value = null });
    }

    pub fn appendAttrName(self: *AttributeList, data: u8) !void {
        if (self.list.items.len != 0) {
            return tokErrors.NoAttribute;
        }
        if (self.list.items[self.list.items.len - 1].name == null) {
            self.list.items[self.list.items.len - 1].name = try std.ArrayList(u8).initCapacity(self.allocator, 10);
        }
        if (self.list.items[self.list.items.len - 1].name) |*name| {
            try name.append(self.allocator, data);
        }
    }

    pub fn appendAttrData(self: *AttributeList, data: u8) !void {
        if (self.list.items.len != 0) {
            return tokErrors.NoAttribute;
        }
        if (self.list.items[self.list.items.len - 1].value == null) {
            self.list.items[self.list.items.len - 1].value = try std.ArrayList(u8).initCapacity(self.allocator, 10);
        }
        if (self.list.items[self.list.items.len - 1].value) |*data_str| {
            try data_str.append(self.allocator, data);
        }
    }
};

const TokenQueue = struct {
    queue: std.ArrayList(*Token),
    len: usize,
};
