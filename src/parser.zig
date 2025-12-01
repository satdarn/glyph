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
    scripting_flag: bool,
    original_insertion_mode: InsertionMode = .Initial,
    pub fn init(allocator: std.mem.Allocator, path_to_html_file: []const u8) !HtmlParser {
        const lexer = try HtmlLexer.init(allocator, path_to_html_file);
        const token: *Token = undefined;
        const document: *Node = try Node.createDocument(allocator);
        const open_elements: std.ArrayList(*Node) = try std.ArrayList(*Node).initCapacity(allocator, 15);
        return .{ .lexer = lexer, .allocator = allocator, .current_token = token, .document = document, .open_elements = open_elements, .foster_parenting = false, .scripting_flag = false };
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
                // A comment token
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, self.document);
                    self.nextToken();
                    continue :sw .Initial;
                }
                // A DOCTYPE token
                if (self.current_token.* == .DOCTYPE) {
                    try self.document.insert(self.allocator, try Node.createDOCTYPE(self.allocator, self.current_token.DOCTYPE.name.items, null, null, false));
                    self.nextToken();
                    continue :sw .BeforeHtml;
                }
                // Anything else
                else {
                    continue :sw .BeforeHtml;
                }
            },
            .BeforeHtml => {
                // A DOCTYPE token
                if (self.current_token.* == .DOCTYPE) {
                    // Parse error
                    self.nextToken();
                    continue :sw .BeforeHtml;
                }
                // A comment token
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, self.document);
                    self.nextToken();
                    continue :sw .BeforeHtml;
                }
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {
                        try self.insertForgienElement(self.current_token, "html", false);
                        self.nextToken();
                        continue :sw .BeforeHead;
                    }
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is one of: "head", "body", "html", "br"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "head", "body", "html", "br" })) {
                        const html_tag_element = try Node.createElement(self.allocator, "html");
                        try self.open_elements.append(self.allocator, html_tag_element);
                        try self.document.insert(self.allocator, html_tag_element);
                        continue :sw .BeforeHead;
                    }
                    // Any other end tag
                    else {
                        // Parse error
                        self.nextToken();
                        continue :sw .BeforeHtml;
                    }
                }
                // Anything else
                else {
                    const html_tag_element = try Node.createElement(self.allocator, "html");
                    try self.open_elements.append(self.allocator, html_tag_element);
                    try self.document.insert(self.allocator, html_tag_element);
                    continue :sw .BeforeHead;
                }
            },
            .BeforeHead => {
                // A comment token
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, null);
                    self.nextToken();
                    continue :sw .BeforeHead;
                }
                // A DOCTYPE token
                if (self.current_token.* == .DOCTYPE) {
                    self.nextToken();
                    continue :sw .BeforeHead;
                }
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {
                        // TODO: Process the token using the rules for the "in body" insertion mode.
                        // for now just drop the tag
                        self.nextToken();
                        continue :sw .BeforeHead;
                    }
                    // A start tag whose tag name is "head"
                    if (self.currentTokenNameIs("head")) {
                        try self.insertHtmlElement(self.current_token);
                        continue :sw .InHead;
                    }
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is one of: "head", "body", "html", "br"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "head", "body", "html", "br" })) {
                        const head_tag_element = try Node.createElement(self.allocator, "head");
                        try self.open_elements.append(self.allocator, head_tag_element);
                        try self.document.insert(self.allocator, head_tag_element);
                        continue :sw .InHead;
                    }
                    // Any other end tag
                    else {
                        self.nextToken();
                        continue :sw .BeforeHead;
                    }
                }
                // Anything else
                else {
                    const head_tag_element = try Node.createElement(self.allocator, "head");
                    try self.getAppropriatePlace(null).insert(self.allocator, head_tag_element);
                    try self.open_elements.append(self.allocator, head_tag_element);
                    continue :sw .InHead;
                }
            },
            .InHead => {
                // A comment token
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, null);
                    self.nextToken();
                    continue :sw .InHead;
                }
                // A DOCTYPE token
                if (self.current_token.* == .DOCTYPE) {
                    // Parse Error
                    self.nextToken();
                    continue :sw .InHead;
                }

                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {
                        // Process the token using the rules for the "in body" insertion mode.
                    }
                    // A start tag whose tag name is one of: "base", "basefont", "bgsound", "link"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "base", "basefont", "link", "meta" })) {
                        try self.insertHtmlElement(self.current_token);
                        _ = self.open_elements.pop();
                    }
                    // A start tag whose tag name is "meta"
                    if (self.currentTokenNameIs("meta")) {
                        try self.insertHtmlElement(self.current_token);
                        _ = self.open_elements.pop();
                        // Acknowledge the token's self-closing flag, if it is set.
                        // If the active speculative HTML parser is null, then:
                        // If the element has a charset attribute, and getting an encoding from its value results in an encoding, 
                        // and the confidence is currently tentative, then change the encoding to the resulting encoding.
                        // Otherwise, if the element has an http-equiv attribute whose value is an ASCII case-insensitive match 
                        // for the string "Content-Type", and the element has a content attribute, 
                        // and applying the algorithm for extracting a character encoding from a 
                        // meta element to that attribute's value returns an encoding, 
                        // and the confidence is currently tentative, then change the encoding to the extracted encoding
                    }
                    // A start tag whose tag name is "title"
                    if (self.currentTokenNameIs("title")) {
                        // Follow the generic RCDATA element parsing algorithm.
                        try self.genericRCDATAElementParsing(self.current_token, .InHead);
                        self.nextToken();
                        continue :sw .Text;
                    }
                    // A start tag whose tag name is "noscript", if the scripting flag is enabled
                    if (self.currentTokenNameIs("noscript") and self.scripting_flag) {
                        try self.genericRCDATAElementParsing();
                        self.nextToken();
                        continue :sw .InHead;
                    }
                    // A start tag whose tag name is one of: "noframes", "style"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "noframes", "style" })) {
                        try self.genericRCDATAElementParsing();
                        self.nextToken();
                        continue :sw .InHead;
                    }
                    // A start tag whose tag name is "noscript", if the scripting flag is disabled
                    if (self.currentTokenNameIs("noscript") and !self.scripting_flag) {
                        try self.insertHtmlElement();
                        self.nextToken();
                        continue :sw .InHeadNoscript;
                    }
                    // A start tag whose tag name is "script"
                    if (self.currentTokenNameIs("script")) {
                        
                    }
                    // A start tag whose tag name is "template"
                    if (self.currentTokenNameIs("template")) {}
                    // A start tag whose tag name is "head"
                    if (self.currentTokenNameIs("head")) {}
                    self.nextToken();
                    continue :sw .InHead;
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "head"
                    if (self.currentTokenNameIs("head")) {
                        _ = self.open_elements.pop();
                        self.nextToken();
                        continue :sw .AfterHead;
                    }
                    // An end tag whose tag name is one of: "body", "html", "br"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "body", "html", "br" })) {}
                    // An end tag whose tag name is "template"
                    if (self.currentTokenNameIs("template")) {}
                    // Any other end tag
                }
                // Anything else
                else {
                    
                }
            },
            .InHeadNoscript => {
                // A DOCTYPE token
                // A comment token
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {}
                    // A start tag whose tag name is one of: "basefont", "bgsound", "link", "meta", "noframes", "style"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "basefont", "bgsound", "link", "meta", "noframes", "style" })) {}
                    // A start tag whose tag name is one of: "head", "noscript"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "head", "noscript" })) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "noscript"
                    if (self.currentTokenNameIs("noscript")) {}
                    // An end tag whose tag name is "br"
                    if (self.currentTokenNameIs("br")) {}
                    // Any other end tag
                    else {}
                }
                // Anything else
                else {}
            },
            .AfterHead => {
                // A comment token
                if (self.isCurrentTokenComment()) {
                    try self.getAppropriatePlace(null).insert(self.allocator, try Node.createComment(self.allocator, self.current_token.Comment.data.items));
                    self.nextToken();
                    continue :sw .AfterHead;
                }
                // A DOCTYPE token
                if (self.current_token.* == .DOCTYPE) {
                    // Parse error
                    self.nextToken();
                    continue :sw .AfterHead;
                }
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {
                        // Process the token using the rules for the "in body" insertion mode.
                    }
                    // A start tag whose tag name is "body"
                    if (self.currentTokenNameIs("body")) {
                        try self.insertHtmlElement(self.current_token);
                        // set the frameset-ok flag to "not ok".
                        self.nextToken();
                        continue :sw .InBody;
                    }
                    // A start tag whose tag name is "frameset"
                    if (self.currentTokenNameIs("frameset")) {
                        try self.insertHtmlElement(self.current_token);
                        self.nextToken();
                        continue :sw .InFrameset;
                    }
                    // A start tag whose tag name is one of: "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "template", "title"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "template", "title" })) {}
                    // A start tag whose tag name is "head"
                    if (self.currentTokenNameIs("head")) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "template"
                    if (self.currentTokenNameIs("template")) {}
                    // An end tag whose tag name is one of: "body", "html", "br"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "body", "html", "br" })) {}
                    // Any other end tag
                    else {}
                }
            },
            .InBody => {
                // Any other character token
                // A comment token
                if (self.isCurrentTokenComment()) {
                    try self.insertComment(self.current_token, null);
                    self.nextToken();
                    continue :sw .InBody;
                }
                // A DOCTYPE token
                if (self.current_token.* == .DOCTYPE) {
                    // Parse Error
                    self.nextToken();
                    continue :sw .InBody;
                }
                // An end-of-file token
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {
                        // Parse Error
                        // TODO: If there is a template element on the stack of open elements, then ignore the token.
                        // Otherwise, for each attribute on the token, check to see if the attribute is already present on the top element of the stack of open elements. If it is not, add the attribute and its corresponding value to that element.
                        // for now drop the token
                        self.nextToken();
                        continue :sw .InBody;
                    }
                    // A start tag whose tag name is one of: "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "template", "title"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "template", "title" })) {
                        // TODO: Process the token using the rules for the "in head" insertion mode.
                    }
                    // A start tag whose tag name is "body"
                    if (self.currentTokenNameIs("body") or self.currentTokenNameIs("frameset")) {
                        // Parse Error
                        self.nextToken();
                        continue :sw .InBody;
                    }
                    // A start tag whose tag name is "frameset"
                    if (self.currentTokenNameIs("frameset")) {}
                    // A start tag whose tag name is one of: "address", "article", "aside", "blockquote", "center", "details", "dialog", "dir", "div", "dl", "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "main", "menu", "nav", "ol", "p", "search", "section", "summary", "ul"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "address", "article", "aside", "blockquote", "center", "details", "dialog", "dir", "div", "dl", "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "main", "menu", "nav", "ol", "p", "search", "section", "summary", "ul" })) {}
                    // A start tag whose tag name is one of: "h1", "h2", "h3", "h4", "h5", "h6"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "h1", "h2", "h3", "h4", "h5", "h6" })) {
                        // If the stack of open elements has a p element in button scope, then close a p element.
                        // If the current node is an HTML element whose tag name is one of "h1", "h2", "h3", "h4", "h5", or "h6", then this is a parse error;
                        // pop the current node off the stack of open elements.
                        // Insert an HTML element for the token.
                        try self.insertHtmlElement(self.current_token);
                        self.nextToken();
                        continue :sw .InBody;
                    }
                    // A start tag whose tag name is one of: "pre", "listing"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "pre", "listing" })) {}
                    // A start tag whose tag name is "form"
                    if (self.currentTokenNameIs("form")) {}
                    // A start tag whose tag name is "li"
                    if (self.currentTokenNameIs("li")) {}
                    // A start tag whose tag name is one of: "dd", "dt"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "dd", "dt" })) {}
                    // A start tag whose tag name is "plaintext"
                    if (self.currentTokenNameIs("plaintext")) {}
                    // A start tag whose tag name is "button"
                    if (self.currentTokenNameIs("button")) {}
                    // A start tag whose tag name is "a"
                    if (self.currentTokenNameIs("a")) {}
                    // A start tag whose tag name is one of: "b", "big", "code", "em", "font", "i", "s", "small", "strike", "strong", "tt", "u"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "b", "big", "code", "em", "font", "i", "s", "small", "strike", "strong", "tt", "u" })) {}
                    // A start tag whose tag name is "nobr"
                    if (self.currentTokenNameIs("nobr")) {}
                    // A start tag whose tag name is one of: "applet", "marquee", "object"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "applet", "marquee", "object" })) {}
                    // A start tag whose tag name is "table"
                    if (self.currentTokenNameIs("table")) {}
                    // A start tag whose tag name is one of: "area", "br", "embed", "img", "keygen", "wbr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "area", "br", "embed", "img", "keygen", "wbr" })) {}
                    // A start tag whose tag name is "input"
                    if (self.currentTokenNameIs("input")) {}
                    // A start tag whose tag name is one of: "param", "source", "track"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "param", "source", "track" })) {}
                    // A start tag whose tag name is "hr"
                    if (self.currentTokenNameIs("hr")) {}
                    // A start tag whose tag name is "image"
                    if (self.currentTokenNameIs("image")) {}
                    // A start tag whose tag name is "textarea"
                    if (self.currentTokenNameIs("textarea")) {}
                    // A start tag whose tag name is "xmp"
                    if (self.currentTokenNameIs("xmp")) {}
                    // A start tag whose tag name is "iframe"
                    if (self.currentTokenNameIs("iframe")) {}
                    // A start tag whose tag name is "noembed"
                    if (self.currentTokenNameIs("noembed")) {}
                    // A start tag whose tag name is "noscript", if the scripting flag is enabled
                    if (self.currentTokenNameIs("noscript")) {}
                    // A start tag whose tag name is "select"
                    if (self.currentTokenNameIs("select")) {}
                    // A start tag whose tag name is "option"
                    if (self.currentTokenNameIs("option")) {}
                    // A start tag whose tag name is "optgroup"
                    if (self.currentTokenNameIs("optgroup")) {}
                    // A start tag whose tag name is one of: "rb", "rtc"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "rb", "rtc" })) {}
                    // A start tag whose tag name is one of: "rp", "rt"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "rp", "rt" })) {}
                    // A start tag whose tag name is "math"
                    if (self.currentTokenNameIs("math")) {}
                    // A start tag whose tag name is "svg"
                    if (self.currentTokenNameIs("svg")) {}
                    // A start tag whose tag name is one of: "caption", "col", "colgroup", "frame", "head", "tbody", "td", "tfoot", "th", "thead", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "caption", "col", "colgroup", "frame", "head", "tbody", "td", "tfoot", "th", "thead", "tr" })) {}
                    // Any other start tag
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "body"
                    if (self.currentTokenNameIs("body")) {
                        if (!self.hasElementInScope("body")) {
                            // Parse Error
                            self.nextToken();
                            continue :sw .InBody;
                        }
                        self.nextToken();
                        continue :sw .AfterBody;
                    }
                    // An end tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {
                        if (!self.hasElementInScope("body")) {
                            // Parse Error
                            self.nextToken();
                            continue :sw .InBody;
                        }
                        continue :sw .AfterBody;
                    }
                    // An end tag whose tag name is one of: "address", "article", "aside", "blockquote", "button", "center", "details", "dialog", "dir", "div", "dl", "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "listing", "main", "menu", "nav", "ol", "pre", "search", "section", "select", "summary", "ul"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "address", "article", "aside", "blockquote", "button", "center", "details", "dialog", "dir", "div", "dl", "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "listing", "main", "menu", "nav", "ol", "pre", "search", "section", "select", "summary", "ul" })) {}
                    // An end tag whose tag name is "form"
                    if (self.currentTokenNameIs("form")) {}
                    // An end tag whose tag name is "p"
                    if (self.currentTokenNameIs("p")) {}
                    // An end tag whose tag name is "li"
                    if (self.currentTokenNameIs("li")) {}
                    // An end tag whose tag name is one of: "dd", "dt"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "dd", "dt" })) {}
                    // An end tag whose tag name is one of: "h1", "h2", "h3", "h4", "h5", "h6"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "h1", "h2", "h3", "h4", "h5", "h6" })) {}
                    // An end tag whose tag name is "sarcasm"
                    if (self.currentTokenNameIs("sarcasm")) {}
                    // An end tag whose tag name is one of: "a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u" })) {}
                    // An end tag token whose tag name is one of: "applet", "marquee", "object"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "applet", "marquee", "object" })) {}
                    // An end tag whose tag name is "br"
                    if (self.currentTokenNameIs("br")) {}
                    // Any other end tag
                    else {}
                }
            },
            .Text => {
                // A character token
                if (self.isCurrentTokenCharacter()) {
                    try self.insertCharacter(self.current_token.Character.data.items);
                    self.nextToken();
                    continue :sw .Text;
                }
                // An end-of-file token
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "script"
                    // Any other end tag
                    _ = self.open_elements.pop();
                    self.nextToken();
                    continue :sw self.original_insertion_mode;
                }
            },
            .InTable => {
                // A character token, if the current node is table, tbody, template, tfoot, thead, or tr element
                // A comment token
                if (self.isCurrentTokenComment()) {}
                // A DOCTYPE token
                if (self.isCurrentTokenDOCTYPE()) {}
                // An end-of-file token
                if (self.isCurrentTokenEOF()) {}
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "caption"
                    if (self.currentTokenNameIs("caption")) {}
                    // A start tag whose tag name is "colgroup"
                    if (self.currentTokenNameIs("colgroup")) {}
                    // A start tag whose tag name is "col"
                    if (self.currentTokenNameIs("col")) {}
                    // A start tag whose tag name is one of: "tbody", "tfoot", "thead"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "tbody", "tfoot", "thead" })) {}
                    // A start tag whose tag name is one of: "td", "th", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "td", "th", "tr" })) {}
                    // A start tag whose tag name is "table"
                    if (self.currentTokenNameIs("table")) {}
                    // A start tag whose tag name is one of: "style", "script", "template"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "style", "script", "template" })) {}
                    // A start tag whose tag name is "input"
                    if (self.currentTokenNameIs("input")) {}
                    // A start tag whose tag name is "form"
                    if (self.currentTokenNameIs("form")) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "table"
                    if (self.currentTokenNameIs("table")) {}
                    // An end tag whose tag name is one of: "body", "caption", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "body", "caption", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr" })) {}
                    // An end tag whose tag name is "template"
                    if (self.currentTokenNameIs("template")) {}
                }
                // Anything else
                else {}
            },
            .InTableText => {
                // A character token that is U+0000 NULL
                // Any other character token
                // Anything else
            },
            .InCaption => {
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is one of: "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr" })) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "caption"
                    if (self.currentTokenNameIs("caption")) {}
                    // An end tag whose tag name is "table"
                    if (self.currentTokenNameIs("table")) {}
                    // An end tag whose tag name is one of: "body", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "body", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr" })) {}
                }
                // Anything else
                else {}
            },
            .InColumnGroup => {
                // A comment token
                if (self.isCurrentTokenComment()) {}
                // A DOCTYPE token
                if (self.isCurrentTokenDOCTYPE()) {}
                // An end-of-file token
                if (self.isCurrentTokenEOF()) {}
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {}
                    // A start tag whose tag name is "col"
                    if (self.currentTokenNameIs("col")) {}
                    // A start tag whose tag name is "template"
                    if (self.currentTokenNameIs("template")) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "colgroup"
                    if (self.currentTokenNameIs("colgroup")) {}
                    // An end tag whose tag name is "col"
                    if (self.currentTokenNameIs("col")) {}
                    // An end tag whose tag name is "template"
                    if (self.currentTokenNameIs("template")) {}
                }
                // Anything else
                else {}
            },
            .InTableBody => {
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "tr"
                    if (self.currentTokenNameIs("tr")) {}
                    // A start tag whose tag name is one of: "th", "td"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "th", "td" })) {}
                    // A start tag whose tag name is one of: "caption", "col", "colgroup", "tbody", "tfoot", "thead"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "caption", "col", "colgroup", "tbody", "tfoot", "thead" })) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is one of: "tbody", "tfoot", "thead"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "tbody", "tfoot", "thead" })) {}
                    // An end tag whose tag name is "table"
                    if (self.currentTokenNameIs("table")) {}
                    // An end tag whose tag name is one of: "body", "caption", "col", "colgroup", "html", "td", "th", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "body", "caption", "col", "colgroup", "html", "td", "th", "tr" })) {}
                }
                // Anything else
                else {}
            },
            .InRow => {
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is one of: "th", "td"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "th", "td" })) {}
                    // A start tag whose tag name is one of: "caption", "col", "colgroup", "tbody", "tfoot", "thead", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "caption", "col", "colgroup", "tbody", "tfoot", "thead", "tr" })) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "tr"
                    if (self.currentTokenNameIs("tr")) {}
                    // An end tag whose tag name is "table"
                    if (self.currentTokenNameIs("table")) {}
                    // An end tag whose tag name is one of: "tbody", "tfoot", "thead"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "tbody", "tfoot", "thead" })) {}
                    // An end tag whose tag name is one of: "body", "caption", "col", "colgroup", "html", "td", "th"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "body", "caption", "col", "colgroup", "html", "td", "th" })) {}
                }
                // Anything else
                else {}
            },
            .InCell => {
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is one of: "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr" })) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is one of: "td", "th"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "td", "th" })) {}
                    // An end tag whose tag name is one of: "body", "caption", "col", "colgroup", "html"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "body", "caption", "col", "colgroup", "html" })) {}
                    // An end tag whose tag name is one of: "table", "tbody", "tfoot", "thead", "tr"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "table", "tbody", "tfoot", "thead", "tr" })) {}
                }
                // Anything else
                else {}
            },
            .InTemplate => {
                // A character token
                // A comment token
                if (self.isCurrentTokenComment()) {}
                // A DOCTYPE token
                if (self.isCurrentTokenDOCTYPE()) {}
                // An end-of-file token
                if (self.isCurrentTokenEOF()) {}
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is one of: "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "template", "title"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "template", "title" })) {}
                    // A start tag whose tag name is one of: "caption", "colgroup", "tbody", "tfoot", "thead"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "caption", "colgroup", "tbody", "tfoot", "thead" })) {}
                    // A start tag whose tag name is "col"
                    if (self.currentTokenNameIs("col")) {}
                    // A start tag whose tag name is "tr"
                    if (self.currentTokenNameIs("tr")) {}
                    // A start tag whose tag name is one of: "td", "th"
                    if (self.currentTokenNameIsOneOf(&[_][]const u8{ "td", "th" })) {}
                    // Any other start tag
                    else {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "template"
                    if (self.currentTokenNameIs("template")) {}
                    // Any other end tag
                    else {}
                }
            },
            .AfterBody => {
                // A comment token
                if (self.isCurrentTokenComment()) {}
                // A DOCTYPE token
                if (self.isCurrentTokenDOCTYPE()) {}
                // An end-of-file token
                if (self.isCurrentTokenEOF()) {}
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {
                        self.nextToken();
                        continue :sw .AfterAfterBody;
                    }
                }
                // Anything else
                else {}
            },
            .InFrameset => {
                // A comment token
                if (self.isCurrentTokenComment()) {}
                // A DOCTYPE token
                if (self.isCurrentTokenDOCTYPE()) {}
                // An end-of-file token
                if (self.isCurrentTokenEOF()) {}
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {}
                    // A start tag whose tag name is "frameset"
                    if (self.currentTokenNameIs("frameset")) {}
                    // A start tag whose tag name is "frame"
                    if (self.currentTokenNameIs("frame")) {}
                    // A start tag whose tag name is "noframes"
                    if (self.currentTokenNameIs("noframes")) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "frameset"
                    if (self.currentTokenNameIs("frameset")) {}
                }
                // Anything else
                else {}
            },
            .AfterFrameset => {
                // A comment token
                if (self.isCurrentTokenComment()) {}
                // A DOCTYPE token
                if (self.isCurrentTokenDOCTYPE()) {}
                // An end-of-file token
                if (self.isCurrentTokenEOF()) {}
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {}
                    // A start tag whose tag name is "noframes"
                    if (self.currentTokenNameIs("noframes")) {}
                }
                if (self.isCurrentTokenEndTag()) {
                    // An end tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {}
                }
                // Anything else
                else {}
            },
            .AfterAfterBody => {
                // A comment token
                if (self.isCurrentTokenComment()) {}
                // A DOCTYPE token
                if (self.isCurrentTokenDOCTYPE()) {}
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {}
                }
                // An end-of-file token
                if (self.isCurrentTokenEOF()) {}
                if (self.current_token.* == .EndOfFile) {
                    break :sw;
                }
                // Anything else
                else {}
            },
            .AfterAfterFrameset => {
                // A comment token
                if (self.isCurrentTokenComment()) {}
                // A DOCTYPE token
                if (self.isCurrentTokenDOCTYPE()) {}
                // An end-of-file token
                if (self.isCurrentTokenEOF()) {}
                if (self.isCurrentTokenStartTag()) {
                    // A start tag whose tag name is "html"
                    if (self.currentTokenNameIs("html")) {}
                    // A start tag whose tag name is "noframes"
                    if (self.currentTokenNameIs("noframes")) {}
                }
                // Anything else
                else {}
            },
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
    fn isCurrentTokenDOCTYPE(self: *HtmlParser) bool {
        return (self.current_token.* == .DOCTYPE);
    }
    fn isCurrentTokenCharacter(self: *HtmlParser) bool {
        return (self.current_token.* == .Character);
    }
    fn isCurrentTokenEOF(self: *HtmlParser) bool {
        return (self.current_token.* == .EndOfFile);
    }
    fn currentTokenNameIs(self: *HtmlParser, name: []const u8) bool {
        return (std.mem.eql(u8, name, self.current_token.Tag.tag_name.items));
    }
    fn currentTokenNameIsOneOf(self: *HtmlParser, names: []const []const u8) bool {
        for (names) |name| if (self.currentTokenNameIs(name)) return true;
        return false;
    }
    fn hasElementInScope(self: *HtmlParser, name: []const u8) bool {
        for (self.open_elements.items.len..0) |i| if (std.mem.eql(u8, self.open_elements.items[i].data.Element.tag_name, name)) return true;
        return false;
    }
};
