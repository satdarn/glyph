const std = @import("std");
const InputStream = @import("inputStream.zig").InputStream;
const Token = @import("tokens.zig").Token;
const TokenHandler = @import("tokens.zig").TokenHandler;

const LexerStates = enum {
    Data,
    RCDATA,
    RAWTEXT,
    ScriptData,
    PLAINTEXT,
    Tagopen,
    EndTagOpen,
    TagName,
    RCDATALessThanSign,
    RCADATAEndTagopen,
    RCADATAEndTagName,
    RAWTEXTLessThanSign,
    RAWTEXTEndTagOpen,
    RAWTEXTEndTagName,
    ScriptDataLessThanSign,
    ScriptDataEndTagOpen,
    ScriptDataEndTagName,
    ScriptDataEscapeStart,
    ScriptDataEscapeStartDash,
    ScriptDataEscaped,
    ScriptDataEscapedDash,
    ScriptDataEscapedDashDash,
    ScriptDataEscapedLessThanSign,
    ScriptDataEscapedEndTagOpen,
    ScriptDataEscapedEndTagName,
    ScriptDataDoubleEscapeStart,
    ScriptDataDoubleEscaped,
    ScriptDataDoubleEscapedDash,
    ScriptDataDoubleEscapedDashDash,
    ScriptDataDoubleEscapedLessThanSign,
    ScriptDataDoubleEscapeEnd,
    BeforeAttributeName,
    AttributeName,
    AfterAttributeName,
    BeforeAttributeValue,
    AttributeValueDoubleQuoted,
    AttributeValueSingleQuoted,
    AttributeValueUnquoted,
    AfterAttributeValueQuoted,
    SelfClosingStartTag,
    BogusComment,
    MarkupDeclarationOpen,
    CommentStart,
    CommentStartDash,
    Comment,
    CommentLessThanSign,
    CommentLessThanSignBang,
    CommentLessThanSignBangDash,
    CommentLessThanSignBangDashDash,
    CommentEndDash,
    CommentEnd,
    CommentEndBang,
    DOCTYPE,
    BeforeDOCTYPEName,
    DOCTYPEName,
    AfterDOCTYPEName,
    AfterDOCTYPEPublicKeyword,
    BeforeDOCTYPEPublicIdentifier,
    DOCTYPEPublicIdentifierDoubleQuoted,
    DOCTYPEPublicIdentifierSingleQuoted,
    AfterDOCTYPEPublicIdentifier,
    BetweenDOCTYPEPublicAndSystemIdentifiers,
    AfterDOCTYPESystemKeyword,
    BeforeDOCTYPESystemIdentifier,
    DOCTYPESystemIdentifierDoubleQuoted,
    DOCTYPESystemIdentifierSingleQuoted,
    AfterDOCTYPESystemIdentifier,
    BogusDOCTYPE,
    CDATAsection,
    CDATAsectionbracket,
    CDATAsectionEnd,
    CharacterReference,
    Namedcharacterreference,
    Ambiguousampersand,
    Numericcharacterreference,
    Hexadecimalcharacterreferencestart,
    Decimalcharacterreferencestart,
    Hexadecimalcharacterreference,
    Decimalcharacterreference,
    NumericcharacterreferenceEnd,
    EOF,
};

pub const HtmlLexer = struct {
    stream: InputStream,
    allocator: std.mem.Allocator,
    current_state: LexerStates = .Data,
    return_state: LexerStates = .Data,
    current_token: *Token,
    current_input_character: ?u8,
    token_handler: TokenHandler,
    tempBuffer: std.ArrayList(u8),
    verbose: bool = false,
    pub fn init(allocator: std.mem.Allocator, path_to_html_file: []const u8 ) !HtmlLexer {
        const token_handler = try TokenHandler.init(allocator);
        const tempBuffer: std.ArrayList(u8) = try std.ArrayList(u8).initCapacity(allocator, 10);
        const stream: InputStream = try InputStream.initFromFile(allocator, path_to_html_file); 
        return .{ 
            .stream = stream, 
            .allocator = allocator, 
            .current_token = undefined, 
            .current_input_character = undefined, 
            .token_handler = token_handler, 
            .tempBuffer = tempBuffer 
        };

    }
    pub fn deinit(self: *HtmlLexer) void {
        self.stream.deinit();
        self.token_handler.deinit();
        self.tempBuffer.deinit(self.allocator);
    }

    pub fn nextToken(self: *HtmlLexer) !*Token {
        while (self.token_handler.getQueueLen() == 0 and self.current_state != .EOF) {
            try self.run();
        }
        if (self.verbose) {
            std.debug.print("Lexer emits a {s} token\n", .{@tagName(self.token_handler.token_queue.items[0].*)});
            self.token_handler.token_queue.items[0].printToken();
        }
        return self.token_handler.dequeue();
    }

    pub fn run(self: *HtmlLexer) !void {
        if (self.verbose) std.debug.print("Lexer state: {s}\n", .{@tagName(self.current_state)});
        switch (self.current_state) {
            .Data => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .Data;
                        return;
                    }
                    // U+0026 AMPERSAND (&)
                    if (char == '&') {
                        self.return_state = .Data;
                        self.current_state = .CharacterReference;
                        return;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        self.current_state = .Tagopen;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        self.current_token = try self.token_handler.createCharacter(char);
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    // Anything else
                    else {
                        self.current_token = try self.token_handler.createCharacter(char);
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                } else {
                    // EOF
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .RCDATA => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+0026 AMPERSAND (&)
                    if (char == '&') {
                        self.return_state = .RCDATA;
                        self.current_state = .CharacterReference;
                        return;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        self.current_state = .RCDATALessThanSign;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                    }
                    // Anything else
                    self.current_token = try self.token_handler.createCharacter(char);
                    try self.token_handler.enqueue(self.current_token);
                    self.current_state = .RCDATA;
                    return;
                } else {
                    // EOF
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .RAWTEXT => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        self.current_state = .RAWTEXTLessThanSign;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                    }
                    // Anything else
                    self.current_token = try self.token_handler.createCharacter(char);
                    try self.token_handler.enqueue(self.current_token);
                    self.current_state = .RAWTEXT;
                    return;
                } else {
                    // EOF
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .ScriptData => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        self.current_state = .ScriptDataLessThanSign;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                    }
                    // Anything else
                    self.current_token = try self.token_handler.createCharacter(char);
                    try self.token_handler.enqueue(self.current_token);
                    self.current_state = .ScriptData;
                    return;
                } else {
                    // EOF
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .PLAINTEXT => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                    }
                    // Anything else
                    self.current_token = try self.token_handler.createCharacter(char);
                    try self.token_handler.enqueue(self.current_token);
                    self.current_state = .PLAINTEXT;
                    return;
                } else {
                    // EOF
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },

            .Tagopen => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+0021 EXCLAMATION MARK (!)
                    if (char == '!') {
                        self.current_state = .MarkupDeclarationOpen;
                        return;
                    }
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        self.current_state = .EndTagOpen;
                        return;
                    }
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        self.current_token = try self.token_handler.createStartTag();
                        try self.current_token.Tag.tag_name.append(self.token_handler.allocator, char);
                        self.current_state = .TagName;
                        return;
                    }
                    // U+003F QUESTION MARK (?)
                    if (char == '?') {
                        // unexpected-question-mark-instead-of-tag-name parse error
                        self.current_token = try self.token_handler.createComment(0);
                        self.stream.reconsumeChar();
                        self.current_state = .BogusComment;
                        return;
                    }
                    // Anything else
                    // invalid-first-character-of-tag-name parse error
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                    self.stream.reconsumeChar();
                    self.current_state = .Data;
                    return;
                } else {
                    // EOF
                    // eof-before-tag-name parse error
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .EndTagOpen => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        self.current_token = try self.token_handler.createEndTag();
                        try self.current_token.Tag.tag_name.append(self.token_handler.allocator, char);
                        self.current_state = .TagName;
                        return;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        // missing-end-tag-name parse error
                        self.current_state = .Data;
                        return;
                    } else {
                        // Anything else
                        // invalid-first-character-of-tag-name parse error
                        self.current_token = try self.token_handler.createComment(0);
                        self.stream.reconsumeChar();
                        self.current_state = .BogusComment;
                        return;
                    }
                } else {
                    // EOF
                    // eof-before-tag-name parse error
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .TagName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+0009 CHARACTER TABULATION (tab) U+000A LINE FEED (LF) U+000C FORM FEED (FF) U+0020 SPACE
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeAttributeName;
                        return;
                    }
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        self.current_state = .SelfClosingStartTag;
                        return;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    // ASCII upper alpha
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        try self.current_token.Tag.tag_name.append(self.token_handler.allocator, std.ascii.toLower(char));
                        self.current_state = .TagName;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        self.current_state = .TagName;
                        return;
                    } else {
                        // Anything else
                        try self.current_token.Tag.tag_name.append(self.token_handler.allocator, char);
                        self.current_state = .TagName;
                        return;
                    }
                } else {
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .RCDATALessThanSign => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        self.tempBuffer.clearAndFree(self.allocator);
                        self.current_state = .RCADATAEndTagopen;
                        return;
                    } else {
                        // Anything else
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('>'));
                        self.stream.reconsumeChar();
                        self.current_state = .RCDATA;
                        return;
                    }
                } else {
                    // EOF is Anything else
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('>'));
                    self.stream.reconsumeChar();
                    self.current_state = .RCDATA;
                    return;
                }
            },
            .RCADATAEndTagopen => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        self.current_token = try self.token_handler.createEndTag();
                        self.stream.reconsumeChar();
                        self.current_state = .RCADATAEndTagName;
                        return;
                    } else {
                        // Anything else
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('/'));
                        self.stream.reconsumeChar();
                        self.current_state = .RCDATA;
                        return;
                    }
                } else {
                    // EOF is Anything else
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('/'));
                    self.stream.reconsumeChar();
                    self.current_state = .RCDATA;
                    return;
                }
            },
            .RCADATAEndTagName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+0009 CHARACTER TABULATION (tab) U+000A LINE FEED (LF) U+000C FORM FEED (FF) U+0020 SPACE
                    if (std.ascii.isWhitespace(char) and self.token_handler.isAppropriateEndTagToken(self.current_token)) {
                        // If the current end tag token is an appropriate end tag token, then switch to the before attribute name state.
                        // Otherwise, treat it as per the "anything else" entry below.
                        self.current_state = .BeforeAttributeName;
                        return;
                    }
                    // U+002F SOLIDUS (/)
                    if (char == '/' and self.token_handler.isAppropriateEndTagToken(self.current_token)) {
                        // If the current end tag token is an appropriate end tag token, then switch to the self-closing start tag state.
                        // Otherwise, treat it as per the "anything else" entry below.
                        self.current_state = .SelfClosingStartTag;
                        return;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>' and self.token_handler.isAppropriateEndTagToken(self.current_token) ) {
                        // If the current end tag token is an appropriate end tag token, then switch to the data state and emit the current tag token.
                        // Otherwise, treat it as per the "anything else" entry below.
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    if (std.ascii.isAlphabetic(char)) {
                        // ASCII upper alpha
                        if (std.ascii.isUpper(char)) {
                            // Append the lowercase version of the current input character (add 0x0020 to the character's code point)
                            // to the current tag token's tag name. Append the current input character to the temporary buffer.
                            try self.current_token.Tag.tag_name.append(self.token_handler.allocator, std.ascii.toLower(char));
                            try self.tempBuffer.append(self.allocator, std.ascii.toLower(char));
                            self.current_state = .RCADATAEndTagName;
                            return;
                        }
                        // ASCII lower alpha
                        else if (std.ascii.isLower(char)) {
                            // Append the current input character to the current tag token's tag name.
                            // Append the current input character to the temporary buffer.
                            try self.current_token.Tag.tag_name.append(self.token_handler.allocator, char);
                            try self.tempBuffer.append(self.allocator, char);
                            self.current_state = .RCADATAEndTagName;
                            return;
                        }
                    }
                    // Anything else
                    else {
                        // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                        // and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer).
                        // Reconsume in the RCDATA state.
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('/'));
                        for (self.tempBuffer.items) |temp_char| {
                            try self.token_handler.enqueue(try self.token_handler.createCharacter(temp_char));
                        }
                        self.stream.reconsumeChar();
                        self.current_state = .RCDATA;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                    // and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer).
                    // Reconsume in the RCDATA state.
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('/'));
                    for (self.tempBuffer.items) |temp_char| {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter(temp_char));
                    }
                    self.stream.reconsumeChar();
                    self.current_state = .RCDATA;
                    return;
                }
            },
            .RAWTEXTLessThanSign => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        self.tempBuffer.clearAndFree(self.allocator);
                        self.current_state = .RAWTEXTEndTagOpen;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        self.stream.reconsumeChar();
                        self.current_state = .RAWTEXT;
                        return;
                    }
                }
                // EOF is Anything else
                else {}
            },
            .RAWTEXTEndTagOpen => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        self.current_token = try self.token_handler.createEndTag();
                        try self.current_token.Tag.tag_name.append(self.token_handler.allocator, std.ascii.toLower(char));
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        self.stream.reconsumeChar();
                        self.current_state = .RAWTEXT;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                    self.stream.reconsumeChar();
                    self.current_state = .RAWTEXT;
                    return;
                }
            },
            .RAWTEXTEndTagName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+0009 CHARACTER TABULATION (tab) U+000A LINE FEED (LF) U+000C FORM FEED (FF) U+0020 SPACE
                    if (std.ascii.isWhitespace(char)) {
                        // If the current end tag token is an appropriate end tag token, then switch to the before attribute name state.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        // If the current end tag token is an appropriate end tag token, then switch to the self-closing start tag state.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        // If the current end tag token is an appropriate end tag token, then switch to the data state and emit the current tag token.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    if (std.ascii.isAlphabetic(char)) {
                        // ASCII upper alpha
                        if (std.ascii.isUpper(char)) {
                            // Append the lowercase version of the current input character (add 0x0020 to the character's code point)
                            // to the current tag token's tag name. Append the current input character to the temporary buffer.
                        }
                        // ASCII lower alpha
                        else if (std.ascii.isLower(char)) {
                            // Append the current input character to the current tag token's tag name. Append the current input character to the temporary buffer.
                        }
                    }
                    // Anything else
                    else {
                        // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                        // and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer).
                        // Reconsume in the RAWTEXT state.
                    }
                }
                // EOF is Anything else
                else {
                    // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                    // and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer).
                    // Reconsume in the RAWTEXT state.
                }
            },
            .ScriptDataLessThanSign => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        self.tempBuffer.clearAndFree(self.allocator);
                        self.current_state = .ScriptDataEndTagOpen;
                        return;
                    }
                    // U+0021 EXCLAMATION MARK (!)
                    if (char == '!') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('!'));
                        self.current_state = .ScriptDataEscapeStart;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        self.stream.reconsumeChar();
                        self.current_state = .ScriptData;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                    self.stream.reconsumeChar();
                    self.current_state = .ScriptData;
                    return;
                }
            },
            .ScriptDataEndTagOpen => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        self.current_token = try self.token_handler.createEndTag();
                        try self.current_token.Tag.tag_name.append(self.token_handler.allocator, std.ascii.toLower(char));
                        self.current_state = .ScriptDataEndTagName;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('/'));
                        self.current_state = .ScriptData;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('/'));
                    self.current_state = .ScriptData;
                    return;
                }
            },
            .ScriptDataEndTagName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+0009 CHARACTER TABULATION (tab) U+000A LINE FEED (LF) U+000C FORM FEED (FF) U+0020 SPACE
                    if (std.ascii.isWhitespace(char)) {
                        // If the current end tag token is an appropriate end tag token, then switch to the before attribute name state.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        // If the current end tag token is an appropriate end tag token, then switch to the self-closing start tag state.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        // If the current end tag token is an appropriate end tag token, then switch to the data state and emit the current tag token.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    if (std.ascii.isAlphabetic(char)) {
                        // ASCII upper alpha
                        if (std.ascii.isUpper(char)) {
                            // Append the lowercase version of the current input character (add 0x0020 to the character's code point)
                            // to the current tag token's tag name.
                            // Append the current input character to the temporary buffer.
                        }
                        // ASCII lower alpha
                        else if (std.ascii.isLower(char)) {
                            // Append the current input character to the current tag token's tag name.
                            // Append the current input character to the temporary buffer.
                        }
                    }
                    // Anything else
                    else {
                        // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                        // and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer).
                        // Reconsume in the script data state.
                    }
                }
                // EOF is Anything else
                else {
                    // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                    // and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer).
                    // Reconsume in the script data state.
                }
            },
            .ScriptDataEscapeStart => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('_'));
                        self.current_state = .ScriptDataEscapeStartDash;
                        return;
                    }
                    // Anything else
                    else {
                        self.stream.reconsumeChar();
                        self.current_state = .ScriptData;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    self.stream.reconsumeChar();
                    self.current_state = .ScriptData;
                    return;
                }
            },
            .ScriptDataEscapeStartDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('_'));
                        self.current_state = .ScriptDataEscapedDashDash;
                        return;
                    }
                    // Anything else
                    else {
                        self.stream.reconsumeChar();
                        self.current_state = .ScriptData;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    self.stream.reconsumeChar();
                    self.current_state = .ScriptData;
                    return;
                }
            },
            .ScriptDataEscaped => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('_'));
                        self.current_state = .ScriptDataEscapeStartDash;
                        return;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        self.current_state = .ScriptDataEscapedLessThanSign;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                }
            },
            .ScriptDataEscapedDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('_'));
                        self.current_state = .ScriptDataEscapedDashDash;
                        return;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        self.current_state = .ScriptDataEscapedLessThanSign;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                        self.current_state = .ScriptDataEscapedDash;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                }
            },
            .ScriptDataEscapedDashDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('-'));
                        self.current_state = .ScriptDataEscapedDashDash;
                        return;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        self.current_state = .ScriptDataEscapedLessThanSign;
                        return;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('>'));
                        self.current_state = .ScriptData;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                        self.current_state = .ScriptDataEscaped;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                        self.current_state = .ScriptDataEscaped;
                        return;
                    }
                }
                // EOF
                else {
                    // eof-in-script-html-comment-like-text parse error
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .ScriptDataEscapedLessThanSign => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        self.tempBuffer.clearAndFree(self.allocator);
                        self.current_state = .ScriptDataEscapedEndTagOpen;
                        return;
                    }
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        self.tempBuffer.clearAndFree(self.allocator);
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        self.stream.reconsumeChar();
                        self.current_state = .ScriptDataDoubleEscapeStart;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        self.current_state = .ScriptDataEscaped;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                    self.current_state = .ScriptDataEscaped;
                    return;
                }
            },
            .ScriptDataEscapedEndTagOpen => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isAlphabetic(char)) {
                        self.current_token = try self.token_handler.createEndTag();
                        try self.current_token.Tag.tag_name.append(self.token_handler.allocator, char);
                        self.current_state = .ScriptDataEscapedEndTagName;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createComment('<'));
                        try self.token_handler.enqueue(try self.token_handler.createComment('/'));
                        self.current_state = .ScriptDataEscaped;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    try self.token_handler.enqueue(try self.token_handler.createComment('<'));
                    try self.token_handler.enqueue(try self.token_handler.createComment('/'));
                    self.current_state = .ScriptDataEscaped;
                    return;
                }
            },
            .ScriptDataEscapedEndTagName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+0009 CHARACTER TABULATION (tab) U+000A LINE FEED (LF) U+000C FORM FEED (FF) U+0020 SPACE
                    if (std.ascii.isWhitespace(char)) {
                        // If the current end tag token is an appropriate end tag token,
                        // then switch to the before attribute name state.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        // If the current end tag token is an appropriate end tag token,
                        // then switch to the self-closing start tag state.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        // If the current end tag token is an appropriate end tag token,
                        // then switch to the data state and emit the current tag token.
                        // Otherwise, treat it as per the "anything else" entry below.
                    }
                    // ASCII upper alpha
                    if (std.ascii.isAlphabetic(char)) {
                        // ASCII upper alpha
                        if (std.ascii.isUpper(char)) {
                            // Append the lowercase version of the current input character
                            // (add 0x0020 to the character's code point) to the current tag token's tag name.
                            // Append the current input character to the temporary buffer.
                        }
                        // ASCII lower alpha
                        else if (std.ascii.isLower(char)) {
                            // Append the current input character to the current tag token's tag name.
                            // Append the current input character to the temporary buffer.
                        }
                    }
                    //Anything else
                    else {
                        // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                        // and a character token for each of the characters in the temporary buffer
                        // (in the order they were added to the buffer). Reconsume in the script data escaped state.
                    }
                }
                // EOF is Anything else
                else {
                    // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                    // and a character token for each of the characters in the temporary buffer
                    // (in the order they were added to the buffer). Reconsume in the script data escaped state.

                }
            },
            .ScriptDataDoubleEscapeStart => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char) or char == '/' or char == '>') {
                        // If the temporary buffer is the string "script",
                        // then switch to the script data double escaped state.
                        if (std.mem.eql(u8, self.tempBuffer.items, "script")) {
                            self.current_state = .ScriptDataDoubleEscaped;
                            return;
                        }
                        // Otherwise, switch to the script data escaped state.
                        // Emit the current input character as a character token.
                        try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                        self.current_state = .ScriptDataEscaped;
                        return;
                    }
                } else {}
            },
            .ScriptDataDoubleEscaped => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('-'));
                        self.current_state = .ScriptDataDoubleEscapedDash;
                        return;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        self.current_state = .ScriptDataDoubleEscapedLessThanSign;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                        self.current_state = .ScriptDataDoubleEscaped;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                        self.current_state = .ScriptDataDoubleEscaped;
                        return;
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .ScriptDataDoubleEscapedDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('-'));
                        self.current_state = .ScriptDataDoubleEscapedDashDash;
                        return;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        self.current_state = .ScriptDataDoubleEscapedLessThanSign;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                        self.current_state = .ScriptDataDoubleEscaped;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                        self.current_state = .ScriptDataDoubleEscaped;
                        return;
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .ScriptDataDoubleEscapedDashDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('-'));
                        self.current_state = .ScriptDataDoubleEscapedDashDash;
                        return;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('<'));
                        self.current_state = .ScriptDataDoubleEscapedLessThanSign;
                        return;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    // Switch to the script data state. Emit a U+003E GREATER-THAN SIGN character token.
                    if (char == '>') {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('>'));
                        self.current_state = .ScriptData;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error.
                        try self.token_handler.enqueue(try self.token_handler.createReplacement());
                        self.current_state = .ScriptDataDoubleEscaped;
                        return;
                    }
                    // Anything else
                    else {
                        try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                        self.current_state = .ScriptDataDoubleEscaped;
                        return;
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .ScriptDataDoubleEscapedLessThanSign => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        self.tempBuffer.clearAndFree(self.allocator);
                        try self.token_handler.enqueue(try self.token_handler.createCharacter('/'));
                        self.current_state = .ScriptDataDoubleEscaped;
                        return;
                    }
                    // Anything else
                    else {
                        self.stream.reconsumeChar();
                        self.current_state = .ScriptDataDoubleEscaped;
                        return;
                    }
                }
                // EOF is Anything else
                else {
                    self.stream.reconsumeChar();
                    self.current_state = .ScriptDataDoubleEscaped;
                    return;
                }
            },
            .ScriptDataDoubleEscapeEnd => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char) or char == '/' or char == '>') {
                        if (std.mem.eql(u8, self.tempBuffer.items, "script")) {
                            self.current_state = .ScriptDataEscaped;
                            return;
                        } else {
                            try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                            self.current_state = .ScriptDataDoubleEscaped;
                            return;
                        }
                    }
                    if (std.ascii.isAlphabetic(char)) {
                        // ASCII upper alpha
                        if (std.ascii.isUpper(char)) {
                            try self.token_handler.enqueue(try self.token_handler.createCharacter(std.ascii.toLower(char)));
                            self.current_state = .ScriptDataDoubleEscaped;
                            return;
                        }
                        // ASCII lower alpha
                        if (std.ascii.isLower(char)) {
                            // Append the current input character to the temporary buffer. Emit the current input character as a character token.
                            try self.token_handler.enqueue(try self.token_handler.createCharacter(char));
                        }
                        // Anything else
                        else {
                            self.stream.reconsumeChar();
                            self.current_state = .ScriptDataDoubleEscaped;
                            return;
                        }
                    }
                }
                // Eof is Anything else
                else {
                    self.stream.reconsumeChar();
                    self.current_state = .ScriptDataDoubleEscaped;
                    return;
                }
            },
            .BeforeAttributeName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeAttributeName;
                        return;
                    }
                    // U+002F SOLIDUS (/) and U+003E GREATER-THAN SIGN (>)
                    if (char == '/' and char == '>') {
                        self.stream.reconsumeChar();
                        self.current_state = .AttributeName;
                        return;
                    }
                    // U+003D EQUALS SIGN (=)
                    if (char == '=') {
                        // unexpected-equals-sign-before-attribute-name parse error
                        try self.current_token.Tag.attributes.addAttribute();
                        try self.current_token.Tag.attributes.appendAttrName(char);
                        self.current_state = .AttributeName;
                        return;
                    }
                    // Anything else
                    else {
                        try self.current_token.Tag.attributes.addAttribute();
                        self.stream.reconsumeChar();
                        self.current_state = .AttributeName;
                        return;
                    }
                }
                // EOF
                else {
                    self.stream.reconsumeChar();
                    self.current_state = .AttributeName;
                    return;
                }
            },
            .AttributeName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char) or char == '/' or char == '>') {
                        self.stream.reconsumeChar();
                        self.current_state = .AfterAttributeName;
                        return;
                    }
                    if (char == '=') {
                        self.current_state = .BeforeAttributeValue;
                        return;
                    }
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        try self.current_token.Tag.attributes.appendAttrName(std.ascii.toLower(char));
                        self.current_state = .AttributeName;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's name.
                        self.current_state = .AttributeName;
                        return;
                    }
                    if (char == '\"' or char == '\'' or char == '<') {
                        // unexpected-character-in-attribute-name parse error
                        try self.current_token.Tag.attributes.appendAttrName(char);
                        self.current_state = .AttributeName;
                        return;
                    } else {
                        try self.current_token.Tag.attributes.appendAttrName(char);
                        self.current_state = .AttributeName;
                        return;
                    }
                } else {
                    self.stream.reconsumeChar();
                    self.current_state = .AfterAttributeName;
                    return;
                }
            },
            .AfterAttributeName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .AfterAttributeName;
                        return;
                    }
                    if (char == '/') {
                        self.current_state = .SelfClosingStartTag;
                        return;
                    }
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        try self.current_token.Tag.attributes.appendAttrName(char);
                        self.current_state = .AttributeName;
                        return;
                    }
                } else {
                    // eof-in-tag parse error
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .BeforeAttributeValue => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeAttributeValue;
                        return;
                    }
                    if (char == '\"') {
                        self.current_state = .AttributeValueDoubleQuoted;
                        return;
                    }
                    if (char == '\'') {
                        self.current_state = .AttributeValueSingleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // missing-attribute-value parse error
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        self.stream.reconsumeChar();
                        self.current_state = .AttributeValueUnquoted;
                        return;
                    }
                } else {
                    self.stream.reconsumeChar();
                    self.current_state = .AttributeValueUnquoted;
                    return;
                }
            },

            .AttributeValueDoubleQuoted => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '\"') {
                        self.current_state = .AfterAttributeValueQuoted;
                        return;
                    }
                    if (char == '&') {
                        self.return_state = .AttributeValueDoubleQuoted;
                        self.current_state = .CharacterReference;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.
                        self.current_state = .AttributeValueDoubleQuoted;
                        return;
                    } else {
                        try self.current_token.Tag.attributes.appendAttrData(char);
                        self.current_state = .AttributeValueDoubleQuoted;
                        return;
                    }
                } else {
                    // eof-in-tag parse error
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .AttributeValueSingleQuoted => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '\'') {
                        self.current_state = .AfterAttributeValueQuoted;
                        return;
                    }
                    if (char == '&') {
                        self.return_state = .AttributeValueSingleQuoted;
                        self.current_state = .CharacterReference;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.
                        self.current_state = .AttributeValueSingleQuoted;
                        return;
                    } else {
                        try self.current_token.Tag.attributes.appendAttrData(char);
                        self.current_state = .AttributeValueSingleQuoted;
                        return;
                    }
                } else {
                    // eof-in-tag parse error
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .AttributeValueUnquoted => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeAttributeName;
                        return;
                    }
                    if (char == '&') {
                        self.return_state = .AttributeValueUnquoted;
                        self.current_state = .CharacterReference;
                        return;
                    }
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.
                        self.current_state = .AttributeValueUnquoted;
                        return;
                    }
                    if (char == '\"' or char == '\'' or char == '<' or char == '=' or char == '`') {
                        // unexpected-character-in-unquoted-attribute-value parse error
                        // Treat it as per the "anything else" entry below.
                        try self.current_token.Tag.attributes.appendAttrData(char);
                        self.current_state = .AttributeValueUnquoted;
                        return;
                    } else {
                        try self.current_token.Tag.attributes.appendAttrData(char);
                        self.current_state = .AttributeValueUnquoted;
                        return;
                    }
                } else {
                    // eof-in-tag parse error
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .AfterAttributeValueQuoted => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeAttributeName;
                        return;
                    }
                    if (char == '/') {
                        self.current_state = .SelfClosingStartTag;
                        return;
                    }
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        // missing-whitespace-between-attributes parse error
                        self.stream.reconsumeChar();
                        self.current_state = .BeforeAttributeName;
                        return;
                    }
                } else {
                    // eof-in-tag parse error
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .SelfClosingStartTag => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '>') {
                        self.current_token.Tag.self_closing = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        // unexpected-solidus-in-tag parse error
                        self.stream.reconsumeChar();
                        self.current_state = .BeforeAttributeName;
                        return;
                    }
                } else {
                    // eof-in-tag parse error
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .BogusComment => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '>') {
                        self.current_token.Tag.self_closing = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        self.current_state = .BogusComment;
                        return;
                    } else {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, char);
                    }
                } else {
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                }
            },

            .MarkupDeclarationOpen => {
                if (self.stream.consumeString("DOCTYPE")) {
                    self.current_state = .DOCTYPE;
                    return;
                }
                if (self.stream.consumeString("--")) {
                    self.current_token = try self.token_handler.createComment(0);
                    self.current_state = .CommentStart;
                    return;
                } else {
                    self.current_token = try self.token_handler.createComment(0);
                    self.current_state = .BogusComment;
                    return;
                }
            },
            .CommentStart => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '-') {
                        self.current_state = .CommentStartDash;
                        return;
                    }
                    if (char == '>') {
                        // abrupt-closing-of-empty-comment parse error
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        self.stream.reconsumeChar();
                        self.current_state = .Comment;
                        return;
                    }
                } else {
                    self.stream.reconsumeChar();
                    self.current_state = .Comment;
                    return;
                }
            },
            .CommentStartDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '-') {
                        self.current_state = .CommentEnd;
                        return;
                    }
                    if (char == '>') {
                        // abrupt-closing-of-empty-comment parse error
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        self.stream.reconsumeChar();
                        self.current_state = .Comment;
                        return;
                    }
                } else {
                    // eof-in-comment parse error
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },

            .Comment => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '<') {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, char);
                        self.current_state = .CommentLessThanSign;
                        return;
                    }
                    if (char == '-') {
                        self.current_state = .CommentEndDash;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        self.current_state = .Comment;
                        return;
                    }
                } else {
                    // eof-in-comment parse error
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .CommentLessThanSign => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '!') {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, char);
                        self.current_state = .CommentLessThanSignBang;
                        return;
                    }
                    if (char == '<') {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, char);
                        self.current_state = .CommentLessThanSign;
                        return;
                    } else {
                        self.stream.reconsumeChar();
                        self.current_state = .Comment;
                        return;
                    }
                } else {
                    self.stream.reconsumeChar();
                    self.current_state = .Comment;
                    return;
                }
            },
            .CommentLessThanSignBang => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '-') {
                        self.current_state = .CommentLessThanSignBangDash;
                        return;
                    } else {
                        self.stream.reconsumeChar();
                        self.current_state = .Comment;
                        return;
                    }
                } else {
                    self.stream.reconsumeChar();
                    self.current_state = .Comment;
                    return;
                }
            },
            .CommentLessThanSignBangDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '-') {
                        self.current_state = .CommentLessThanSignBangDashDash;
                        return;
                    } else {
                        self.stream.reconsumeChar();
                        self.current_state = .CommentEndDash;
                        return;
                    }
                } else {
                    self.stream.reconsumeChar();
                    self.current_state = .CommentEndDash;
                    return;
                }
            },
            .CommentLessThanSignBangDashDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '>') {
                        self.stream.reconsumeChar();
                        self.current_state = .CommentEnd;
                        return;
                    } else {
                        // nested-comment parse error
                        self.stream.reconsumeChar();
                        self.current_state = .CommentEnd;
                        return;
                    }
                } else {
                    self.stream.reconsumeChar();
                    self.current_state = .CommentEnd;
                    return;
                }
            },
            .CommentEndDash => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '-') {
                        self.current_state = .CommentEnd;
                        return;
                    } else {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        self.stream.reconsumeChar();
                        self.current_state = .Comment;
                        return;
                    }
                } else {
                    // eof-in-comment parse error
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .CommentEnd => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    if (char == '!') {
                        self.current_state = .CommentEndBang;
                        return;
                    }
                    if (char == '-') {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        self.current_state = .CommentEnd;
                        return;
                    } else {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        self.current_state = .Comment;
                        return;
                    }
                } else {
                    // eof-in-comment parse error
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .CommentEndBang => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '-') {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '!');
                        self.current_state = .CommentEndDash;
                        return;
                    }
                    if (char == '>') {
                        // incorrectly-closed-comment parse error
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '-');
                        try self.current_token.Comment.data.append(self.token_handler.allocator, '!');
                        self.current_state = .Comment;
                        return;
                    }
                } else {
                    // eof-in-comment parse error
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            // Anything else
            // Append two U+002D HYPHEN-MINUS characters (-) and a U+0021 EXCLAMATION MARK character (!) to the comment token's data. Reconsume in the comment state.
            .DOCTYPE => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeDOCTYPEName;
                        return;
                    }
                    if (char == '>') {
                        self.stream.reconsumeChar();
                        self.current_state = .BeforeDOCTYPEName;
                        return;
                    } else {
                        // missing-whitespace-before-doctype-name parse error
                        self.stream.reconsumeChar();
                        self.current_state = .BeforeDOCTYPEName;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token = try self.token_handler.createDOCTYPEToken();
                    self.current_token.DOCTYPE.force_quirks = false;
                    try self.token_handler.enqueue(self.current_token);
                }
            },
            .BeforeDOCTYPEName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeDOCTYPEName;
                        return;
                    }
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        self.current_token = try self.token_handler.createDOCTYPEToken();
                        try self.current_token.DOCTYPE.name.append(self.token_handler.allocator, std.ascii.toLower(char));
                        self.current_state = .DOCTYPEName;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        self.current_token = try self.token_handler.createDOCTYPEToken();
                        // Set the token's name to a U+FFFD REPLACEMENT CHARACTER character
                        self.current_state = .DOCTYPEName;
                        return;
                    }
                    if (char == '>') {
                        self.current_token = try self.token_handler.createDOCTYPEToken();
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        self.current_token = try self.token_handler.createDOCTYPEToken();
                        try self.current_token.DOCTYPE.name.append(self.token_handler.allocator, char);
                        self.current_state = .DOCTYPEName;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token = try self.token_handler.createDOCTYPEToken();
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .DOCTYPEName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .AfterDOCTYPEName;
                        return;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    // ASCII upper alpha
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        try self.current_token.DOCTYPE.name.append(self.token_handler.allocator, std.ascii.toLower(char));
                        self.current_state = .DOCTYPEName;
                        return;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        self.current_state = .DOCTYPEName;
                        return;
                    }
                    // Anything else
                    else {
                        try self.current_token.DOCTYPE.name.append(self.token_handler.allocator, char);
                        self.current_state = .DOCTYPEName;
                        return;
                    }
                }
                // EOF
                else {
                    //eof-in-doctype parse error
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .AfterDOCTYPEName => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .AfterDOCTYPEName;
                        return;
                    }
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    self.stream.case_sensitive = false;
                    self.stream.reconsumeChar();
                    if (self.stream.consumeString("public")) {
                        self.current_state = .AfterDOCTYPEPublicKeyword;
                        return;
                    }
                    if (self.stream.consumeString("system")) {
                        self.current_state = .AfterDOCTYPESystemKeyword;
                        return;
                    } else {
                        // invalid-character-sequence-after-doctype-name parse error
                        self.stream.case_sensitive = true;
                        self.current_token.DOCTYPE.force_quirks = true;
                        self.stream.reconsumeChar();
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .AfterDOCTYPEPublicKeyword => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .AfterDOCTYPEPublicKeyword;
                        return;
                    }
                    if (char == '"') {
                        self.current_token.DOCTYPE.public_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPEPublicIdentifierDoubleQuoted;
                        return;
                    }
                    if (char == '\'') {
                        self.current_token.DOCTYPE.public_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPEPublicIdentifierSingleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // missing-doctype-public-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        // missing-quote-before-doctype-public-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        self.stream.reconsumeChar();
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .BeforeDOCTYPEPublicIdentifier => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeDOCTYPEPublicIdentifier;
                        return;
                    }
                    if (char == '"') {
                        self.current_token.DOCTYPE.public_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPEPublicIdentifierDoubleQuoted;
                        return;
                    }
                    if (char == '\'') {
                        self.current_token.DOCTYPE.public_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPEPublicIdentifierSingleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // missing-doctype-public-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        // missing-quote-before-doctype-public-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        self.stream.reconsumeChar();
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .DOCTYPEPublicIdentifierDoubleQuoted => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '"') {
                        self.current_state = .AfterDOCTYPEPublicIdentifier;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        self.current_state = .DOCTYPEPublicIdentifierDoubleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // abrupt-doctype-public-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        try self.current_token.DOCTYPE.public_ident.append(self.token_handler.allocator, char);
                        self.current_state = .DOCTYPEPublicIdentifierDoubleQuoted;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .DOCTYPEPublicIdentifierSingleQuoted => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '\'') {
                        self.current_state = .AfterDOCTYPEPublicIdentifier;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        self.current_state = .DOCTYPEPublicIdentifierSingleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // abrupt-doctype-public-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        try self.current_token.DOCTYPE.public_ident.append(self.token_handler.allocator, char);
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .AfterDOCTYPEPublicIdentifier => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BetweenDOCTYPEPublicAndSystemIdentifiers;
                        return;
                    }
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    if (char == '"') {
                        // missing-whitespace-between-doctype-public-and-system-identifiers parse error
                        self.current_token.DOCTYPE.system_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPESystemIdentifierDoubleQuoted;
                        return;
                    }
                    if (char == '\'') {
                        // missing-whitespace-between-doctype-public-and-system-identifiers parse error
                        self.current_token.DOCTYPE.system_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPESystemIdentifierSingleQuoted;
                        return;
                    } else {
                        // missing-quote-before-doctype-system-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        self.stream.reconsumeChar();
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .BetweenDOCTYPEPublicAndSystemIdentifiers => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BetweenDOCTYPEPublicAndSystemIdentifiers;
                        return;
                    }
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    if (char == '"') {
                        self.current_token.DOCTYPE.system_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPESystemIdentifierDoubleQuoted;
                        return;
                    }
                    if (char == '\'') {
                        self.current_token.DOCTYPE.system_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPESystemIdentifierSingleQuoted;
                        return;
                    } else {
                        // missing-quote-before-doctype-system-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        self.stream.reconsumeChar();
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .AfterDOCTYPESystemKeyword => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeDOCTYPESystemIdentifier;
                        return;
                    }
                    if (char == '"') {
                        // missing-whitespace-after-doctype-system-keyword parse error
                        self.current_token.DOCTYPE.system_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPESystemIdentifierDoubleQuoted;
                        return;
                    }
                    if (char == '\'') {
                        // missing-whitespace-after-doctype-system-keyword parse error
                        self.current_token.DOCTYPE.system_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPEPublicIdentifierSingleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // missing-doctype-system-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        // missing-quote-before-doctype-system-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        self.stream.reconsumeChar();
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .BeforeDOCTYPESystemIdentifier => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .BeforeDOCTYPESystemIdentifier;
                        return;
                    }
                    if (char == '"') {
                        self.current_token.DOCTYPE.system_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPESystemIdentifierDoubleQuoted;
                        return;
                    }
                    if (char == '\'') {
                        self.current_token.DOCTYPE.system_ident.clearAndFree(self.token_handler.allocator);
                        self.current_state = .DOCTYPESystemIdentifierSingleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // missing-doctype-system-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        // missing-quote-before-doctype-system-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        self.stream.reconsumeChar();
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .DOCTYPESystemIdentifierDoubleQuoted => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '"') {
                        self.current_state = .AfterDOCTYPESystemIdentifier;
                        return;
                    }
                    if (char == 0) {
                        self.current_state = .DOCTYPESystemIdentifierDoubleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // abrupt-doctype-system-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        try self.current_token.DOCTYPE.system_ident.append(self.token_handler.allocator, char);
                        self.current_state = .DOCTYPESystemIdentifierDoubleQuoted;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .DOCTYPESystemIdentifierSingleQuoted => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '\'') {
                        self.current_state = .AfterDOCTYPESystemIdentifier;
                        return;
                    }
                    if (char == 0) {
                        self.current_state = .DOCTYPEPublicIdentifierSingleQuoted;
                        return;
                    }
                    if (char == '>') {
                        // abrupt-doctype-system-identifier parse error
                        self.current_token.DOCTYPE.force_quirks = true;
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        try self.current_token.DOCTYPE.system_ident.append(self.token_handler.allocator, char);
                        self.current_state = .DOCTYPEPublicIdentifierSingleQuoted;
                        return;
                    }
                } else {
                    // eof-in-doctype parse error
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .AfterDOCTYPESystemIdentifier => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        self.current_state = .AfterDOCTYPESystemIdentifier;
                        return;
                    }
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    } else {
                        // unexpected-character-after-doctype-system-identifier parse error
                        self.stream.reconsumeChar();
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    self.current_token.DOCTYPE.force_quirks = true;
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .BogusDOCTYPE => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |char| {
                    if (char == '>') {
                        try self.token_handler.enqueue(self.current_token);
                        self.current_state = .Data;
                        return;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        self.current_state = .BogusDOCTYPE;
                        return;
                    } else {
                        self.current_state = .BogusDOCTYPE;
                        return;
                    }
                } else {
                    try self.token_handler.enqueue(self.current_token);
                    try self.token_handler.enqueue(try self.token_handler.createEOF());
                    self.current_state = .EOF;
                    return;
                }
            },
            .CDATAsection => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // U+005D RIGHT SQUARE BRACKET (])
            // Switch to the CDATA section bracket state.
            // EOF
            // This is an eof-in-cdata parse error. Emit an end-of-file token.
            // Anything else
            // Emit the current input character as a character token.
            .CDATAsectionbracket => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // U+005D RIGHT SQUARE BRACKET (])
            // Switch to the CDATA section end state.
            // Anything else
            // Emit a U+005D RIGHT SQUARE BRACKET character token. Reconsume in the CDATA section state.
            .CDATAsectionEnd => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // U+005D RIGHT SQUARE BRACKET (])
            // Emit a U+005D RIGHT SQUARE BRACKET character token.
            // U+003E GREATER-THAN SIGN (>)
            // Switch to the data state.
            // Anything else
            // Emit two U+005D RIGHT SQUARE BRACKET character tokens. Reconsume in the CDATA section state.
            .CharacterReference => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // Set the temporary buffer to the empty string. Append a U+0026 AMPERSAND (&) character to the temporary buffer. Consume the next input character:
            // ASCII alphanumeric
            // Reconsume in the named character reference state.
            // U+0023 NUMBER SIGN (#)
            // Append the current input character to the temporary buffer. Switch to the numeric character reference state.
            // Anything else
            // Flush code points consumed as a character reference. Reconsume in the return state.
            .Namedcharacterreference => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // Consume the maximum number of characters possible, where the consumed characters are one of the identifiers in the first column of the named character references table. Append each character to the temporary buffer when it's consumed.
            // If there is a match
            // If the character reference was consumed as part of an attribute, and the last character matched is not a U+003B SEMICOLON character (;), and the next input character is either a U+003D EQUALS SIGN character (=) or an ASCII alphanumeric, then, for historical reasons, flush code points consumed as a character reference and switch to the return state.
            // Otherwise:
            // If the last character matched is not a U+003B SEMICOLON character (;), then this is a missing-semicolon-after-character-reference parse error.
            // Set the temporary buffer to the empty string. Append one or two characters corresponding to the character reference name (as given by the second column of the named character references table) to the temporary buffer.
            // Flush code points consumed as a character reference. Switch to the return state.
            // Otherwise
            // Flush code points consumed as a character reference. Switch to the ambiguous ampersand state.
            .Ambiguousampersand => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // ASCII alphanumeric
            // If the character reference was consumed as part of an attribute, then append the current input character to the current attribute's value. Otherwise, emit the current input character as a character token.
            // U+003B SEMICOLON (;)
            // This is an unknown-named-character-reference parse error. Reconsume in the return state.
            // Anything else
            // Reconsume in the return state.
            .Numericcharacterreference => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // U+0078 LATIN SMALL LETTER X
            // U+0058 LATIN CAPITAL LETTER X
            // Append the current input character to the temporary buffer. Switch to the hexadecimal character reference start state.
            // Anything else
            // Reconsume in the decimal character reference start state.
            .Hexadecimalcharacterreferencestart => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // ASCII hex digit
            // Reconsume in the hexadecimal character reference state.
            // Anything else
            // This is an absence-of-digits-in-numeric-character-reference parse error. Flush code points consumed as a character reference. Reconsume in the return state.
            .Decimalcharacterreferencestart => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // Consume the next input character:
            //
            // ASCII digit
            // Reconsume in the decimal character reference state.
            // Anything else
            // This is an absence-of-digits-in-numeric-character-reference parse error. Flush code points consumed as a character reference. Reconsume in the return state.
            .Hexadecimalcharacterreference => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // ASCII digit
            // Multiply the character reference code by 16. Add a numeric version of the current input character (subtract 0x0030 from the character's code point) to the character reference code.
            // ASCII upper hex digit
            // Multiply the character reference code by 16. Add a numeric version of the current input character as a hexadecimal digit (subtract 0x0037 from the character's code point) to the character reference code.
            // ASCII lower hex digit
            // Multiply the character reference code by 16. Add a numeric version of the current input character as a hexadecimal digit (subtract 0x0057 from the character's code point) to the character reference code.
            // U+003B SEMICOLON (;)
            // Switch to the numeric character reference end state.
            // Anything else
            // This is a missing-semicolon-after-character-reference parse error. Reconsume in the numeric character reference end state.
            .Decimalcharacterreference => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // ASCII digit
            // Multiply the character reference code by 10. Add a numeric version of the current input character (subtract 0x0030 from the character's code point) to the character reference code.
            // U+003B SEMICOLON (;)
            // Switch to the numeric character reference end state.
            // Anything else
            // This is a missing-semicolon-after-character-reference parse error. Reconsume in the numeric character reference end state.
            .NumericcharacterreferenceEnd => {
                self.current_input_character = self.stream.consumeChar();
                if (self.current_input_character) |_| {} else {}
            },
            // Check the character reference code:
            // If the number is 0x00, then this is a null-character-reference parse error. Set the character reference code to 0xFFFD.
            // If the number is greater than 0x10FFFF, then this is a character-reference-outside-unicode-range parse error. Set the character reference code to 0xFFFD.
            // If the number is a surrogate, then this is a surrogate-character-reference parse error. Set the character reference code to 0xFFFD.
            // If the number is a noncharacter, then this is a noncharacter-character-reference parse error.
            // If the number is 0x0D, or a control that's not ASCII whitespace, then this is a control-character-reference parse error. If the number is one of the numbers in the first column of the following table, then find the row with that number in the first column, and set the character reference code to the number in the second column of that row.
            .EOF => {
                return;
            },
        }
    }
};
