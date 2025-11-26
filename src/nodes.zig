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
            content: std.ArrayList(u8),
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
        const name_copy = try allocator.dupe(u8, tag_name);

        node.* = .{ .parent = null, .children = try std.ArrayList(*Node).initCapacity(allocator, 5), .allocator = allocator, .data = .{ .Element = .{
            .tag_name = name_copy,
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .self_closing = false,
        } } };
        return node;
    }
    pub fn createText(allocator: std.mem.Allocator, text: []const u8) !*Node {
        const node = try allocator.create(Node);
        var content = try std.ArrayList(u8).initCapacity(allocator, 10);
        try content.appendSlice(allocator, text);
        node.* = .{
            .parent = null,
            .children = try std.ArrayList(*Node).initCapacity(allocator, 5),
            .allocator = allocator,
            .data = .{ .Text = .{ .content = content } },
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
                self.data.Text.content.deinit(self.allocator);
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

    pub fn insert(self: *Node, allocator: std.mem.Allocator, child: *Node) !void {
        try self.children.append(allocator, child);
        child.parent = self;
    }

    pub fn printTreeSimple(node: *Node) void {
        printTreeSimpleRecursive(node, 0);
    }

    fn printTreeSimpleRecursive(node: *Node, depth: usize) void {
        // Print indentation
        var i: usize = 0;
        while (i < depth) : (i += 1) {
            std.debug.print("  ", .{});
        }

        // Print node content
        switch (node.data) {
            .Document => {
                std.debug.print("Document\n", .{});
            },
            .Element => |element| {
                if (element.self_closing) {
                    std.debug.print("<{s}/>", .{element.tag_name});
                } else {
                    std.debug.print("<{s}>", .{element.tag_name});
                }

                // Print attributes
                var attr_iter = element.attributes.iterator();
                while (attr_iter.next()) |entry| {
                    std.debug.print(" {s}=\"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
                }
                std.debug.print("\n", .{});
            },
            .Text => |text| {
                std.debug.print("\"{s}\"\n", .{text.content.items});
            },
            .Comment => |comment| {
                std.debug.print("<!-- {s} -->\n", .{comment.content});
            },
            .DOCTYPE => |doctype| {
                std.debug.print("<!DOCTYPE {s}", .{doctype.name});
                if (doctype.public_id) |pub_id| {
                    std.debug.print(" PUBLIC \"{s}\"", .{pub_id});
                }
                if (doctype.system_id) |sys_id| {
                    if (doctype.public_id == null) {
                        std.debug.print(" SYSTEM", .{});
                    }
                    std.debug.print(" \"{s}\"", .{sys_id});
                }
                std.debug.print(">\n", .{});
            },
        }

        // Print children
        for (node.children.items) |child| {
            printTreeSimpleRecursive(child, depth + 1);
        }
    }
};
