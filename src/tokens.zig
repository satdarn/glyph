const std = @import("std");

pub const Token = union(enum) {
    DOCTYPE: struct {
        name: []const u8,
        publicIdent: []const u8,
        systemIdent: []const u8,
        forceQuirks: bool,
    },
    StartTag: struct {
        tagName: []const u8,
        selfClosing: bool,
        attributes: std.ArrayList(Attributes),
    },
    EndTag: struct {
        tagName: []const u8,
        selfClosing: bool,
        attributes: std.ArrayList(Attributes),
    },
    Comment: struct {
        data: []const u8,
    },
    Character: struct {
        data: []const u8,
    },
    EndOfFile,

    pub fn createDOCTYPEToken(name: []const u8, publicIdent: []const u8, systemIdent: []const u8, forceQuirks: bool) Token {
        return .{ .DOCTYPE = .{ .name = name, .publicIdent = publicIdent, .systemIdent = systemIdent, .forceQuirks = forceQuirks } };
    }
    pub fn createStartTag(tagName: []const u8, selfClosing: bool, attributes: std.ArrayList(Attributes)) Token {
        return .{ .StartTag = .{ .tagName = tagName, .selfClosing = selfClosing, .attributes = attributes } };
    }
    pub fn createEndTag(tagName: []const u8, selfClosing: bool, attributes: std.ArrayList(Attributes)) Token {
        return .{ .EndTag = .{ .tagName = tagName, .selfClosing = selfClosing, .attributes = attributes } };
    }
    pub fn createComment(data: []const u8) Token {
        return .{ .Comment = .{ .data = data } };
    }
    pub fn createCharacter(data: []const u8) Token {
        return .{ .Character = .{ .data = data } };
    }
    pub fn emitToken(token: Token) void {
        switch (token) {
            .DOCTYPE => |tok| {
                std.debug.print("DOCTYPE TKN", .{});
                std.debug.print("   name:{s}", .{tok.name});
                std.debug.print("   publicIdent : {s}", .{tok.publicIdent});
                std.debug.print("   systemIdent : {s}", .{tok.systemIdent});
                std.debug.print("   forceQuirks : {b}", .{tok.forceQuirks});
            },
            .StartTag => |tok| {
                std.debug.print("StartTag TKN", .{});
                std.debug.print("   tagName : {s}", .{tok.tagName});
                std.debug.print("   selfClosing : {b}", .{tok.selfClosing});
                std.debug.print("   selfClosing : {b}", .{tok.selfClosing});

            },
            .EndTag => |tok| {
                std.debug.print("EndTag TKN", .{});
                std.debug.print("   tagName : {s}", .{tok.tagName});
                std.debug.print("   selfClosing : {b}", .{tok.selfClosing});
                std.debug.print("   selfClosing : {b}", .{tok.selfClosing});
            },
            .Comment => |tok| {
                std.debug.print("Comment TKN", .{});
                std.debug.print("   data: {s}", .{tok.data});
            },
            .Comment => |tok| {
                std.debug.print("Comment TKN", .{});
                std.debug.print("   data: {s}", .{tok.data});
            },
        }
    }
};

pub const Attributes = struct {
    name: []const u8,
    value: []const u8,
};
