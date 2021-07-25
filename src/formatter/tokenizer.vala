using Gee;

class Vls.Tokenizer {
    private Gee.List<string> lines = new ArrayList<string>();
    // Keywords from https://wiki.gnome.org/Projects/Vala/Syntax
    private string[] keywords = new string[] {
            // This line is at the top, as otherwise the spaces would mess a lot up.
            "construct", "static construct", "class construct",
            "if", "else", "switch", "case", "default",
            "do", "while", "for", "foreach", "in",
            "break", "continue", "return",
            "try", "catch", "finally", "throw",
            "lock",
            "class", "interface", "struct", "enum", "delegate", "errordomain",
            "const", "weak", "unowned", "dynamic",
            "abstract", "virtual", "override", "signal", "extern", "static", "async", "inline", "new",
            "public", "private", "protected", "internal",
            "out", "ref",
            "throws", "requires", "ensures",
            "namespace", "using",
            "as", "is", "in", "new", "delete", "sizeof", "typeof",
            "this", "base",
            "null", "true", "false",
            "get", "set", "construct", "default", "value",
            "void", "var", "yield", "global", "owned"
    };

    public Tokenizer(Vala.SourceFile file_to_tokenize) {
        for(int i = 1;; i++) {
            var line = file_to_tokenize.get_source_line(i);
            if(line == null) {
                break;
            }
            this.lines.add(line);
        }
    }
    public Tokenizer.with_lines(Gee.List<string> lines) {
        this.lines = lines.read_only_view;
    }
    public Gee.List<Token> tokenize() {
        var tokens = new Gee.ArrayList<Token>();
        foreach(var line in this.lines) {
            var line_tokens = this.parse_line(line);
            tokens.add_all(line_tokens);
        }
        return tokens;
    }
    Gee.List<Token> parse_line(string line) {
        var length = line.char_count();
        var chars = line.to_utf8();
        var tokens = new Gee.ArrayList<Token>();
        for(var i = 0; i < length;) {
            Token? token = null;
            if(this.isblank(chars[i])) {
                i++;
                continue;
            }
            var consumed_chars = this.parse_keyword(out token, chars, i, length);
            if(token != null) {
                tokens.add(token);
                i += consumed_chars;
                continue;
            }
        }
        return tokens;
    }
    int parse_keyword(out Token? result, char[] line, int offset, int max_length) {
        result = null;
        var upcoming_char_count = max_length - offset;
        var amount_of_caching = 20;
        // Is the next char a separator that ends a keyword?
        var next_char_is_sep = new bool[amount_of_caching];
        // The string of the next n chars.
        var next_strings = new string[amount_of_caching];
        for(int i = 0; i < amount_of_caching; i++) {
            var c = upcoming_char_count > i ? line[offset + i] : '\0';
            // TODO: Check for edge cases!
            next_char_is_sep[i] = this.isblank(c) || !c.isalnum();
            var sb = new StringBuilder();
            for(int j = 0; j < i; j++) {
                sb.append_c(line[offset + j]);
            }
            next_strings[i] = sb.str;
        }
        // Example: namespace as a keyword, first char is 'n',
        foreach(var key in keywords) {
            // length 9
            var length = key.char_count();
            // 8 chars have to follow at least (amespace, the 'n' is already there)
            if(upcoming_char_count >= length - 1) {
                // If the string of the length of the keyword matches and the following
                // char is a separator (== blank or not alpha numeric) or just end of string, we found a keyword
                if(next_strings[length] == key && (upcoming_char_count - length == 0 || next_char_is_sep[length])) {
                    result = new Keyword(key);
                    return length;
                }
            }
        }
        return 0;
    }
    bool isblank(char c) {
        return c == ' ' || c == '\t' || c == '\r' || c == '\n';
    }
}

enum Vls.TokenType {
    KEYWORD, SLASH_SLASH_COMMENT_IN_LINE, SLASH_SLASH_COMMENT_WITH_OWN_LINE
}
abstract class Vls.Token {
    public TokenType token_type{public get; protected set;}
    public string string_value{public get; protected set;}

    public bool equals(Vls.Token other) {
        return this.token_type == other.token_type && this.string_value == other.string_value;
    }
}
class Vls.Keyword : Vls.Token {
    internal Keyword(string str_value) {
        string_value = str_value;
        this.token_type = TokenType.KEYWORD;
    }
}