using Gee;
using Vala;

class Vls.TokenFormatter : Object{
    SourceFile _file;
    Vls.Token? last_token = null;
    internal TokenFormatter(SourceFile file) {
        _file = file;
    }
    internal void format() {
        var source_file = this.load_string();
        var tokens = this.tokenize(source_file);
        var merger = new TokenMerger(merger);
        merger.merge();
    }
    Gee.List<Token> tokenize(string source) {
        var ret = new Gee.ArrayList<Token>();
        var length = source.length;
        for(var i = 0; i < length; i++) {
            var current_char = source.get_char(i);
            switch(current_char) {
                case '"':
                    last_token = parse_string_literal(ref i, source);
                    break;
                case '\'':
                    last_token = parse_character_literal(ref i, source);
                    break;
                default:
                    var t = default_handling(ref i, source);
                    if(t != null)
                        last_token = t;
                    break;
            }
            if(last_token != null) {
                ret.add(last_token);
            }
        }
        return ret;
    }
    bool start_regex() {
        if(last_token == null)
            return false;
        if(last_token is Operator) {
            // See https://github.com/GNOME/vala/blob/0afdde060b0cc3d4c575f6686730a38441e92966/vala/valascanner.vala#L1092
            var txt = last_token.content;
            return txt == "=" || txt == "," ||
                    txt == "-" || txt == "??" ||
                    txt == "==" || txt == ">=" ||
                    txt == ">" || txt == "<=" ||
                    txt == "<" || txt == "!=" ||
                    txt == "~" || txt == "|" ||
                    txt == "[" || txt == "(" || txt == "+";
        } else if(last_token is Identifier) {
            return last_token.content == "return";
        }
        return false;
    }
    Vls.Token? default_handling(ref int i, string source) {
        var current_char = source.get_char(i);
        var next_char = source.get_char(i + 1);
        if(current_char.isspace())
            return null;
        if(current_char == '/') {
            if(start_regex()) {
                // TODO
                return handle_regex_literal(ref i, source);
            } else if(next_char == '/') {
                return handle_slash_slash(ref i, source);
            } else if(next_char == '*') {
                return handle_multiline_comment(ref i, source);
            } else if(next_char == '=') {
                i++;
                return new Operator("/=");
            }
            // TODO: Regex literal + plus modifiers (/.../ismx)
            return new Operator("/");
        }
        if(is_single_char_op(current_char)) {
            return new Operator(current_char.to_string());
        } else if(can_be_assigned(current_char)) {
            if(next_char == '=') {
                i++;
                return new Operator(current_char.to_string() + "=");
            }
            return new Operator(current_char.to_string());
        } else if(current_char == '.') {
            if(next_char == '.' && source.get_char(i + 2) == '.') {
                i += 2;
                return new Operator("...");
            }
            return new Operator(".");
        } else if(current_char == ':') {
            if(next_char == ':') {
                i++;
                return new Operator("::");
            }
            return new Operator(":");
        } else if(current_char == '?') {
            if(next_char == '?') {
                i++;
                return new Operator("??");
            }
            return new Operator("?");
        } else if(current_char == '|' || current_char == '&') {
            if(next_char == current_char || next_char == '=') {
                i++;
                return new Operator(current_char.to_string() + next_char.to_string());
            }
            return new Operator(current_char.to_string());
        } else if(current_char == '<') {
            if(next_char == '=') {
                i++;
                return new Operator("<=");
            } else if(next_char == '<') {
                i++;
                if(source.get_char(i + 1) == '=') {
                    i++;
                    return new Operator("<<=");
                }
                return new Operator("<<");
            }
            return new Operator("<");
        } else if (current_char == '+') {
            if(next_char == '=') {
                i++;
                return new Operator("+=");
            } else if(next_char == '+') {
                i++;
                return new Operator("++");
            }
            return new Operator("+");
        } else if (current_char == '-') {
            if(next_char == '=') {
                i++;
                return new Operator("-=");
            } else if(next_char == '-') {
                i++;
                return new Operator("--");
            } else if(next_char == '>') {
                i++;
                return new Operator("->");
            }
            return new Operator("-");
        } else {
            var sb = new StringBuilder();
            var j = i;
            for(;;j++) {
                var c = source.get_char(j);
                if(c.isalnum() || c == '_')
                    sb.append_unichar(c);
                else
                    break;
            }
            // Otherwise the next char is skipped.
            j--;
            j = i;
            return new Identifier(sb.str);
        }
    }
    Vls.Token handle_regex_literal(ref int i, string source) {
        var sb = new StringBuilder();
        i++; // Skip /
        var j = i;
        for(;; j++) {
            var c = source.get_char(j);
            if(c == '/')
                break;
            if(c == '\\') {
                // See https://github.com/GNOME/vala/blob/0afdde060b0cc3d4c575f6686730a38441e92966/vala/valascanner.vala#L162
                switch(source.get_char(j + 1)) {
                    case '\'':
                    case '"':
                    case '\\':
                    case '/':
                    case '^':
                    case '$':
                    case '.':
                    case '[':
                    case ']':
                    case '{':
                    case '}':
                    case '(':
                    case ')':
                    case '?':
                    case '*':
                    case '+':
                    case '-':
                    case '#':
                    case '&':
                    case '~':
                    case ':':
                    case ';':
                    case '<':
                    case '>':
                    case '|':
                    case '%':
                    case '=':
                    case '@':
                    case '0':
                    case 'b':
                    case 'B':
                    case 'f':
                    case 'n':
                    case 'N':
                    case 'r':
                    case 'R':
                    case 't':
                    case 'v':
                    case 'a':
                    case 'A':
                    case 'p':
                    case 'P':
                    case 'e':
                    case 'd':
                    case 'D':
                    case 's':
                    case 'S':
                    case 'w':
                    case 'W':
                    case 'G':
                    case 'z':
                    case 'Z':
                        sb.append("\\").append_unichar(source.get_char(j + 1));
                        j++;
                        break;
                    case 'u':
                        sb.append("\\u");
                        j++;
                        for(var k = 0; k < 4; k++) {
                            sb.append_unichar(source.get_char(j + 1 + k));
                            j++;
                        }
                        break;
                    case 'x':
                        j++;
                        sb.append("\\x").append_unichar(source.get_char(j + 1)).append_unichar(source.get_char(j + 2));
                        j += 2;
                        break;
                }
            } else {
                sb.append_unichar(c);
            }
        }
        j++; // Skip trailing /
        var string2 = new StringBuilder();
        // See https://github.com/GNOME/vala/blob/0afdde060b0cc3d4c575f6686730a38441e92966/vala/valascanner.vala#L120
        for(;; j++) {
            var c = source.get_char(j);
            switch(c) {
                case 'i':
                case 's':
                case 'm':
                case 'x':
                    string2.append_unichar(c);
                    continue;
            }
            break;
        }
        return new RegexLiteral(sb.str, string2.str);
    }
    bool is_single_char_op(unichar c) {
        switch(c) {
            case ',':
            case '@':
            case ';':
            case '#':
            case '~':
            case '(':
            case ')':
            case '[':
            case ']':
            case '{':
            case '}':
                return true;
            default:
                return false;
        }
    }
    bool can_be_assigned(unichar c) {
        switch(c) {
            case '=':
            case '^':
            case '>':
            case '!':
            case '*':
            case '%':
                return true;
            default:
                return false;
        }
    }
    Vls.Token handle_multiline_comment(ref int i, string source) {
        var content = new StringBuilder();
        var is_doc = source.get_char(i + 2) == '*';
        var j = i + (is_doc ? 3 : 2);
        var multiline = false;
        for(;; j++) {
            if(source.get_char(j) == '\n') {
                multiline = true;
                // Skip indentation and so on.
                while(source.get_char(j).isspace())
                    j++;
                // We are now at the leading star if it is there.
                if(source.get_char(j) == '*')
                    if(source.get_char(j + 1) == '/') {
                        j++;
                        break;
                    } else {
                        j++;
                        while(source.get_char(j).isspace())
                            j++;
                        j--;
                    }
                else // Avoid losing content
                    j--;
                content.append("\n");
                continue;
            }
            if(source.get_char(j) == '*' && source.get_char(j + 1) == '/') {
                j++;
                break;
            }
            content.append_unichar(source.get_char(j));
        }
        i = j;
        if(!multiline)
            return new InlineComment.multiline(content.str.strip(), is_doc);
        return new Comment.multiline(content.str.strip(), is_doc);
    }
    Vls.Token handle_slash_slash(ref int i, string source) {
        var content = new StringBuilder();
        var j = i + 2;
        for(;; j++) {
            if(source.get_char(j) == '\n')
                break;
            content.append_unichar(source.get_char(j));
        }
        i = j;
        var is_inline = false;
        for(j -= 2;; j--) {
            if(source.get_char(j) == '\n') {
                break;
            } else if(!source.get_char(j).isspace()) {
                is_inline = true;
                break;
            }
        }
        if(is_inline)
            return new InlineComment(content.str.strip());
        return new Comment(content.str.strip());
    }
    Vls.Token parse_string_literal(ref int i, string source) {
        var sb = new StringBuilder();
        var multiline = source.get_char(i + 1) == '\"' && source.get_char(i + 2) == '\"';
        // Skip quotes
        if(multiline) {
            i += 3;
        } else {
            i++;
        }
        var escaped = false;
        var j = i;
        for(;; j++) {
            var c = source.get_char(j);
            if(c == '\\') {
                escaped = !escaped;
            } else if(c == '\"' && !escaped) {
                if(!multiline)
                    break;
                if(source.get_char(j + 1) == '\"' && source.get_char(j + 2) == '\"') {
                    j += 2;
                    break;
                }
            }
            sb.append_unichar(c);
        }
        i = j;
        if(multiline)
            return new MultilineString(sb.str);
        return new StringLiteral(sb.str);
    }
    Vls.Token parse_character_literal(ref int i, string source) {
        var sb = new StringBuilder();
        if(source.get_char(i + 1) != '\\') {
            sb.append_unichar(source.get_char(i + 1));
            i += 2;
        } else {
            var next = source.get_char(i + 2);
            if(next == 'x') {
                sb.append("\\x").append_unichar(source.get_char(i + 3)).append_unichar(source.get_char(i + 4));
                i += 5;
            } else {
                sb.append("\\u");
                for(var j = 0; j < 4; j++) {
                    sb.append_unichar(source.get_char(i + 1 + j));
                }
                i += 7;
            }
        }
        return new CharacterLiteral(sb.str);
    }
    string load_string() {
        var sb = new StringBuilder();
        for(int i = 1;; i++) {
            var line = this._file.get_source_line(i);
            if(line == null)
                break;
            sb.append(line).append_c('\n');
        }
        return sb.str;
    }
}
abstract class Vls.Token {
    internal string content{protected set; internal get;}
    internal virtual string to_string(ref uint indentation) {
        return this.content;
    }
}

// Either a // comment or /* */
class Vls.InlineComment : Vls.Token{
    bool is_multiline;
    bool is_doc;

    internal InlineComment(string s) {
        this.content = s;
    }
    internal InlineComment.multiline(string s, bool is_doc) {
        this.content = s;
        this.is_multiline = true;
        this.is_doc = is_doc;
    }
    internal override string to_string(ref uint indentation) {
        var c = this.content.strip();
        if(is_multiline) {
            return (is_doc ? "/** " : "/* ") + c + " */";
        }
        return "<indent>// " + c;
    }
}
// Comment on its own line or /* */ comments on their own lines
class Vls.Comment : Vls.Token {
    bool is_doc;
    bool is_multiline;
    internal Comment(string s) {
        this.content = s;
    }
    internal Comment.multiline(string s, bool is_doc) {
        this.content = s;
        this.is_multiline = true;
        this.is_doc = is_doc;
    }
    internal override string to_string(ref uint indentation) {
        var c = this.content.strip();
        if(is_multiline) {
            var parts = this.content.split("\n");
            var sb = new StringBuilder();
            sb.append(is_doc ? "/**" : "/*\n");
            foreach(var part in parts) {
                sb.append("<indent> * ").append(part).append("\n");
            }
            sb.append("<indent> */\n");
            return sb.str;
        }
        return "<indent>// " + c;
    }
}

class Vls.Identifier : Vls.Token {
    internal Identifier(string s) {
        this.content = s;
    }
}
class Vls.Operator : Vls.Token {
    internal Operator(string s) {
        this.content = s;
    }
}
class Vls.MultilineString : Vls.Token {
    internal MultilineString(string s) {
        this.content = s;
    }
    internal override string to_string(ref uint indentation) {
        return "\"\"\"" + this.content + "\"\"\"";
    }
}
class Vls.RegexLiteral : Vls.Token {
    // E.g. i,m,s,x
    string modifiers;
    internal RegexLiteral(string regex, string modifiers) {
        this.content = regex;
        this.modifiers = modifiers;
    }
    internal override string to_string(ref uint indentation) {
        return "/" + this.content + "/" + modifiers;
    }
}
class Vls.StringLiteral : Vls.Token {
    internal StringLiteral(string s) {
        this.content = s;
    }
    internal override string to_string(ref uint indentation) {
        return "\"" + this.content + "\"";
    }
}
class Vls.CharacterLiteral : Vls.Token {
    internal CharacterLiteral(string s) {
        this.content = s;
    }
    internal override string to_string(ref uint indentation) {
        return "\'" + this.content + "\'";
    }
}
