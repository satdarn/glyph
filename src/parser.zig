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
    current_token: *Token,
    document: *Node,
    open_elements: std.ArrayList(*Node),
    foster_parenting: bool,
    original_insertion_mode: InsertionMode = .Initial,
    pub fn init(allocator: std.mem.Allocator, path_to_html_file: []const u8) !HtmlParser {
        const lexer = try HtmlLexer.init(allocator, path_to_html_file);
        const token: *Token = undefined;
        const document: *Node = try Node.createDocument(allocator);
        const open_elements: std.ArrayList(*Node) = try std.ArrayList(*Node).initCapacity(allocator, 15);
        return .{ .lexer = lexer, .allocator = allocator, .current_token = token, .document = document, .open_elements = open_elements, .foster_parenting = false };
    }
    pub fn deinit(self: *HtmlParser) void {
        self.lexer.deinit();
        self.document.deinit();
        self.open_elements.deinit(self.allocator);
    }
    pub fn getTree(self: *HtmlParser) !void {
        self.lexer.verbose = true;
        const insertion_mode: InsertionMode = .Initial;
        // var head_element_pointer: ?*Node = null;
        sw: switch (insertion_mode) {
            .Initial => {
                if (self.current_token.* == .Comment) {
                    try self.document.insert(self.allocator, try Node.createComment(self.allocator, self.current_token.Comment.data.items));
                    self.nextToken();
                    continue :sw .Initial;
                }
                if (self.current_token.* == .DOCTYPE) {
                    try self.document.insert(self.allocator, try Node.createDOCTYPE(self.allocator, self.current_token.DOCTYPE.name.items, null, null, false));
                    self.nextToken();
                    continue :sw .BeforeHtml;
                } else {
                    continue :sw .BeforeHtml;
                }
            },
            .BeforeHtml => {
                if (self.current_token.* == .Comment) {
                    try self.document.insert(self.allocator, try Node.createComment(self.allocator, self.current_token.Comment.data.items));
                    self.nextToken();
                    continue :sw .BeforeHtml;
                }
                if (self.current_token.* == .Tag and self.current_token.Tag.type == .StartTag and std.mem.eql(u8, self.current_token.Tag.tag_name.items, "html")) {
                    const html_tag_element = try Node.createElement(self.allocator, self.current_token.Tag.tag_name.items);
                    try self.open_elements.append(self.allocator, html_tag_element);
                    try self.document.insert(self.allocator, html_tag_element);
                    self.nextToken();
                    continue :sw .BeforeHead;
                } else {
                    const html_tag_element = try Node.createElement(self.allocator, "html");
                    try self.open_elements.append(self.allocator, html_tag_element);
                    try self.document.insert(self.allocator, html_tag_element);
                    continue :sw .BeforeHead;
                }
            },
            .BeforeHead => {
                if (self.current_token.* == .Comment) {
                    try self.getAppropriatePlace(null).insert(self.allocator, try Node.createComment(self.allocator, self.current_token.Comment.data.items));
                    self.nextToken();
                    continue :sw .BeforeHead;
                }
                if (self.current_token.* == .Tag and self.current_token.Tag.type == .StartTag and std.mem.eql(u8, self.current_token.Tag.tag_name.items, "head")) {
                    const head_tag_element = try Node.createElement(self.allocator, self.current_token.Tag.tag_name.items);
                    try self.getAppropriatePlace(null).insert(self.allocator, head_tag_element);
                    try self.open_elements.append(self.allocator, head_tag_element);
                    self.nextToken();
                    continue :sw .InHead;
                } else {
                    const head_tag_element = try Node.createElement(self.allocator, "head");
                    try self.getAppropriatePlace(null).insert(self.allocator, head_tag_element);
                    try self.open_elements.append(self.allocator, head_tag_element);
                    continue :sw .InHead;
                }
            },
            .InHead => {
                if (self.current_token.* == .Comment) {
                    try self.getAppropriatePlace(null).insert(self.allocator, try Node.createComment(self.allocator, self.current_token.Comment.data.items));
                    self.nextToken();
                    continue :sw .InHead;
                }
                if (self.current_token.* == .Tag and self.current_token.Tag.type == .StartTag and std.mem.eql(u8, self.current_token.Tag.tag_name.items, "meta")) {
                    try self.insertHtmlElement(self.current_token);
                }
            },
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
        self.document.printTreeSimple();
    }
    fn nextToken(self: *HtmlParser) void {
        self.current_token = self.lexer.nextToken() catch return;
    }
    
    fn getAppropriatePlace(self: *HtmlParser, override_target: ?*Node) *Node {
        const target: ?*Node = if (override_target) |override| override else self.open_elements.getLastOrNull();
        if (self.foster_parenting) {
            // 13.2.6.1 Creating and inserting nodes
        }
        if (target) |targ| {
            return targ;
        }
        return self.document;
    }

    fn insertCharacter(self: *HtmlParser, data: []const u8) void {
        const adjusted_insertion_location: *Node = self.getAppropriatePlace(null);
        if (adjusted_insertion_location.data.* == .Document) return;

        if (adjusted_insertion_location.children.getLastOrNull()) |last_child| {
            if (last_child.data.* == .Text) {
                last_child.data.Text.content.appendSlice(self.allocator, data);
                return;
            }
        }
        try adjusted_insertion_location.insert(self.allocator, try Node.createText(self.allocator, data));
    }

    fn insertHtmlElement(self: *HtmlParser, token: *Token) !void {
        try self.insertForgienElement(token, "html", false);
    }

    fn insertForgienElement(self: *HtmlParser, token: *Token, namespace: []const u8, only_add_to_element_stack: bool) !void {
        // namespace is not used now
        _ = namespace[0];
        const adjusted_insertion_location: *Node = self.getAppropriatePlace(null);
        const element = try Node.createElement(self.allocator, token.Tag.tag_name.items);
        if (!only_add_to_element_stack) {
            try adjusted_insertion_location.insert(self.allocator, element);
        }
        try self.open_elements.append(self.allocator, element);
    }
};
