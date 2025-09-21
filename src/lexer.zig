const std = @import("std");
const InputStream = @import("inputStream.zig").InputStream;
const Token = @import("tokens.zig").Token;

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
    RCDATAendtagopen,
    RCDATAendtagname,
    RAWTEXTLessThanSign,
    RAWTEXTendtagopen,
    RAWTEXTendtagname,
    ScriptDataLessThanSign,
    ScriptDataendtagopen,
    ScriptDataendtagname,
    ScriptDataescapestart,
    ScriptDataescapestartdash,
    ScriptDataescaped,
    ScriptDataescapeddash,
    ScriptDataescapeddashdash,
    ScriptDataescapedLessThanSign,
    ScriptDataescapedendtagopen,
    ScriptDataescapedendtagname,
    ScriptDatadoubleescapestart,
    ScriptDatadoubleescaped,
    ScriptDatadoubleescapeddash,
    ScriptDatadoubleescapeddashdash,
    ScriptDatadoubleescapedLessThanSign,
    ScriptDatadoubleescapeend,
    BeforeAttributeName,
    Attributename,
    Afterattributename,
    Beforeattributevalue,
    Attributevaluedoublequoted,
    Attributevaluesinglequoted,
    Attributevalueunquoted,
    Afterattributevaluequoted,
    SelfClosingStartTag,
    BogusComment,
    MarkupDeclarationOpen,
    Commentstart,
    Commentstartdash,
    Comment,
    CommentLessThanSign,
    CommentLessThanSignbang,
    CommentLessThanSignbangdash,
    CommentLessThanSignbangdashdash,
    Commentenddash,
    Commentend,
    Commentendbang,
    DOCTYPE,
    BeforeDOCTYPEname,
    DOCTYPEname,
    AfterDOCTYPEname,
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
    CDATAsectionend,
    CharacterReference,
    Namedcharacterreference,
    Ambiguousampersand,
    Numericcharacterreference,
    Hexadecimalcharacterreferencestart,
    Decimalcharacterreferencestart,
    Hexadecimalcharacterreference,
    Decimalcharacterreference,
    Numericcharacterreferenceend,
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
                lexer.current_input_character = lexer.stream.consumeChar();
                if (lexer.current_input_character) |char| {
                    if (char == '/'){
                               
                    }
                }
            },
            .RCDATAendtagopen => {},
            .RCDATAendtagname => {},
            .RAWTEXTLessThanSign => {},
            .RAWTEXTendtagopen => {},
            .RAWTEXTendtagname => {},
            .ScriptDataLessThanSign => {},
            .ScriptDataendtagopen => {},
            .ScriptDataendtagname => {},
            .ScriptDataescapestart => {},
            .ScriptDataescapestartdash => {},
            .ScriptDataescaped => {},
            .ScriptDataescapeddash => {},
            .ScriptDataescapeddashdash => {},
            .ScriptDataescapedLessThanSign => {},
            .ScriptDataescapedendtagopen => {},
            .ScriptDataescapedendtagname => {},
            .ScriptDatadoubleescapestart => {},
            .ScriptDatadoubleescaped => {},
            .ScriptDatadoubleescapeddash => {},
            .ScriptDatadoubleescapeddashdash => {},
            .ScriptDatadoubleescapedLessThanSign => {},
            .ScriptDatadoubleescapeend => {},
            .BeforeAttributeName => {},
            .Attributename => {},
            .Afterattributename => {},
            .Beforeattributevalue => {},
            .Attributevaluedoublequoted => {},
            .Attributevaluesinglequoted => {},
            .Attributevalueunquoted => {},
            .Afterattributevaluequoted => {},
            .SelfClosingStartTag => {},
            .BogusComment => {},
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
