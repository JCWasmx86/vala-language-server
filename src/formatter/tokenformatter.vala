using Gee;
using Vala;

class Vls.TokenFormatter : Object{
    SourceFile _file;

    internal TokenFormatter(SourceFile file) {
        _file = file;
    }
    internal void format() {
        var source_file = this.load_string();
        var tokens = this.tokenize(source_file);
    }
    Gee.List<Token> tokenize(string source) {
        var ret = new Gee.ArrayList<Token>();
        var length = source.length;
        for(var i = 0; i < length; i++) {
            var following = length - i;
            var current_char = source.get_char(i);
            var next_chars = source.slice(i + 1, (following > 3 ? 3 : following) + 1);
            switch(current_char) {
                case '"':
                    ret.add(parse_string_literal(ref i, source));
                    break;
                case '\'':
                    ret.add(parse_character_literal(ref i, source));
                    break;
                default:
                    var t = default_handling(ref i, source);
                    if(t != null)
                        ret.add(t);
                    break;
            }
        }
        return ret;
    }
    Vls.Token? default_handling(ref int i, string source) {
        var current_char = source.get_char(i);
        var next_char = source.get_char(i + 1);
        if(current_char.isspace())
            return null;
        if(current_char == '/') {
            if(next_char == '/') {
                return handle_slash_slash(ref i, string source);
            } else if(next_char == '*') {
                return handle_multiline_comment(ref i, string source);
            } else if(next_char == '=') {
                i++;
                return new Operator("/=");
            }
            // TODO: Regex literal + plus modifiers (/.../ismx)
            return new Operator("/");
        }
        // TODO: {[()]}
        // TODO: Deduplicate
        if (current_char == ',') {
            return new Operator(",");
        } else if(current_char == '@') {
            return new Operator("@");
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
        } else if(current_char == ';') {
            return new Operator(";");
        } else if(current_char == '#') {
            return new Operator("#");
        } else if(current_char == '?') {
            if(next_char == '?') {
                i++;
                return new Operator("??");
            }
            return new Operator("?");
        } else if(current_char == '|' || current_char == '&' || current_char == '=') {
            if(next_char == current_char || next_char == '=') {
                i++;
                return new Operator(current_char.to_string() + next_char.to_string());
            }
            return new Operator(current_char.to_string());
        } else if(current_char == '^') {
            if(next_char == '=') {
                i++;
                return new Operator("^=");
            }
            return new Operator("^");
        } else if(current_char == '~') {
            return new Operator("~");
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
        } else if(current_char == '>') {
            if(next_char == '=') {
                i++;
                return new Operator(">=");
            }
            return new Operator(">");
        } else if(current_char == '!') {
            if(next_char == '=') {
                i++;
                return new Operator("!=");
            }
            return new Operator("!");
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
        } else if(current_char == '*') {
            if(next_char == '=') {
                i++;
                return new Operator("*=");
            }
            return new Operator("*");
        } else if(current_char == '%') {
            if(next_char == '=') {
                i++;
                return new Operator("%=");
            }
            return new Operator("%");
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
            j = i;
            return new Identifier(sb.str);
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
        if(is_inline)
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
class Vls.Token {
    protected string content;
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
        this.is_doc = is_doc;
    }
}
// Comment on its own line or /* */ comments on their own lines
class Vls.Comment : Vls.Token {
    bool is_doc;
    internal Comment(string s) {
        this.content = s;
    }
    internal InlineComment.multiline(string s, bool is_doc) {
        this.content = s;
        this.is_doc = is_doc;
    }
}

class Vls.Identifier : Vls.Token {

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
}
class Vls.RegexLiteral : Vls.Token {

}
class Vls.StringLiteral : Vls.Token {
    internal StringLiteral(string s) {
        this.content = s;
    }
}
class Vls.CharacterLiteral : Vls.Token {
    internal CharacterLiteral(string s) {
        this.content = s;
    }
}