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
    ScriptDataDoubleEscapestart,
    ScriptDataDoubleEscaped,
    ScriptDataDoubleEscapedDash,
    ScriptDataDoubleEscapedDashDash,
    ScriptDataDoubleEscapedLessThanSign,
    ScriptDataDoubleEscapeEnd,
    BeforeAttributeName,
    AttributeName,
    AfterattributeName,
    Beforeattributevalue,
    Attributevaluedoublequoted,
    Attributevaluesinglequoted,
    Attributevalueunquoted,
    Afterattributevaluequoted,
    SelfClosingStartTag,
    BogusComment,
    MarkupDeclarationOpen,
    Commentstart,
    CommentstartDash,
    Comment,
    CommentLessThanSign,
    CommentLessThanSignbang,
    CommentLessThanSignbangDash,
    CommentLessThanSignbangDashDash,
    CommentEndDash,
    CommentEnd,
    CommentEndbang,
    DOCTYPE,
    BeforeDOCTYPEName,
    DOCTYPEName,
    AfterDOCTYPEName,
    AfterDOCTYPEpublickeyword,
    BeforeDOCTYPEpublicidentifier,
    DOCTYPEpublicidentifierdoublequoted,
    DOCTYPEpublicidentifiersinglequoted,
    AfterDOCTYPEpublicidentifier,
    BetweenDOCTYPEpublicandsystemidentifiers,
    AfterDOCTYPEsystemkeyword,
    BeforeDOCTYPEsystemidentifier,
    DOCTYPEsystemidentifierdoublequoted,
    DOCTYPEsystemidentifiersinglequoted,
    AfterDOCTYPEsystemidentifier,
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

    pub fn run(lexer: *HtmlLexer) !void {
        var current_token: *Token = undefined;
        var current_input_character: ?u8 = undefined;
        var tokenHandler = try TokenHandler.init(lexer.allocator);
        defer tokenHandler.deinit();
        var tempBuffer: [1024:0]u8 = undefined;
        sw: switch (lexer.current_state) {
            .Data => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+0026 AMPERSAND (&)
                    if (char == '&') {
                        lexer.return_state = .Data;
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+0026 AMPERSAND (&)
                    if (char == '&') {
                        lexer.return_state = .RCDATA;
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .RAWTEXTLessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+003C LESS-THAN SIGN (<)
                    if (char == '<') {
                        continue :sw .ScriptDataLessThanSign;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error
                        // #TODO: Emit a U+FFFD REPLACEMENT CHARACTER character token.
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
                current_input_character = lexer.stream.consumeChar();
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
                        lexer.stream.reconsumeChar();
                        continue :sw .BogusComment;
                    }
                    // Anything else
                    // invalid-first-character-of-tag-name parse error
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    lexer.stream.reconsumeChar();
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
                current_input_character = lexer.stream.consumeChar();
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
                        lexer.stream.reconsumeChar();
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
                current_input_character = lexer.stream.consumeChar();
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
                        // unexpected-null-character parse error.
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current tag token's tag name
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        tempBuffer[0] = 0;
                        continue :sw .RCADATAEndTagopen;
                    } else {
                        // Anything else
                        Token.emitToken(try tokenHandler.createCharacter('>'));
                        lexer.stream.reconsumeChar();
                        continue :sw .RCDATA;
                    }
                } else {
                    // EOF is Anything else
                    Token.emitToken(try tokenHandler.createCharacter('>'));
                    lexer.stream.reconsumeChar();
                    continue :sw .RCDATA;
                }
            },
            .RCADATAEndTagopen => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        current_token = try tokenHandler.createEndTag();
                        lexer.stream.reconsumeChar();
                        continue :sw .RCADATAEndTagName;
                    } else {
                        // Anything else
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        Token.emitToken(try tokenHandler.createCharacter('/'));
                        lexer.stream.reconsumeChar();
                        continue :sw .RCDATA;
                    }
                } else {
                    // EOF is Anything else
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    Token.emitToken(try tokenHandler.createCharacter('/'));
                    lexer.stream.reconsumeChar();
                    continue :sw .RCDATA;
                }
            },
            .RCADATAEndTagName => {
                current_input_character = lexer.stream.consumeChar();
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        tempBuffer[0] = 0;
                        continue :sw .RAWTEXTEndTagOpen;
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        lexer.stream.reconsumeChar();
                        continue :sw .RAWTEXT;
                    }
                }
                // EOF is Anything else
                else {}
            },
            .RAWTEXTEndTagOpen => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        current_token = try tokenHandler.createEndTag();
                        try current_token.Tag.tagName.append(tokenHandler.allocator, std.ascii.toLower(char));
                    }
                    // Anything else
                    else {
                        Token.emitToken(try tokenHandler.createCharacter('<'));
                        lexer.stream.reconsumeChar();
                        continue :sw .RAWTEXT;
                    }
                }
                // EOF is Anything else
                else {
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    lexer.stream.reconsumeChar();
                    continue :sw .RAWTEXT;
                }
            },
            .RAWTEXTEndTagName => {
                current_input_character = lexer.stream.consumeChar();
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002F SOLIDUS (/)
                    if (char == '/') {
                        tempBuffer[0] = 0;
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
                        lexer.stream.reconsumeChar();
                        continue :sw .ScriptData;
                    }
                }
                // EOF is Anything else
                else {
                    Token.emitToken(try tokenHandler.createCharacter('<'));
                    lexer.stream.reconsumeChar();
                    continue :sw .ScriptData;
                }
            },
            .ScriptDataEndTagOpen => {
                current_input_character = lexer.stream.consumeChar();
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
                current_input_character = lexer.stream.consumeChar();
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('_'));
                        continue :sw .ScriptDataEscapeStartDash;
                    }
                    // Anything else
                    else {
                        lexer.stream.reconsumeChar();
                        continue :sw .ScriptData;
                    }
                }
                // EOF is Anything else
                else {
                    lexer.stream.reconsumeChar();
                    continue :sw .ScriptData;
                }
            },
            .ScriptDataEscapeStartDash => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // U+002D HYPHEN-MINUS (-)
                    if (char == '-') {
                        Token.emitToken(try tokenHandler.createCharacter('_'));
                        continue :sw .ScriptDataEscapedDashDash;
                    }
                    // Anything else
                    else {
                        lexer.stream.reconsumeChar();
                        continue :sw .ScriptData;
                    }
                }
                // EOF is Anything else
                else {
                    lexer.stream.reconsumeChar();
                    continue :sw .ScriptData;
                }
            },
            .ScriptDataEscaped => {
                current_input_character = lexer.stream.consumeChar();
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
                current_input_character = lexer.stream.consumeChar();
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataEscapedLessThanSign => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataEscapedEndTagOpen => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataEscapedEndTagName => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataDoubleEscapestart => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataDoubleEscaped => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataDoubleEscapedDash => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataDoubleEscapedDashDash => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataDoubleEscapedLessThanSign => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .ScriptDataDoubleEscapeEnd => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .BeforeAttributeName => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .AttributeName => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .AfterattributeName => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Beforeattributevalue => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Attributevaluedoublequoted => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Attributevaluesinglequoted => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Attributevalueunquoted => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Afterattributevaluequoted => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .SelfClosingStartTag => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .BogusComment => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .MarkupDeclarationOpen => {
                if (lexer.stream.consumeString("DOCTYPE")) {
                    continue :sw .DOCTYPE;
                }
            },
            .Commentstart => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CommentstartDash => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Comment => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CommentLessThanSign => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CommentLessThanSignbang => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CommentLessThanSignbangDash => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CommentLessThanSignbangDashDash => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CommentEndDash => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CommentEnd => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CommentEndbang => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .DOCTYPE => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    if (std.ascii.isWhitespace(char)) {
                        continue :sw .BeforeDOCTYPEName;
                    }
                    if (char == '>') {
                        lexer.stream.reconsumeChar();
                        continue :sw .BeforeDOCTYPEName;
                    } else {
                        // missing-whitespace-before-doctype-name parse error
                        lexer.stream.reconsumeChar();
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
                current_input_character = lexer.stream.consumeChar();
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
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .AfterDOCTYPEName => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .AfterDOCTYPEpublickeyword => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .BeforeDOCTYPEpublicidentifier => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .DOCTYPEpublicidentifierdoublequoted => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .DOCTYPEpublicidentifiersinglequoted => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .AfterDOCTYPEpublicidentifier => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .BetweenDOCTYPEpublicandsystemidentifiers => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .AfterDOCTYPEsystemkeyword => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .BeforeDOCTYPEsystemidentifier => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .DOCTYPEsystemidentifierdoublequoted => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .DOCTYPEsystemidentifiersinglequoted => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .AfterDOCTYPEsystemidentifier => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .BogusDOCTYPE => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CDATAsection => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CDATAsectionbracket => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CDATAsectionEnd => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .CharacterReference => {
                unreachable;
            },
            .Namedcharacterreference => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Ambiguousampersand => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Numericcharacterreference => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Hexadecimalcharacterreferencestart => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Decimalcharacterreferencestart => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Hexadecimalcharacterreference => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .Decimalcharacterreference => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
            .NumericcharacterreferenceEnd => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |_| {} else {}
            },
        }
    }
};
