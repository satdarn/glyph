const std = @import("std");
pub const Node = struct {
    parent: ?*Node,
    children: std.ArrayList(*Node),
    allocator: std.mem.Allocator,
    data: NodeData,

    pub const NodeData = union(enum) {
        Document: void,
        Element: struct {
            tag_name: []const u8,
            attributes: std.StringHashMap([]const u8),
            self_closing: bool,
        },
        Text: struct {
            content: []const u8,
        },
        Comment: struct {
            content: []const u8,
        },
        DOCTYPE: struct {
            name: []const u8,
            public_id: ?[]const u8,
            system_id: ?[]const u8,
            force_quirks: bool,
        },
    };

    pub fn createDocument(allocator: std.mem.Allocator) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .parent = null,
            .children = try std.ArrayList(*Node).initCapacity(allocator, 5),
            .allocator = allocator,
            .data = .{ .Document = {} },
        };
        return node;
    }

    pub fn createElement(allocator: std.mem.Allocator, tag_name: []const u8) !*Node {
        const node = try allocator.create(Node);
        const name_copy = try allocator.dupe(tag_name);

        node.* = .{ .parent = null, .children = try std.ArrayList(*Node).initCapacity(allocator, 5), .allocator = allocator, .data = .{ .Element = .{
            .tag_name = name_copy,
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .self_closing = false,
        } } };
        return node;
    }
    pub fn createText(allocator: std.mem.Allocator, text: []const u8) !*Node {
        const node = try allocator.create(Node);
        const text_copy = try allocator.dupe(u8, text);

        node.* = .{
            .parent = null,
            .children = try std.ArrayList(*Node).initCapacity(allocator, 5),
            .allocator = allocator,
            .data = .{ .Text = .{ .content = text_copy } },
        };
        return node;
    }

    pub fn createComment(allocator: std.mem.Allocator, comment_text: []const u8) !*Node {
        const node = try allocator.create(Node);
        const text_copy = try allocator.dupe(u8, comment_text);

        node.* = .{
            .parent = null,
            .children = try std.ArrayList(*Node).initCapacity(allocator, 5),
            .allocator = allocator,
            .data = .{ .Comment = .{ .content = text_copy } },
        };
        return node;
    }

    pub fn createDOCTYPE(allocator: std.mem.Allocator, name: []const u8, public_id: ?[]const u8, system_id: ?[]const u8, force_quirks: bool) !*Node {
        const node = try allocator.create(Node);
        const name_copy = try allocator.dupe(u8, name);

        const pub_id = if (public_id) |id| try allocator.dupe(u8, id) else null;
        const sys_id = if (system_id) |id| try allocator.dupe(u8, id) else null;

        node.* = .{
            .parent = null,
            .children = try std.ArrayList(*Node).initCapacity(allocator, 5),
            .allocator = allocator,
            .data = .{
                .DOCTYPE = .{
                    .name = name_copy,
                    .public_id = pub_id,
                    .system_id = sys_id,
                    .force_quirks = force_quirks,
                },
            },
        };
        return node;
    }
    pub fn deinit(self: *Node) void {
        const allocator: std.mem.Allocator = self.allocator;
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit(allocator);
        switch (self.data) {
            .Document => {},
            .Element => {
                allocator.free(self.data.Element.tag_name);
                self.data.Element.attributes.deinit();
            },
            .Text => {
                allocator.free(self.data.Text.content);
            },
            .Comment => {
                allocator.free(self.data.Comment.content);
            },
            .DOCTYPE => {
                allocator.free(self.data.DOCTYPE.name);
                if (self.data.DOCTYPE.system_id) |sys_id| allocator.free(sys_id);
                if (self.data.DOCTYPE.public_id) |pub_id| allocator.free(pub_id);
            },
        }
        allocator.destroy(self);
    }
};
