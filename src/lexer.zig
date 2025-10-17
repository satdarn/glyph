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
};

pub const HtmlLexer = struct {
    stream: InputStream,
    allocator: std.mem.Allocator,
    current_state: LexerStates = .Data,
    return_state: LexerStates = .Data,

    pub fn init(allocator: std.mem.Allocator, input_stream: InputStream) HtmlLexer {
        return .{ .stream = input_stream, .allocator = allocator };
    }

    pub fn run(self: *HtmlLexer) !void {
        var current_token: *Token = undefined;
        var current_input_character: ?u8 = undefined;
        var tokenHandler = try TokenHandler.init(self.allocator);
        defer tokenHandler.deinit();
        var tempBuffer: std.ArrayList(u8) = try std.ArrayList(u8).initCapacity(self.allocator, 10);
        defer tempBuffer.deinit(self.allocator);

        sw: switch (self.current_state) {
            .Data => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+0026 AMPERSAND (&)
                    if (char == '&') {
                        self.return_state = .Data;
                        continue :sw .CharacterReference;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .Tagopen;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        current_token = try tokenHandler.createCharacter(char);
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    // Anything else

                    current_token = try tokenHandler.createCharacter(char);
                    Token.emitToken(current_token);
                    continue :sw .Data;
                } else {
                    // EOF
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .RCDATA => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+0026 AMPERSAND (&)
                    if (char == '&') {
                        self.return_state = .RCDATA;
                        continue :sw .CharacterReference;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .RCDATALessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        Token.emitToken(try tokenHandler.createReplacement());
                    }
                    // Anything else
                    current_token = try tokenHandler.createCharacter(char);
                    Token.emitToken(current_token);
                    continue :sw .RCDATA;
                } else {
                    // EOF
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .RAWTEXT => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .RAWTEXTLessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        Token.emitToken(try tokenHandler.createReplacement());
                    }
                    // Anything else
                    current_token = try tokenHandler.createCharacter(char);
                    Token.emitToken(current_token);
                    continue :sw .RAWTEXT;
                } else {
                    // EOF
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .ScriptData => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .ScriptDataLessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        Token.emitToken(try tokenHandler.createReplacement());
                    }
                    // Anything else
                    current_token = try tokenHandler.createCharacter(char);
                    Token.emitToken(current_token);
                    continue :sw .ScriptData;
                } else {
                    // EOF
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .PLAINTEXT => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        Token.emitToken(try tokenHandler.createReplacement());
                    }
                    // Anything else
                    current_token = try tokenHandler.createCharacter(char);
                    Token.emitToken(current_token);
                    continue :sw .PLAINTEXT;
                } else {
                    // EOF
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },

            .Tagopen => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+0021 EXCLAMATION MARK (!)
                    if (char == '!') {
                        continue :sw .MarkupDeclarationOpen;
                    }
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        continue :sw .EndTagOpen;
                    }
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        current_token = try tokenHandler.createStartTag();
                        try current_token.Tag.tagName.append(tokenHandler.allocator, char);
                        continue :sw .TagName;
                    }
                    // U+003F QUESTION MARK (?)
                    if (char == '?') {
                        // unexpected-question-mark-instead-of-tag-name parse error
                        current_token = try tokenHandler.createComment(0);
                        self.stream.reconsumeChar();
                        continue :sw .BogusComment;
                    }
                    // Anything else
                    // invalid-first-character-of-tag-name parse error
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    self.stream.reconsumeChar();
                    continue :sw .Data;
                } else {
                    // EOF
                    // eof-before-tag-name parse error
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .EndTagOpen => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        current_token = try tokenHandler.createEndTag();
                        try current_token.Tag.tagName.append(tokenHandler.allocator, char);
                        continue :sw .TagName;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        // missing-end-tag-name parse error
                        continue :sw .Data;
                    } else {
                        // Anything else
                        // invalid-first-character-of-tag-name parse error
                        current_token = try tokenHandler.createComment(0);
                        self.stream.reconsumeChar();
                        continue :sw .BogusComment;
                    }
                } else {
                    // EOF
                    // eof-before-tag-name parse error
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .TagName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+0009 CHARACTER TABULATION (tab) U+000A LINE FEED (LF) U+000C FORM FEED (FF) U+0020 SPACE
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeAttributeName;
                    }
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        continue :sw .SelfClosingStartTag;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    // ASCII upper alpha
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        try current_token.Tag.tagName.append(tokenHandler.allocator, std.ascii.toLower(char));
                        continue :sw .TagName;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        continue :sw .TagName;
                    } else {
                        // Anything else
                        try current_token.Tag.tagName.append(tokenHandler.allocator, char);
                        continue :sw .TagName;
                    }
                } else {
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .RCDATALessThanSign => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        tempBuffer.clearAndFree(self.allocator);
                        continue :sw .RCADATAEndTagopen;
                    } else {
                        // Anything else
                        Token.emitToken(try tokenHandler.createCharacter('>'));
                        self.stream.reconsumeChar();
                        continue :sw .RCDATA;
                    }
                } else {
                    // EOF is Anything else
                    Token.emitToken(try tokenHandler.createCharacter('>'));
                    self.stream.reconsumeChar();
                    continue :sw .RCDATA;
                }
            },
            .RCADATAEndTagopen => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        current_token = try tokenHandler.createEndTag();
                        self.stream.reconsumeChar();
                        continue :sw .RCADATAEndTagName;
                    } else {
                        // Anything else
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        Token.emitToken(try tokenHandler.createCharacter('/'));
                        self.stream.reconsumeChar();
                        continue :sw .RCDATA;
                    }
                } else {
                    // EOF is Anything else
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    Token.emitToken(try tokenHandler.createCharacter('/'));
                    self.stream.reconsumeChar();
                    continue :sw .RCDATA;
                }
            },
            .RCADATAEndTagName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
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
                            // Append the current input character to the current tag token's tag name.
                            // Append the current input character to the temporary buffer.
                        }
                    }
                    // Anything else
                    else {
                        // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                        // and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer).
                        // Reconsume in the RCDATA state.

                    }
                }
                // EOF is Anything else
                else {
                    // Emit a U+003C LESS-THAN SIGN character token, a U+002F SOLIDUS character token,
                    // and a character token for each of the characters in the temporary buffer (in the order they were added to the buffer).
                    // Reconsume in the RCDATA state.
                }
            },
            .RAWTEXTLessThanSign => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        tempBuffer.clearAndFree(self.allocator);
                        continue :sw .RAWTEXTEndTagOpen;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        self.stream.reconsumeChar();
                        continue :sw .RAWTEXT;
                    }
                }
                // EOF is Anything else
                else {}
            },
            .RAWTEXTEndTagOpen => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        current_token = try tokenHandler.createEndTag();
                        try current_token.Tag.tagName.append(tokenHandler.allocator, std.ascii.toLower(char));
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        self.stream.reconsumeChar();
                        continue :sw .RAWTEXT;
                    }
                }
                // EOF is Anything else
                else {
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    self.stream.reconsumeChar();
                    continue :sw .RAWTEXT;
                }
            },
            .RAWTEXTEndTagName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
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
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        tempBuffer.clearAndFree(self.allocator);
                        continue :sw .ScriptDataEndTagOpen;
                    }
                    // U+0021 EXCLAMATION MARK (!)
                    if (char == '!') {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        Token.emitToken(try tokenHandler.createCharacter('!'));
                        continue :sw .ScriptDataEscapeStart;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        self.stream.reconsumeChar();
                        continue :sw .ScriptData;
                    }
                }
                // EOF is Anything else
                else {
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    self.stream.reconsumeChar();
                    continue :sw .ScriptData;
                }
            },
            .ScriptDataEndTagOpen => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        current_token = try tokenHandler.createEndTag();
                        try current_token.Tag.tagName.append(tokenHandler.allocator, std.ascii.toLower(char));
                        continue :sw .ScriptDataEndTagName;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        Token.emitToken(try tokenHandler.createCharacter('/'));
                        continue :sw .ScriptData;
                    }
                }
                // EOF is Anything else
                else {
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    Token.emitToken(try tokenHandler.createCharacter('/'));
                    continue :sw .ScriptData;
                }
            },
            .ScriptDataEndTagName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
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
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('_'));
                        continue :sw .ScriptDataEscapeStartDash;
                    }
                    // Anything else
                    else {
                        self.stream.reconsumeChar();
                        continue :sw .ScriptData;
                    }
                }
                // EOF is Anything else
                else {
                    self.stream.reconsumeChar();
                    continue :sw .ScriptData;
                }
            },
            .ScriptDataEscapeStartDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('_'));
                        continue :sw .ScriptDataEscapedDashDash;
                    }
                    // Anything else
                    else {
                        self.stream.reconsumeChar();
                        continue :sw .ScriptData;
                    }
                }
                // EOF is Anything else
                else {
                    self.stream.reconsumeChar();
                    continue :sw .ScriptData;
                }
            },
            .ScriptDataEscaped => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('_'));
                        continue :sw .ScriptDataEscapeStartDash;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .ScriptDataEscapedLessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        Token.emitToken(try tokenHandler.createReplacement());
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter(char));
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    Token.emitToken(try tokenHandler.createEOF());
                }
            },
            .ScriptDataEscapedDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('_'));
                        continue :sw .ScriptDataEscapedDashDash;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .ScriptDataEscapedLessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error. Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        Token.emitToken(try tokenHandler.createReplacement());
                        continue :sw .ScriptDataEscapedDash;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter(char));
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    Token.emitToken(try tokenHandler.createEOF());
                }
            },
            .ScriptDataEscapedDashDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('-'));
                        continue :sw .ScriptDataEscapedDashDash;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .ScriptDataEscapedLessThanSign;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        Token.emitToken(try tokenHandler.createCharacter('>'));
                        continue :sw .ScriptData;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // Emit a U+FFFD REPLACEMENT CHARACTER character token.
                        Token.emitToken(try tokenHandler.createReplacement());
                        Token.emitToken(try tokenHandler.createReplacement());
                        continue :sw .ScriptDataEscaped;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter(char));
                        continue :sw .ScriptDataEscaped;
                    }
                }
                // EOF
                else {
                    // eof-in-script-html-comment-like-text parse error
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .ScriptDataEscapedLessThanSign => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        tempBuffer.clearAndFree(self.allocator);
                        continue :sw .ScriptDataEscapedEndTagOpen;
                    }
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        tempBuffer.clearAndFree(self.allocator);
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        self.stream.reconsumeChar();
                        continue :sw .ScriptDataDoubleEscapeStart;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        continue :sw .ScriptDataEscaped;
                    }
                }
                // EOF is Anything else
                else {
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    continue :sw .ScriptDataEscaped;
                }
            },
            .ScriptDataEscapedEndTagOpen => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isAlphabetic(char)) {
                        current_token = try tokenHandler.createEndTag();
                        try current_token.Tag.tagName.append(tokenHandler.allocator, char);
                        continue :sw .ScriptDataEscapedEndTagName;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createComment('<'));
                        Token.emitToken(try tokenHandler.createComment('/'));
                        continue :sw .ScriptDataEscaped;
                    }
                }
                // EOF is Anything else
                else {
                    Token.emitToken(try tokenHandler.createComment('<'));
                    Token.emitToken(try tokenHandler.createComment('/'));
                    continue :sw .ScriptDataEscaped;
                }
            },
            .ScriptDataEscapedEndTagName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
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
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char) or char == '/' or char == '>') {
                        // If the temporary buffer is the string "script",
                        // then switch to the script data double escaped state.
                        if (std.mem.eql(u8, tempBuffer.items, "script")) {
                            continue :sw .ScriptDataDoubleEscaped;
                        }
                        // Otherwise, switch to the script data escaped state.
                        // Emit the current input character as a character token.
                        Token.emitToken(try tokenHandler.createCharacter(char));
                        continue :sw .ScriptDataEscaped;
                    }
                } else {}
            },
            .ScriptDataDoubleEscaped => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('-'));
                        continue :sw .ScriptDataDoubleEscapedDash;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        continue :sw .ScriptDataDoubleEscapedLessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error.
                        Token.emitToken(try tokenHandler.createReplacement());
                        continue :sw .ScriptDataDoubleEscaped;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter(char));
                        continue :sw .ScriptDataDoubleEscaped;
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .ScriptDataDoubleEscapedDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('-'));
                        continue :sw .ScriptDataDoubleEscapedDashDash;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        continue :sw .ScriptDataDoubleEscapedLessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error.
                        Token.emitToken(try tokenHandler.createReplacement());
                        continue :sw .ScriptDataDoubleEscaped;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter(char));
                        continue :sw .ScriptDataDoubleEscaped;
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .ScriptDataDoubleEscapedDashDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('-'));
                        continue :sw .ScriptDataDoubleEscapedDashDash;
                    }
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        continue :sw .ScriptDataDoubleEscapedLessThanSign;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    // Switch to the script data state. Emit a U+003E GREATER-THAN SIGN character token.
                    if (char == '>') {
                        Token.emitToken(try tokenHandler.createCharacter('>'));
                        continue :sw .ScriptData;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // This is an unexpected-null-character parse error.
                        Token.emitToken(try tokenHandler.createReplacement());
                        continue :sw .ScriptDataDoubleEscaped;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter(char));
                        continue :sw .ScriptDataDoubleEscaped;
                    }
                }
                // EOF
                else {
                    // This is an eof-in-script-html-comment-like-text parse error.
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .ScriptDataDoubleEscapedLessThanSign => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        tempBuffer.clearAndFree(self.allocator);
                        Token.emitToken(try tokenHandler.createCharacter('/'));
                        continue :sw .ScriptDataDoubleEscaped;
                    }
                    // Anything else
                    else {
                        self.stream.reconsumeChar();
                        continue :sw .ScriptDataDoubleEscaped;
                    }
                }
                // EOF is Anything else
                else {
                    self.stream.reconsumeChar();
                    continue :sw .ScriptDataDoubleEscaped;
                }
            },
            .ScriptDataDoubleEscapeEnd => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char) or char == '/' or char == '>') {
                        if (std.mem.eql(u8, tempBuffer.items, "script")) {
                            continue :sw .ScriptDataEscaped;
                        } else {
                            Token.emitToken(try tokenHandler.createCharacter(char));
                            continue :sw .ScriptDataDoubleEscaped;
                        }
                    }
                    if (std.ascii.isAlphabetic(char)) {
                        // ASCII upper alpha
                        if (std.ascii.isUpper(char)) {
                            Token.emitToken(try tokenHandler.createCharacter(std.ascii.toLower(char)));
                            continue :sw .ScriptDataDoubleEscaped;
                        }
                        // ASCII lower alpha
                        if (std.ascii.isLower(char)) {
                            // Append the current input character to the temporary buffer. Emit the current input character as a character token.
                            Token.emitToken(try tokenHandler.createCharacter(char));
                        }
                        // Anything else
                        else {
                            self.stream.reconsumeChar();
                            continue :sw .ScriptDataDoubleEscaped;
                        }
                    }
                }
                // Eof is Anything else
                else {
                    self.stream.reconsumeChar();
                    continue :sw .ScriptDataDoubleEscaped;
                }
            },
            .BeforeAttributeName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeAttributeName;
                    }
                    // U+002F SOLIDUS (/) and U+003E GREATER-THAN SIGN (>)
                    if (char == '/' and char == '>') {
                        self.stream.reconsumeChar();
                        continue :sw .AttributeName;
                    }
                    // U+003D EQUALS SIGN (=)
                    if (char == '=') {
                        // unexpected-equals-sign-before-attribute-name parse error
                        try current_token.Tag.attributes.addAttribute();
                        try current_token.Tag.attributes.appendAttrName(char);
                        continue :sw .AttributeName;
                    }
                    // Anything else
                    else {
                        try current_token.Tag.attributes.addAttribute();
                        self.stream.reconsumeChar();
                        continue :sw .AttributeName;
                    }
                }
                // EOF
                else {
                    self.stream.reconsumeChar();
                    continue :sw .AttributeName;
                }
            },
            .AttributeName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char) or char == '/' or char == '>') {
                        self.stream.reconsumeChar();
                        continue :sw .AfterAttributeName;
                    }
                    if (char == '=') {
                        continue :sw .BeforeAttributeValue;
                    }
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        try current_token.Tag.attributes.appendAttrName(std.ascii.toLower(char));
                        continue :sw .AttributeName;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's name.
                        continue :sw .AttributeName;
                    }
                    if (char == '\"' or char == '\'' or char == '<') {
                        // unexpected-character-in-attribute-name parse error
                        try current_token.Tag.attributes.appendAttrName(char);
                        continue :sw .AttributeName;
                    } else {
                        try current_token.Tag.attributes.appendAttrName(char);
                        continue :sw .AttributeName;
                    }
                } else {
                    self.stream.reconsumeChar();
                    continue :sw .AfterAttributeName;
                }
            },
            .AfterAttributeName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .AfterAttributeName;
                    }
                    if (char == '/') {
                        continue :sw .SelfClosingStartTag;
                    }
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        try current_token.Tag.attributes.appendAttrName(char);
                        continue :sw .AttributeName;
                    }
                } else {
                    // eof-in-tag parse error
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .BeforeAttributeValue => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeAttributeValue;
                    }
                    if (char == '\"') {
                        continue :sw .AttributeValueDoubleQuoted;
                    }
                    if (char == '\'') {
                        continue :sw .AttributeValueSingleQuoted;
                    }
                    if (char == '>') {
                        // missing-attribute-value parse error
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        self.stream.reconsumeChar();
                        continue :sw .AttributeValueUnquoted;
                    }
                } else {
                    self.stream.reconsumeChar();
                    continue :sw .AttributeValueUnquoted;
                }
            },

            .AttributeValueDoubleQuoted => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '\"') {
                        continue :sw .AfterAttributeValueQuoted;
                    }
                    if (char == '&') {
                        self.return_state = .AttributeValueDoubleQuoted;
                        continue :sw .CharacterReference;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.
                        continue :sw .AttributeValueDoubleQuoted;
                    } else {
                        try current_token.Tag.attributes.appendAttrData(char);
                        continue :sw .AttributeValueDoubleQuoted;
                    }
                } else {
                    // eof-in-tag parse error
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .AttributeValueSingleQuoted => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '\'') {
                        continue :sw .AfterAttributeValueQuoted;
                    }
                    if (char == '&') {
                        self.return_state = .AttributeValueSingleQuoted;
                        continue :sw .CharacterReference;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.
                        continue :sw .AttributeValueSingleQuoted;
                    } else {
                        try current_token.Tag.attributes.appendAttrData(char);
                        continue :sw .AttributeValueSingleQuoted;
                    }
                } else {
                    // eof-in-tag parse error
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .AttributeValueUnquoted => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeAttributeName;
                    }
                    if (char == '&') {
                        self.return_state = .AttributeValueUnquoted;
                        continue :sw .CharacterReference;
                    }
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current attribute's value.
                        continue :sw .AttributeValueUnquoted;
                    }
                    if (char == '\"' or char == '\'' or char == '<' or char == '=' or char == '`') {
                        // unexpected-character-in-unquoted-attribute-value parse error
                        // Treat it as per the "anything else" entry below.
                        try current_token.Tag.attributes.appendAttrData(char);
                        continue :sw .AttributeValueUnquoted;
                    } else {
                        try current_token.Tag.attributes.appendAttrData(char);
                        continue :sw .AttributeValueUnquoted;
                    }
                } else {
                    // eof-in-tag parse error
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .AfterAttributeValueQuoted => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeAttributeName;
                    }
                    if (char == '/') {
                        continue :sw .SelfClosingStartTag;
                    }
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        // missing-whitespace-between-attributes parse error
                        self.stream.reconsumeChar();
                        continue :sw .BeforeAttributeName;
                    }
                } else {
                    // eof-in-tag parse error
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .SelfClosingStartTag => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '>') {
                        current_token.Tag.selfClosing = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        // unexpected-solidus-in-tag parse error
                        self.stream.reconsumeChar();
                        continue :sw .BeforeAttributeName;
                    }
                } else {
                    // eof-in-tag parse error
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .BogusComment => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '>') {
                        current_token.Tag.selfClosing = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        continue :sw .BogusComment;
                    } else {
                        try current_token.Comment.data.append(tokenHandler.allocator, char);
                    }
                } else {
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                }
            },

            .MarkupDeclarationOpen => {
                if (self.stream.consumeString("DOCTYPE")) {
                    continue :sw .DOCTYPE;
                }
                if (self.stream.consumeString("--")) {
                    current_token = try tokenHandler.createComment(0);
                    continue :sw .CommentStart;
                } else {
                    current_token = try tokenHandler.createComment(0);
                    continue :sw .BogusComment;
                }
            },
            .CommentStart => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '-') {
                        continue :sw .CommentStartDash;
                    }
                    if (char == '>') {
                        // abrupt-closing-of-empty-comment parse error
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        self.stream.reconsumeChar();
                        continue :sw .Comment;
                    }
                } else {
                    self.stream.reconsumeChar();
                    continue :sw .Comment;
                }
            },
            .CommentStartDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '-') {
                        continue :sw .CommentEnd;
                    }
                    if (char == '>') {
                        // abrupt-closing-of-empty-comment parse error
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        self.stream.reconsumeChar();
                        continue :sw .Comment;
                    }
                } else {
                    // eof-in-comment parse error
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },

            .Comment => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '<') {
                        try current_token.Comment.data.append(tokenHandler.allocator, char);
                        continue :sw .CommentLessThanSign;
                    }
                    if (char == '-') {
                        continue :sw .CommentEndDash;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        continue :sw .Comment;
                    }
                } else {
                    // eof-in-comment parse error
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .CommentLessThanSign => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '!') {
                        try current_token.Comment.data.append(tokenHandler.allocator, char);
                        continue :sw .CommentLessThanSignBang;
                    }
                    if (char == '<') {
                        try current_token.Comment.data.append(tokenHandler.allocator, char);
                        continue :sw .CommentLessThanSign;
                    } else {
                        self.stream.reconsumeChar();
                        continue :sw .Comment;
                    }
                } else {
                    self.stream.reconsumeChar();
                    continue :sw .Comment;
                }
            },
            .CommentLessThanSignBang => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '-') {
                        continue :sw .CommentLessThanSignBangDash;
                    } else {
                        self.stream.reconsumeChar();
                        continue :sw .Comment;
                    }
                } else {
                    self.stream.reconsumeChar();
                    continue :sw .Comment;
                }
            },
            .CommentLessThanSignBangDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '-') {
                        continue :sw .CommentLessThanSignBangDashDash;
                    } else {
                        self.stream.reconsumeChar();
                        continue :sw .CommentEndDash;
                    }
                } else {
                    self.stream.reconsumeChar();
                    continue :sw .CommentEndDash;
                }
            },
            .CommentLessThanSignBangDashDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '>') {
                        self.stream.reconsumeChar();
                        continue :sw .CommentEnd;
                    } else {
                        // nested-comment parse error
                        self.stream.reconsumeChar();
                        continue :sw .CommentEnd;
                    }
                } else {
                    self.stream.reconsumeChar();
                    continue :sw .CommentEnd;
                }
            },
            .CommentEndDash => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '-') {
                        continue :sw .CommentEnd;
                    } else {
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        self.stream.reconsumeChar();
                        continue :sw .Comment;
                    }
                } else {
                    // eof-in-comment parse error
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .CommentEnd => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    if (char == '!') {
                        continue :sw .CommentEndBang;
                    }
                    if (char == '-') {
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        continue :sw .CommentEnd;
                    } else {
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        continue :sw .Comment;
                    }
                } else {
                    // eof-in-comment parse error
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .CommentEndBang => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '-') {
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        try current_token.Comment.data.append(tokenHandler.allocator, '!');
                        continue :sw .CommentEndDash;
                    }
                    if (char == '>') {
                        // incorrectly-closed-comment parse error
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        try current_token.Comment.data.append(tokenHandler.allocator, '-');
                        try current_token.Comment.data.append(tokenHandler.allocator, '!');
                        continue :sw .Comment;
                    }
                } else {
                    // eof-in-comment parse error
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            // Anything else
            // Append two U+002D HYPHEN-MINUS characters (-) and a U+0021 EXCLAMATION MARK character (!) to the comment token's data. Reconsume in the comment state.
            .DOCTYPE => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeDOCTYPEName;
                    }
                    if (char == '>') {
                        self.stream.reconsumeChar();
                        continue :sw .BeforeDOCTYPEName;
                    } else {
                        // missing-whitespace-before-doctype-name parse error
                        self.stream.reconsumeChar();
                        continue :sw .BeforeDOCTYPEName;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token = try tokenHandler.createDOCTYPEToken();
                    current_token.DOCTYPE.forceQuirks = false;
                    Token.emitToken(current_token);
                }
            },
            .BeforeDOCTYPEName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeDOCTYPEName;
                    }
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        current_token = try tokenHandler.createDOCTYPEToken();
                        try current_token.DOCTYPE.name.append(tokenHandler.allocator, std.ascii.toLower(char));
                        continue :sw .DOCTYPEName;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        current_token = try tokenHandler.createDOCTYPEToken();
                        // Set the token's name to a U+FFFD REPLACEMENT CHARACTER character
                        continue :sw .DOCTYPEName;
                    }
                    if (char == '>') {
                        current_token = try tokenHandler.createDOCTYPEToken();
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        current_token = try tokenHandler.createDOCTYPEToken();
                        try current_token.DOCTYPE.name.append(tokenHandler.allocator, char);
                        continue :sw .DOCTYPEName;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token = try tokenHandler.createDOCTYPEToken();
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .DOCTYPEName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .AfterDOCTYPEName;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    // ASCII upper alpha
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        try current_token.DOCTYPE.name.append(tokenHandler.allocator, std.ascii.toLower(char));
                        continue :sw .DOCTYPEName;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        continue :sw .DOCTYPEName;
                    }
                    // Anything else
                    else {
                        try current_token.DOCTYPE.name.append(tokenHandler.allocator, char);
                        continue :sw .DOCTYPEName;
                    }
                }
                // EOF
                else {
                    //eof-in-doctype parse error
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .AfterDOCTYPEName => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .AfterDOCTYPEName;
                    }
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    self.stream.case_sensitive = false;
                    self.stream.reconsumeChar();
                    if (self.stream.consumeString("public")) {
                        continue :sw .AfterDOCTYPEPublicKeyword;
                    }
                    if (self.stream.consumeString("system")) {
                        continue :sw .AfterDOCTYPESystemKeyword;
                    } else {
                        // invalid-character-sequence-after-doctype-name parse error
                        self.stream.case_sensitive = true;
                        current_token.DOCTYPE.forceQuirks = true;
                        self.stream.reconsumeChar();
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .AfterDOCTYPEPublicKeyword => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .AfterDOCTYPEPublicKeyword;
                    }
                    if (char == '"') {
                        current_token.DOCTYPE.publicIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPEPublicIdentifierDoubleQuoted;
                    }
                    if (char == '\'') {
                        current_token.DOCTYPE.publicIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPEPublicIdentifierSingleQuoted;
                    }
                    if (char == '>') {
                        // missing-doctype-public-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        // missing-quote-before-doctype-public-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        self.stream.reconsumeChar();
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .BeforeDOCTYPEPublicIdentifier => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeDOCTYPEPublicIdentifier;
                    }
                    if (char == '"') {
                        current_token.DOCTYPE.publicIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPEPublicIdentifierDoubleQuoted;
                    }
                    if (char == '\'') {
                        current_token.DOCTYPE.publicIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPEPublicIdentifierSingleQuoted;
                    }
                    if (char == '>') {
                        // missing-doctype-public-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        // missing-quote-before-doctype-public-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        self.stream.reconsumeChar();
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .DOCTYPEPublicIdentifierDoubleQuoted => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '"') {
                        continue :sw .AfterDOCTYPEPublicIdentifier;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        continue :sw .DOCTYPEPublicIdentifierDoubleQuoted;
                    }
                    if (char == '>') {
                        // abrupt-doctype-public-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        try current_token.DOCTYPE.publicIdent.append(tokenHandler.allocator, char);
                        continue :sw .DOCTYPEPublicIdentifierDoubleQuoted;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .DOCTYPEPublicIdentifierSingleQuoted => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '\'') {
                        continue :sw .AfterDOCTYPEPublicIdentifier;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        continue :sw .DOCTYPEPublicIdentifierSingleQuoted;
                    }
                    if (char == '>') {
                        // abrupt-doctype-public-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        try current_token.DOCTYPE.publicIdent.append(tokenHandler.allocator, char);
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .AfterDOCTYPEPublicIdentifier => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BetweenDOCTYPEPublicAndSystemIdentifiers;
                    }
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    if (char == '"') {
                        // missing-whitespace-between-doctype-public-and-system-identifiers parse error
                        current_token.DOCTYPE.systemIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPESystemIdentifierDoubleQuoted;
                    }
                    if (char == '\'') {
                        // missing-whitespace-between-doctype-public-and-system-identifiers parse error
                        current_token.DOCTYPE.systemIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPESystemIdentifierSingleQuoted;
                    } else {
                        // missing-quote-before-doctype-system-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        self.stream.reconsumeChar();
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .BetweenDOCTYPEPublicAndSystemIdentifiers => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BetweenDOCTYPEPublicAndSystemIdentifiers;
                    }
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    if (char == '"') {
                        current_token.DOCTYPE.systemIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPESystemIdentifierDoubleQuoted;
                    }
                    if (char == '\'') {
                        current_token.DOCTYPE.systemIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPESystemIdentifierSingleQuoted;
                    } else {
                        // missing-quote-before-doctype-system-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        self.stream.reconsumeChar();
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .AfterDOCTYPESystemKeyword => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeDOCTYPESystemIdentifier;
                    }
                    if (char == '"') {
                        // missing-whitespace-after-doctype-system-keyword parse error
                        current_token.DOCTYPE.systemIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPESystemIdentifierDoubleQuoted;
                    }
                    if (char == '\'') {
                        // missing-whitespace-after-doctype-system-keyword parse error
                        current_token.DOCTYPE.systemIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPEPublicIdentifierSingleQuoted;
                    }
                    if (char == '>') {
                        // missing-doctype-system-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        // missing-quote-before-doctype-system-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        self.stream.reconsumeChar();
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .BeforeDOCTYPESystemIdentifier => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeDOCTYPESystemIdentifier;
                    }
                    if (char == '"') {
                        current_token.DOCTYPE.systemIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPESystemIdentifierDoubleQuoted;
                    }
                    if (char == '\'') {
                        current_token.DOCTYPE.systemIdent.clearAndFree(tokenHandler.allocator);
                        continue :sw .DOCTYPESystemIdentifierSingleQuoted;
                    }
                    if (char == '>') {
                        // missing-doctype-system-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        // missing-quote-before-doctype-system-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        self.stream.reconsumeChar();
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .DOCTYPESystemIdentifierDoubleQuoted => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '"') {
                        continue :sw .AfterDOCTYPESystemIdentifier;
                    }
                    if (char == 0) {
                        continue :sw .DOCTYPESystemIdentifierDoubleQuoted;
                    }
                    if (char == '>') {
                        // abrupt-doctype-system-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        try current_token.DOCTYPE.systemIdent.append(tokenHandler.allocator, char);
                        continue :sw .DOCTYPESystemIdentifierDoubleQuoted;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .DOCTYPESystemIdentifierSingleQuoted => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '\'') {
                        continue :sw .AfterDOCTYPESystemIdentifier;
                    }
                    if (char == 0) {
                        continue :sw .DOCTYPEPublicIdentifierSingleQuoted;
                    }
                    if (char == '>') {
                        // abrupt-doctype-system-identifier parse error
                        current_token.DOCTYPE.forceQuirks = true;
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        try current_token.DOCTYPE.systemIdent.append(tokenHandler.allocator, char);
                        continue :sw .DOCTYPEPublicIdentifierSingleQuoted;
                    }
                } else {
                    // eof-in-doctype parse error
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .AfterDOCTYPESystemIdentifier => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .AfterDOCTYPESystemIdentifier;
                    }
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    } else {
                        // unexpected-character-after-doctype-system-identifier parse error
                        self.stream.reconsumeChar();
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    current_token.DOCTYPE.forceQuirks = true;
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .BogusDOCTYPE => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '>') {
                        Token.emitToken(current_token);
                        continue :sw .Data;
                    }
                    if (char == 0) {
                        // unexpected-null-character parse error
                        continue :sw .BogusDOCTYPE;
                    } else {
                        continue :sw .BogusDOCTYPE;
                    }
                } else {
                    Token.emitToken(current_token);
                    Token.emitToken(try tokenHandler.createEOF());
                    break :sw;
                }
            },
            .CDATAsection => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // U+005D RIGHT SQUARE BRACKET (])
            // Switch to the CDATA section bracket state.
            // EOF
            // This is an eof-in-cdata parse error. Emit an end-of-file token.
            // Anything else
            // Emit the current input character as a character token.
            .CDATAsectionbracket => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // U+005D RIGHT SQUARE BRACKET (])
            // Switch to the CDATA section end state.
            // Anything else
            // Emit a U+005D RIGHT SQUARE BRACKET character token. Reconsume in the CDATA section state.
            .CDATAsectionEnd => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // U+005D RIGHT SQUARE BRACKET (])
            // Emit a U+005D RIGHT SQUARE BRACKET character token.
            // U+003E GREATER-THAN SIGN (>)
            // Switch to the data state.
            // Anything else
            // Emit two U+005D RIGHT SQUARE BRACKET character tokens. Reconsume in the CDATA section state.
            .CharacterReference => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // Set the temporary buffer to the empty string. Append a U+0026 AMPERSAND (&) character to the temporary buffer. Consume the next input character:
            // ASCII alphanumeric
            // Reconsume in the named character reference state.
            // U+0023 NUMBER SIGN (#)
            // Append the current input character to the temporary buffer. Switch to the numeric character reference state.
            // Anything else
            // Flush code points consumed as a character reference. Reconsume in the return state.
            .Namedcharacterreference => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
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
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // ASCII alphanumeric
            // If the character reference was consumed as part of an attribute, then append the current input character to the current attribute's value. Otherwise, emit the current input character as a character token.
            // U+003B SEMICOLON (;)
            // This is an unknown-named-character-reference parse error. Reconsume in the return state.
            // Anything else
            // Reconsume in the return state.
            .Numericcharacterreference => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // U+0078 LATIN SMALL LETTER X
            // U+0058 LATIN CAPITAL LETTER X
            // Append the current input character to the temporary buffer. Switch to the hexadecimal character reference start state.
            // Anything else
            // Reconsume in the decimal character reference start state.
            .Hexadecimalcharacterreferencestart => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // ASCII hex digit
            // Reconsume in the hexadecimal character reference state.
            // Anything else
            // This is an absence-of-digits-in-numeric-character-reference parse error. Flush code points consumed as a character reference. Reconsume in the return state.
            .Decimalcharacterreferencestart => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // Consume the next input character:
            //
            // ASCII digit
            // Reconsume in the decimal character reference state.
            // Anything else
            // This is an absence-of-digits-in-numeric-character-reference parse error. Flush code points consumed as a character reference. Reconsume in the return state.
            .Hexadecimalcharacterreference => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
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
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // ASCII digit
            // Multiply the character reference code by 10. Add a numeric version of the current input character (subtract 0x0030 from the character's code point) to the character reference code.
            // U+003B SEMICOLON (;)
            // Switch to the numeric character reference end state.
            // Anything else
            // This is a missing-semicolon-after-character-reference parse error. Reconsume in the numeric character reference end state.
            .NumericcharacterreferenceEnd => {
                current_input_character = self.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            // Check the character reference code:
            // If the number is 0x00, then this is a null-character-reference parse error. Set the character reference code to 0xFFFD.
            // If the number is greater than 0x10FFFF, then this is a character-reference-outside-unicode-range parse error. Set the character reference code to 0xFFFD.
            // If the number is a surrogate, then this is a surrogate-character-reference parse error. Set the character reference code to 0xFFFD.
            // If the number is a noncharacter, then this is a noncharacter-character-reference parse error.
            // If the number is 0x0D, or a control that's not ASCII whitespace, then this is a control-character-reference parse error. If the number is one of the numbers in the first column of the following table, then find the row with that number in the first column, and set the character reference code to the number in the second column of that row.

        }
    }
};
