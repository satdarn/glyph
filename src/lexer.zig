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

    current_token: Token = undefined,

    pub fn init(allocator: std.mem.Allocator, input_stream: InputStream) HtmlLexer {
        return .{ .stream = input_stream, .allocator = allocator };
    }


    pub fn run(lexer: *HtmlLexer) void {
        var current_input_character: ?u8 = undefined;
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
                        lexer.current_token = Token.createCharacter(char);
                        Token.emitToken(lexer.current_token);
                        continue :sw .Data;
                    }
                    // Anything else
                    lexer.current_token = Token.createCharacter(char);
                    Token.emitToken(lexer.current_token);
                    continue :sw .Data;
                } else {
                    // EOF
                    Token.createEOF().emitToken();
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
                    lexer.current_token = Token.createCharacter(char);
                    Token.emitToken(lexer.current_token);
                    continue :sw .RCDATA;
                } else {
                    // EOF
                    Token.createEOF().emitToken();
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
                    lexer.current_token = Token.createCharacter(char);
                    Token.emitToken(lexer.current_token);
                    continue :sw .RAWTEXT;
                } else {
                    // EOF
                    Token.createEOF().emitToken();
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
                    lexer.current_token = Token.createCharacter(char);
                    Token.emitToken(lexer.current_token);
                    continue :sw .ScriptData;
                } else {
                    // EOF
                    Token.createEOF().emitToken();
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
                    lexer.current_token = Token.createCharacter(char);
                    Token.emitToken(lexer.current_token);
                    continue :sw .PLAINTEXT;
                } else {
                    // EOF
                    Token.createEOF().emitToken();
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
                        lexer.current_token = Token.createStartTag(char, false);
                        continue :sw .TagName;
                    }
                    // U+003F QUESTION MARK (?)
                    if (char == '?') {
                        // unexpected-question-mark-instead-of-tag-name parse error
                        lexer.current_token = Token.createComment(0);
                        lexer.stream.reconsumeChar();
                        continue :sw .BogusComment;
                    }
                    // Anything else
                    // invalid-first-character-of-tag-name parse error
                    Token.createCharacter('<').emitToken();
                    lexer.stream.reconsumeChar();
                    continue :sw .Data;
                } else {
                    // EOF
                    // eof-before-tag-name parse error
                    Token.createCharacter('<').emitToken();
                    Token.createEOF().emitToken();
                    break :sw;
                }
            },
            .EndTagOpen => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    // ASCII alpha
                    if (std.ascii.isAlphabetic(char)) {
                        lexer.current_token = Token.createEndTag(char, false);
                        continue :sw .TagName;
                    }
                    // U+003E GREATER-THAN SIGN (>)
                    if (char == '>') {
                        // missing-end-tag-name parse error
                        continue :sw .Data;
                    } else {
                        // Anything else
                        // invalid-first-character-of-tag-name parse error
                        lexer.current_token = Token.createComment(0);
                        lexer.stream.reconsumeChar();
                        continue :sw .BogusComment;
                    }
                } else {
                    // EOF
                    // eof-before-tag-name parse error
                    Token.createEOF().emitToken();
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
                        Token.emitToken(lexer.current_token);
                        continue :sw .Data;
                    }
                    // ASCII upper alpha
                    if (std.ascii.isAlphabetic(char) and std.ascii.isUpper(char)) {
                        lexer.current_token.tagName = lexer.current_token.tagName ++ std.ascii.toLower(char);
                        continue :sw .TagName;
                    }
                    // U+0000 NULL
                    if (char == 0) {
                        // unexpected-null-character parse error.
                        // Append a U+FFFD REPLACEMENT CHARACTER character to the current tag token's tag name
                    } else {
                        // Anything else
                        lexer.current_token.tagName = lexer.current_token.tagName ++ char;
                        continue :sw .TagName;
                    }
                } else {
                    Token.createEOF().emitToken();
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
            .Commentstart => {},
            .Commentstartdash => {},
            .Comment => {},
            .CommentLessThanSign => {},
            .CommentLessThanSignbang => {},
            .CommentLessThanSignbangdash => {},
            .CommentLessThanSignbangdashdash => {},
            .Commentenddash => {},
            .Commentend => {},
            .Commentendbang => {},
            .DOCTYPE => {},
            .BeforeDOCTYPEname => {},
            .DOCTYPEname => {},
            .AfterDOCTYPEname => {},
            .AfterDOCTYPEpublickeyword => {},
            .BeforeDOCTYPEpublicidentifier => {},
            .DOCTYPEpublicidentifierdoublequoted => {},
            .DOCTYPEpublicidentifiersinglequoted => {},
            .AfterDOCTYPEpublicidentifier => {},
            .BetweenDOCTYPEpublicandsystemidentifiers => {},
            .AfterDOCTYPEsystemkeyword => {},
            .BeforeDOCTYPEsystemidentifier => {},
            .DOCTYPEsystemidentifierdoublequoted => {},
            .DOCTYPEsystemidentifiersinglequoted => {},
            .AfterDOCTYPEsystemidentifier => {},
            .BogusDOCTYPE => {},
            .CDATAsection => {},
            .CDATAsectionbracket => {},
            .CDATAsectionend => {},
            .CharacterReference => {
                unreachable;
            },
            .Namedcharacterreference => {},
            .Ambiguousampersand => {},
            .Numericcharacterreference => {},
            .Hexadecimalcharacterreferencestart => {},
            .Decimalcharacterreferencestart => {},
            .Hexadecimalcharacterreference => {},
            .Decimalcharacterreference => {},
            .Numericcharacterreferenceend => {},
        }
    }
};
