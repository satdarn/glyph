const std = @import("std");
const InputStream = @import("inputStream.zig").InputStream;

const LexerStates = enum {
    Data,
    RCDATA,
    RAWTEXT,
    Scriptdata,
    PLAINTEXT,
    Tagopen,
    EndTagOpen,
    Tagname,
    RCDATAlessthansign,
    RCDATAendtagopen,
    RCDATAendtagname,
    RAWTEXTlessthansign,
    RAWTEXTendtagopen,
    RAWTEXTendtagname,
    Scriptdatalessthansign,
    Scriptdataendtagopen,
    Scriptdataendtagname,
    Scriptdataescapestart,
    Scriptdataescapestartdash,
    Scriptdataescaped,
    Scriptdataescapeddash,
    Scriptdataescapeddashdash,
    Scriptdataescapedlessthansign,
    Scriptdataescapedendtagopen,
    Scriptdataescapedendtagname,
    Scriptdatadoubleescapestart,
    Scriptdatadoubleescaped,
    Scriptdatadoubleescapeddash,
    Scriptdatadoubleescapeddashdash,
    Scriptdatadoubleescapedlessthansign,
    Scriptdatadoubleescapeend,
    Beforeattributename,
    Attributename,
    Afterattributename,
    Beforeattributevalue,
    Attributevaluedoublequoted,
    Attributevaluesinglequoted,
    Attributevalueunquoted,
    Afterattributevaluequoted,
    Selfclosingstarttag,
    Boguscomment,
    MarkupDeclarationOpen,
    Commentstart,
    Commentstartdash,
    Comment,
    Commentlessthansign,
    Commentlessthansignbang,
    Commentlessthansignbangdash,
    Commentlessthansignbangdashdash,
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

    pub fn init(allocator: std.mem.Allocator, input_stream: InputStream) HtmlLexer {
        return .{ .stream = input_stream, .allocator = allocator };
    }

    pub fn run(lexer: *HtmlLexer) void {
        var current_input_character: ?u8 = undefined;
        sw: switch (lexer.current_state) {

            .Data => {
                current_input_character = lexer.stream.consumeChar();
                if (current_input_character) |char| {
                    if (char == '&') {
                        lexer.return_state = .Data;
                        continue :sw .CharacterReference;
                    }
                    if (char == '<') {
                        continue :sw .Tagopen;
                    }
                } else {
                    // TODO: Emit EOF token 
                }

            },
            .RCDATA => {},
            .RAWTEXT => {},
            .Scriptdata => {},
            .PLAINTEXT => {},
            .Tagopen => {
                current_input_character = lexer.stream.consumeChar();
                if(current_input_character) |char| {
                    if (current_input_character == '!') { continue sw: .MarkupDeclarationOpen; }
                    if (current_input_character == '/') { continue sw: .EndTagOpen; }
                } else {     
                    // EOF
                }
            },
            .EndTagOpen => {},
            .Tagname => {},
            .RCDATAlessthansign => {},
            .RCDATAendtagopen => {},
            .RCDATAendtagname => {},
            .RAWTEXTlessthansign => {},
            .RAWTEXTendtagopen => {},
            .RAWTEXTendtagname => {},
            .Scriptdatalessthansign => {},
            .Scriptdataendtagopen => {},
            .Scriptdataendtagname => {},
            .Scriptdataescapestart => {},
            .Scriptdataescapestartdash => {},
            .Scriptdataescaped => {},
            .Scriptdataescapeddash => {},
            .Scriptdataescapeddashdash => {},
            .Scriptdataescapedlessthansign => {},
            .Scriptdataescapedendtagopen => {},
            .Scriptdataescapedendtagname => {},
            .Scriptdatadoubleescapestart => {},
            .Scriptdatadoubleescaped => {},
            .Scriptdatadoubleescapeddash => {},
            .Scriptdatadoubleescapeddashdash => {},
            .Scriptdatadoubleescapedlessthansign => {},
            .Scriptdatadoubleescapeend => {},
            .Beforeattributename => {},
            .Attributename => {},
            .Afterattributename => {},
            .Beforeattributevalue => {},
            .Attributevaluedoublequoted => {},
            .Attributevaluesinglequoted => {},
            .Attributevalueunquoted => {},
            .Afterattributevaluequoted => {},
            .Selfclosingstarttag => {},
            .Boguscomment => {},
            .MarkupDeclarationOpen => {
                if(lexer.stream.consumeString("DOCTYPE")) {
                    continue :sw .DOCTYPE;
                }
            },
            .Commentstart => {},
            .Commentstartdash => {},
            .Comment => {},
            .Commentlessthansign => {},
            .Commentlessthansignbang => {},
            .Commentlessthansignbangdash => {},
            .Commentlessthansignbangdashdash => {},
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
