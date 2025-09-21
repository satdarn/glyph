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
        attributes: []Attributes,
    },
    EndTag: struct {
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

    pub fn createDOCTYPEToken(name: []const u8, publicIdent: []const u8, systemIdent: []const u8, forceQuirks: bool) Token {
        return .{ .DOCTYPE = .{ .name = name, .publicIdent = publicIdent, .systemIdent = systemIdent, .forceQuirks = forceQuirks } };
    }
    pub fn createStartTag(tagName: u8, selfClosing: bool) Token {
        return .{ .StartTag = .{
            .tagName = &[_]u8{tagName},
            .selfClosing = selfClosing,
            .attributes = &[_]Attributes{},
        } };
    }
    pub fn createEndTag(tagName: u8, selfClosing: bool) Token {
        return .{ .EndTag = .{
            .tagName = &[_]u8{tagName},
            .selfClosing = selfClosing,
            .attributes = &[_]Attributes{},
        } };
    }
    pub fn createComment(data: u8) Token {
        return .{ .Comment = .{ .data = &[_]u8{data} } };
    }
    pub fn createCharacter(data: u8) Token {
        return .{ .Character = .{ .data = &[_]u8{data} } };
    }
    pub fn createEOF() Token {
        return .{.EndOfFile = {}};
    }
    pub fn emitToken(token: Token) void {
        switch (token) {
            .DOCTYPE => |tok| {
                std.debug.print("DOCTYPE TKN\n", .{});
                std.debug.print("   name:{s}\n", .{tok.name});
                std.debug.print("   publicIdent : {s}\n", .{tok.publicIdent});
                std.debug.print("   systemIdent : {s}\n", .{tok.systemIdent});
                std.debug.print("   forceQuirks : {b}\n", .{tok.forceQuirks});
            },
            .StartTag => |tok| {
                std.debug.print("StartTag TKN\n", .{});
                std.debug.print("   tagName : {s}\n", .{tok.tagName});
                std.debug.print("   selfClosing : {b}\n", .{tok.selfClosing});
                std.debug.print("   selfClosing : {b}\n", .{tok.selfClosing});
            },
            .EndTag => |tok| {
                std.debug.print("EndTag TKN\n", .{});
                std.debug.print("   tagName : {s}\n", .{tok.tagName});
                std.debug.print("   selfClosing : {b}\n", .{tok.selfClosing});
                std.debug.print("   selfClosing : {b}\n", .{tok.selfClosing});
            },
            .Comment => |tok| {
                std.debug.print("Comment TKN\n", .{});
                std.debug.print("   data: {s}\n", .{tok.data});
            },
            .Character => |tok| {
                std.debug.print("Character TKN\n", .{});
                std.debug.print("   data: {s}\n", .{tok.data});
            },
            .EndOfFile => std.debug.print("EOF TKN\n", .{})
        }
    }
};

pub const Attributes = struct {
    name: []const u8,
    value: []const u8,
};
