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
        self.nextToken();
        sw: switch (insertion_mode) {
            .Initial => {
                if (self.current_token.* == .Comment) {
                    try self.insertComment(self.current_token, self.document);
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
                if (self.current_token.* == .DOCTYPE) {
                    // Parse error
                    self.nextToken();
                    continue :sw .BeforeHtml;
                }
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, self.document);
                    self.nextToken();
                    continue :sw .BeforeHtml;
                }
                if (self.isCurrentTokenStartTag()) {
                    if (self.currentTokenNameIs("html")) {
                        try self.insertForgienElement(self.current_token, "html", false);
                        self.nextToken();
                        continue :sw .BeforeHead;
                    }
                }
                if (self.isCurrentTokenEndTag()) {
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "head", "body", "html", "br" })) {
                        const html_tag_element = try Node.createElement(self.allocator, "html");
                        try self.open_elements.append(self.allocator, html_tag_element);
                        try self.document.insert(self.allocator, html_tag_element);
                        continue :sw .BeforeHead;
                    } else {
                        // Parse error
                        self.nextToken();
                        continue :sw .BeforeHtml;
                    }
                } else {
                    const html_tag_element = try Node.createElement(self.allocator, "html");
                    try self.open_elements.append(self.allocator, html_tag_element);
                    try self.document.insert(self.allocator, html_tag_element);
                    continue :sw .BeforeHead;
                }
            },
            .BeforeHead => {
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, null);
                    self.nextToken();
                    continue :sw .BeforeHead;
                }
                if (self.current_token.* == .DOCTYPE) {
                    self.nextToken();
                    continue :sw .BeforeHead;
                }
                if (self.isCurrentTokenStartTag()) {
                    if (self.currentTokenNameIs("html")) {
                        // TODO: Process the token using the rules for the "in body" insertion mode.
                        // for now just drop the tag
                        self.nextToken();
                        continue :sw .BeforeHead;
                    }
                    if (self.currentTokenNameIs("head")) {
                        try self.insertHtmlElement(self.current_token);
                        continue :sw .InHead;
                    }
                }
                if (self.isCurrentTokenEndTag()) {
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "head", "body", "html", "br" })) {
                        const head_tag_element = try Node.createElement(self.allocator, "head");
                        try self.open_elements.append(self.allocator, head_tag_element);
                        try self.document.insert(self.allocator, head_tag_element);
                        continue :sw .InHead;
                    } else {
                        self.nextToken();
                        continue :sw .BeforeHead;
                    }
                } else {
                    const head_tag_element = try Node.createElement(self.allocator, "head");
                    try self.getAppropriatePlace(null).insert(self.allocator, head_tag_element);
                    try self.open_elements.append(self.allocator, head_tag_element);
                    continue :sw .InHead;
                }
            },
            .InHead => {
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, null);
                    self.nextToken();
                    continue :sw .InHead;
                }
                if (self.current_token.* == .DOCTYPE) {
                    // Parse Error
                    self.nextToken();
                    continue :sw .InHead;
                }
                if (self.isCurrentTokenStartTag()) {
                    if (self.currentTokenNameIs("html")) {
                        // Process the token using the rules for the "in body" insertion mode.
                    }
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "base", "basefont", "link", "meta" })) {
                        try self.insertHtmlElement(self.current_token);
                        _ = self.open_elements.pop();
                    }
                    if (self.currentTokenNameIs("title")) {
                        // Follow the generic RCDATA element parsing algorithm.
                        try self.genericRCDATAElementParsing(self.current_token, .InHead);
                        self.nextToken();
                        continue :sw .Text;
                    }
                    self.nextToken();
                    continue :sw .InHead;
                }
                if (self.isCurrentTokenEndTag()) {
                    if (self.currentTokenNameIs("head")) {
                        _ = self.open_elements.pop();
                        self.nextToken();
                        continue :sw .AfterHead;
                    }
                }
            },
            .InHeadNoscript => {},
            .AfterHead => {
                if (self.current_token.* == .Comment) {
                    try self.getAppropriatePlace(null).insert(self.allocator, try Node.createComment(self.allocator, self.current_token.Comment.data.items));
                    self.nextToken();
                    continue :sw .AfterHead;
                }
                if (self.current_token.* == .DOCTYPE) {
                    // Parse error
                    self.nextToken();
                    continue :sw .AfterHead;
                }
                if (self.isCurrentTokenStartTag()) {
                    if (self.currentTokenNameIs("html")) {
                        // Process the token using the rules for the "in body" insertion mode.
                    }
                    if (self.currentTokenNameIs("body")) {
                        try self.insertHtmlElement(self.current_token);
                        // set the frameset-ok flag to "not ok".
                        self.nextToken();
                        continue :sw .InBody;
                    }
                    if (self.currentTokenNameIs("frameset")) {
                        try self.insertHtmlElement(self.current_token);
                        self.nextToken();
                        continue :sw .InFrameset;
                    }
                }
            },
            .InBody => {
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, null);
                    self.nextToken();
                    continue :sw .InBody;
                }
                if (self.current_token.* == .DOCTYPE) {
                    // Parse Error
                    self.nextToken();
                    continue :sw .InBody;
                }
                if (self.isCurrentTokenStartTag()) {
                    if (self.currentTokenNameIs("html")) {
                        // Parse Error
                        // TODO: If there is a template element on the stack of open elements, then ignore the token.
                        // Otherwise, for each attribute on the token, check to see if the attribute is already present on the top element of the stack of open elements. If it is not, add the attribute and its corresponding value to that element.
                        // for now drop the token
                        self.nextToken();
                        continue :sw .InBody;
                    }
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "template", "title" })) {
                        // TODO: Process the token using the rules for the "in head" insertion mode.
                    }
                    if (self.currentTokenNameIs("body") or self.currentTokenNameIs("frameset")) {
                        // Parse Error
                        self.nextToken();
                        continue :sw .InBody;
                    }
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "h1", "h2", "h3", "h4", "h5", "h6" })) {
                        // If the stack of open elements has a p element in button scope, then close a p element.
                        // If the current node is an HTML element whose tag name is one of "h1", "h2", "h3", "h4", "h5", or "h6", then this is a parse error;
                        // pop the current node off the stack of open elements.
                        // Insert an HTML element for the token.
                        try self.insertHtmlElement(self.current_token);
                        self.nextToken();
                        continue :sw .InBody;
                    }
                }
                if (self.isCurrentTokenEndTag()) {
                    if (self.currentTokenNameIs("body")) {
                        self.nextToken();
                        continue :sw .AfterBody;
                    }
                }
            },
            .Text => {
                if (self.current_token.* == .Character) {
                    try self.insertCharacter(self.current_token.Character.data.items);
                    self.nextToken();
                    continue :sw .Text;
                }
                if (self.isCurrentTokenEndTag()) {
                    _ = self.open_elements.pop();
                    self.nextToken();
                    continue :sw self.original_insertion_mode;
                }
            },
            .InTable => {},
            .InTableText => {},
            .InCaption => {},
            .InColumnGroup => {},
            .InTableBody => {},
            .InRow => {},
            .InCell => {},
            .InTemplate => {},
            .AfterBody => {
                if (self.isCurrentTokenEndTag()) {
                    if (self.currentTokenNameIs("html")) {
                        self.nextToken();
                        continue :sw .AfterAfterBody;
                    }
                }
            },
            .InFrameset => {},
            .AfterFrameset => {},
            .AfterAfterBody => {
                if (self.current_token.* == .EndOfFile) {
                    break :sw;
                }
            },
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
    fn insertCharacter(self: *HtmlParser, data: []const u8) !void {
        const adjusted_insertion_location: *Node = self.getAppropriatePlace(null);
        if (adjusted_insertion_location.data == .Document) return;

        if (adjusted_insertion_location.children.getLastOrNull()) |last_child| {
            if (last_child.data == .Text) {
                try last_child.data.Text.content.appendSlice(self.allocator, data);
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
    fn insertComment(self: *HtmlParser, token: *Token, override_target: ?*Node) !void {
        const adjusted_insertion_location: *Node = self.getAppropriatePlace(override_target);
        const comment: *Node = try Node.createComment(self.allocator, token.Comment.data.items);
        try adjusted_insertion_location.insert(self.allocator, comment);
    }
    fn genericRawTextElementParsing(self: *HtmlParser, token: *Token, insertion_mode: InsertionMode) !void {
        try self.insertHtmlElement(token);
        self.lexer.current_state = .RAWTEXT;
        self.original_insertion_mode = insertion_mode;
    }
    fn genericRCDATAElementParsing(self: *HtmlParser, token: *Token, insertion_mode: InsertionMode) !void {
        try self.insertHtmlElement(token);
        self.lexer.current_state = .RCDATA;
        self.original_insertion_mode = insertion_mode;
    }
    fn isCurrentTokenStartTag(self: *HtmlParser) bool {
        return (self.current_token.* == .Tag and self.current_token.Tag.type == .StartTag);
    }
    fn isCurrentTokenEndTag(self: *HtmlParser) bool {
        return (self.current_token.* == .Tag and self.current_token.Tag.type == .EndTag);
    }
    fn isCurrentTokenComment(self: *HtmlParser) bool {
        return (self.current_token.* == .Comment);
    }
    fn currentTokenNameIs(self: *HtmlParser, name: []const u8) bool {
        return (std.mem.eql(u8, name, self.current_token.Tag.tag_name.items));
    }
    fn currentTokenNameIsOneOf(self: *HtmlParser, names: []const []const u8) bool {
        for (names) |name| {
            if (self.currentTokenNameIs(name)) {
                return true;
            }
        }
        return false;
    }
};
