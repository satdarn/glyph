const std = @import("std");

pub const Node = struct {
    parent: ?*Node,
    children: std.ArrayList(*Node),
    allocator: std.mem.Allocator,
    data: NodeData,

    pub const NodeData = union(enum) {
        Document: void,
        Element: struct {
            tag_name : []const u8,
            attributes: std.StringHashMap([]const u8),
            self_closing: bool,
        },
        Text: struct {
            content : []const u8, 
        },
        Comment: struct {
            content : []const u8, 
        },
        DOCTYPE: struct {
            name: []const u8,
            public_id: ?[]const u8,
            system_id: ?[]const u8,
            force_quirks: bool,
        },

    };
}; 
