const std = @import("std");

const tokErrors = error{
    WrongTagType,
    NoAttribute,
    NoElementsInQueue,
};

pub const Token = union(enum) {
    DOCTYPE: struct {
        name: std.ArrayList(u8),
        public_ident: std.ArrayList(u8),
        system_ident: std.ArrayList(u8),
        force_quirks: bool,
    },
    Tag: struct {
        type: enum { StartTag, EndTag },
        tag_name: std.ArrayList(u8),
        self_closing: bool,
        attributes: AttributeList,
    },
    Comment: struct {
        data: std.ArrayList(u8),
    },
    Character: struct {
        data: std.ArrayList(u8),
    },
    ReplacementCharacter: void, // REPLACEMENT CHARACTER character token U+FFFD
    EndOfFile: void,
    pub fn printToken(token: *Token) void {
        switch (token.*) {
            .DOCTYPE => |tok| {
                std.debug.print("DOCTYPE TKN\n", .{});
                std.debug.print("   name:{s}\n", .{tok.name.items});
                std.debug.print("   public_ident : {s}\n", .{tok.public_ident.items});
                std.debug.print("   system_ident : {s}\n", .{tok.system_ident.items});
                std.debug.print("   force_quirks : {}\n", .{tok.force_quirks});
            },
            .Tag => |tok| {
                if (tok.type == .StartTag) {
                    std.debug.print("StartTag TKN\n", .{});
                    std.debug.print("   tag_name : {s}\n", .{tok.tag_name.items});
                    std.debug.print("   self_closing : {}\n", .{tok.self_closing});
                } else {
                    std.debug.print("EndTag TKN\n", .{});
                    std.debug.print("   tag_name : {s}\n", .{tok.tag_name.items});
                    std.debug.print("   self_closing : {}\n", .{tok.self_closing});
                }
            },
            .Comment => |tok| {
                std.debug.print("Comment TKN\n", .{});
                std.debug.print("   data: {s}\n", .{tok.data.items});
            },
            .Character => |tok| {
                std.debug.print("Character TKN\n", .{});
                std.debug.print("   data: {s}\n", .{tok.data.items});
            },
            .ReplacementCharacter => std.debug.print("EOF TKN\n", .{}),
            .EndOfFile => std.debug.print("EOF TKN\n", .{}),
        }
    }
};

pub const TokenHandler = struct {
    allocator: std.mem.Allocator,
    token_ref_list: std.ArrayList(*Token),
    token_queue: std.ArrayList(*Token),
    last_start_tag: ?*Token,

    pub fn init(allocator: std.mem.Allocator) !TokenHandler {
        // #TODO: optimize the size of the "Token List" that best represents the how we should keep on hand,
        // maybe move emit to this struct and we can dealloc from emit ???
        const token_ref_list = try std.ArrayList(*Token).initCapacity(allocator, 30);
        const token_queue = try std.ArrayList(*Token).initCapacity(allocator, 30);
        return .{
            .allocator = allocator,
            .token_ref_list = token_ref_list,
            .token_queue = token_queue,
            .last_start_tag = null,
        };
    }
    pub fn deinit(self: *TokenHandler) void {
        for (self.token_ref_list.items) |tok| {
            if (tok.* == .Tag) {
                tok.Tag.tag_name.deinit(self.allocator);
                tok.Tag.attributes.deinit();
            }
            if (tok.* == .DOCTYPE) {
                tok.DOCTYPE.name.deinit(self.allocator);
                tok.DOCTYPE.public_ident.deinit(self.allocator);
                tok.DOCTYPE.system_ident.deinit(self.allocator);
            }
            if (tok.* == .Comment) {
                tok.Comment.data.deinit(self.allocator);
            }
            if (tok.* == .Character) {
                tok.Character.data.deinit(self.allocator);
            }

            self.allocator.destroy(tok);
        }
        self.token_ref_list.deinit(self.allocator);
        self.token_queue.deinit(self.allocator);
    }
    pub fn createDOCTYPEToken(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        const name = try std.ArrayList(u8).initCapacity(self.allocator, 1);
        const public_ident = try std.ArrayList(u8).initCapacity(self.allocator, 1);
        const system_ident = try std.ArrayList(u8).initCapacity(self.allocator, 1);

        tok.* = .{ .DOCTYPE = .{ .name = name, .public_ident = public_ident, .system_ident = system_ident, .force_quirks = false } };
        try self.token_ref_list.append(self.allocator, tok);
        return tok;
    }
    pub fn createStartTag(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        const tag_name = try std.ArrayList(u8).initCapacity(self.allocator, 1);
        tok.* = .{ .Tag = .{
            .type = .StartTag,
            .tag_name = tag_name,
            .self_closing = false,
            .attributes = try AttributeList.init(self.allocator),
        } };
        try self.token_ref_list.append(self.allocator, tok);
        return tok;
    }

    pub fn createEndTag(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        const tag_name = try std.ArrayList(u8).initCapacity(self.allocator, 1);
        tok.* = .{ .Tag = .{
            .type = .EndTag,
            .tag_name = tag_name,
            .self_closing = false,
            .attributes = try AttributeList.init(self.allocator),
        } };
        try self.token_ref_list.append(self.allocator, tok);
        return tok;
    }

    pub fn createComment(self: *TokenHandler, data: u8) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .Comment = .{ .data = try std.ArrayList(u8).initCapacity(self.allocator, 32) } };
        try self.token_ref_list.append(self.allocator, tok);
        if (data != 0) try tok.Comment.data.append(self.allocator, data);
        return tok;
    }
    pub fn createCharacter(self: *TokenHandler, data: u8) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .Character = .{ .data = try std.ArrayList(u8).initCapacity(self.allocator, 32) } };
        try self.token_ref_list.append(self.allocator, tok);
        if (data != 0) try tok.Character.data.append(self.allocator, data);
        return tok;
    }
    pub fn createReplacement(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .ReplacementCharacter = {} };
        try self.token_ref_list.append(self.allocator, tok);
        return tok;
    }
    pub fn createEOF(self: *TokenHandler) !*Token {
        const tok: *Token = try self.allocator.create(Token);
        tok.* = .{ .EndOfFile = {} };
        try self.token_ref_list.append(self.allocator, tok);
        return tok;
    }

    pub fn enqueue(self: *TokenHandler, new: *Token) !void {
        if (new.* == .Character) {
            if (self.token_queue.getLastOrNull()) |last| {
                if (last.* == .Character) {
                    try last.Character.data.appendSlice(self.allocator, new.Character.data.items);
                    for (self.token_ref_list.items, 0..) |tkn, i| {
                        if (tkn == new) {
                            new.Character.data.deinit(self.allocator);
                            self.allocator.destroy(new);
                            _ = self.token_ref_list.swapRemove(i);
                        }
                    }
                    return;
                }
            }
        }
        if (new.* == .Tag and new.Tag.type == .StartTag) {
            self.last_start_tag = new;
        }
 
        try self.token_queue.append(self.allocator, new);
    }
    pub fn dequeue(self: *TokenHandler) !*Token {
        if (self.token_queue.items.len == 0) return tokErrors.NoElementsInQueue;
        const tok = self.token_queue.items[0];
        if (tok.* == .EndOfFile) return tok; // this make sure that the there is always a EOF once lexing is complete
        _ = self.token_queue.orderedRemove(0);
        return tok;
    }
    pub fn getQueueLen(self: *TokenHandler) usize {
        return self.token_queue.items.len;
    }
    pub fn isAppropriateEndTagToken(self: *TokenHandler, token: *Token) bool {
        if (self.last_start_tag) |last| {
            if (token.* == .Tag and token.Tag.type == .EndTag and std.mem.eql(u8, token.Tag.tag_name.items, last.Tag.tag_name.items)) {
                return true;
            }
        }
        return false;
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
    pub fn toStringHashMap(self: *AttributeList, allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
        const attributes = std.StringHashMap([]const u8).init(allocator);
        for (self.list.items) |attr| {
            const attr_name = if (attr.name.items) |name| name else "__NO_ATTRIBUTE_NAME__";
            const attr_value = if (attr.name.items) |name| name else "__NO_ATTRIBUTE_VALUE__";
            try attributes.put(attr_name, attr_value);
        }
        return attributes;
    }
};

const TokenQueue = struct {
    queue: std.ArrayList(*Token),
    len: usize,
};
