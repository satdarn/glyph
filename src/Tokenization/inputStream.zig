const std = @import("std");

// TODO: THIS NEEDS TO HANDLE UNICODE TO BE IN SPEC ascii is ok for now
const InputStream = struct {
    data: []const u8,
    pos: usize,

    fn getNextChar(stream: *InputStream) ?u8 {
        if(stream.pos+1 >= stream.data.size){ return null;}
        stream.pos += 1;
        return stream.data[stream.pos];
    }
    
    fn peek(stream: *InputStream, offset: usize) ?u8 {
        if (stream.pos + offset >= stream.data.size) {
            return null;
        }
        return stream.data[stream.pos + offset];
    }
    
    fn nextCharsAre(stream: *InputStream, string: []const u8) bool{
        for (string, 0.. ) |checkChar, i| {
            const maybeChar: ?u8 = stream.peek(i);
            if (maybeChar) |char| {
                if (char != checkChar) {
                    return false; 
                }
            } else {
                return false;
            }

        }
        return true;
    }

    fn consumeChars(stream: *InputStream, string: []const u8) bool{
        if(stream.nextCharsAre(string)) {
            stream.pos += string.len;
            return true;
        }
        return false;
    }

};
