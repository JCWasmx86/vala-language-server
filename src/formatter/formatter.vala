using Gee;

class Vls.Formatter : Object{
    private Pair<Vala.SourceFile, Compilation> _input;
    private Lsp.FormattingOptions _options;
    private int _start_line;
    private int _end_line;
    private string _indenting_string;

    // Used for formatting of the entire file. 8kb are preallocated.
    private StringBuilder new_source_string = new StringBuilder.sized (1024 * 8);
    private uint current_char;
    public Formatter (Lsp.FormattingOptions options, Pair<Vala.SourceFile, Compilation> input, Lsp.Range? range) {
        _options = options;
        _input = input;
        if (range == null) {
            _start_line = 0;
            _end_line = int.MAX;
        } else {
            _start_line = (int) range.start.line;
            _end_line = (int) range.end.line;
        }
        _indenting_string = options.insertSpaces ? string.nfill (options.tabSize, ' ') : "\t";
    }

    /**
     * Format the source file. If an error occurs, error is set and a non-null
     * error string is returned. Otherwise "edit" is set.
     */
    public string? format (out Lsp.TextEdit edit, out Jsonrpc.ClientError error) {
        error = 0;
        if(1 == 0) {
            format_2 (out edit, out error);
            return null;
        } else if (1 != 0) {
            StringBuilder sb = new StringBuilder();
            format_using_visitor(sb, out edit, out error);
            error = Jsonrpc.ClientError.INTERNAL_ERROR;
            return "Not implemented";
        }
        var new_lines = new ArrayList<string>();
        var expected_indentation_depth = 0;
        var source_file = _input.first;
        bool is_in_multiline_comment = false;
        for (int i = _start_line; i <= _end_line; i++) {
            // + 1, as libvala expects the line number to be 1-based,
            // while LSP provides it as 0-based.
            var line_to_format = source_file.get_source_line (i + 1);
            if(line_to_format == null) {
                break;
            }
            var trimmed_line = line_to_format.strip ();
            // Indented lines with no other content are replaced by really empty lines
            if(trimmed_line.length == 0) {
                new_lines.add(is_in_multiline_comment ?  (generate_indentation (expected_indentation_depth) + " *") : "");
                continue;
            }
            if(is_in_multiline_comment) {
                var indent = generate_indentation (expected_indentation_depth) + " ";
                if(trimmed_line.has_suffix ("*/")) {
                    new_lines.add (indent + "*/");
                    is_in_multiline_comment = false;
                } else  {
                    string to_add = trimmed_line;
                    if(trimmed_line.has_prefix ("*")) {
                        to_add = trimmed_line.slice (1, trimmed_line.length);
                    }
                    new_lines.add (indent + "* " + to_add.strip ());
                }
                continue;
            // Preprocessor statements are not indented
            } else if (trimmed_line.has_prefix ("#")) {
                new_lines.add (trimmed_line);
                continue;
            }
            string? raw_string = null;
            // Skip multiline comments, that are just one line
            if(trimmed_line.has_prefix ("/* ") || trimmed_line.has_prefix ("/** ") && trimmed_line.has_suffix ("*/")) {
                raw_string = trimmed_line;
            } else if(trimmed_line.has_prefix ("/*")) {
                is_in_multiline_comment = true;
                var is_doc = trimmed_line.has_prefix ("/**");
                var maybe_string = trimmed_line.slice( is_doc ? 3 : 2, trimmed_line.length).strip();
                var indent = generate_indentation (expected_indentation_depth);
                new_lines.add (indent + (is_doc ? "/**" : "/*"));
                if(maybe_string.length > 0) {
                    new_lines.add(indent + " * " + maybe_string);
                }
                continue;
            } else if (trimmed_line.has_prefix ("//")) {
                // Convert "//<someComment>" to "// <someComment>"
                var comment = trimmed_line.slice( 2, trimmed_line.length).strip();
                raw_string = "// " + comment;
            } else if (trimmed_line.has_suffix ("{")) {
                if(!trimmed_line.has_prefix ("}")) {
                    // After if() {, while() {, ..., indent the body one unit further...
                    expected_indentation_depth++;
                } // ..., but for } else [if()] {, not
                new_lines.add (generate_indentation (expected_indentation_depth - 1) + trimmed_line);
                continue;
            } else if (trimmed_line.has_prefix ("}")) {
                // If a method/block/namespace/class ends, reduce the indentation
                expected_indentation_depth--;
                raw_string = trimmed_line;
            } else {
                // Just a normal line.
                raw_string = trimmed_line;
            }
            new_lines.add (generate_indentation (expected_indentation_depth) + raw_string);
        }
        var new_file = new StringBuilder.sized (new_lines.size * 80);
        foreach (var line in new_lines) {
            new_file.append(line);
            // Or use a platform dependent one? \n works everywhere
            new_file.append_c('\n');
        }
        edit = new Lsp.TextEdit () {
            range = new Lsp.Range () {
                start = new Lsp.Position () {
                    line = _start_line,
                    character = 0
                },
                end = new Lsp.Position () {
                    line = _start_line + new_lines.size,
                    // Just for the trailing newline
                    character = 1
                }
            },
            // Just one final newline
            newText = new_file.str.strip() + "\n"
        };
        return null;
    }

    void format_using_visitor(StringBuilder sb, out Lsp.TextEdit edit, out Jsonrpc.ClientError error) {
        edit = null;
        error = 0;
        if(_input.second.reporter.get_errors () > 0)
            return;
        Vala.CodeContext.push (_input.second.code_context);
        FormattingVisitor fv = new FormattingVisitor ();
        fv.visit_source_file (this._input.first);
        Vala.CodeContext.pop ();
    }
    public string? format_2 (out Lsp.TextEdit edit, out Jsonrpc.ClientError error) {
        edit = null;
        error = 0;
        var list = new ArrayList<Vls.Token>();
        var formatting_properties = new HashMap<string, bool>();
        var scanner = new Vala.Scanner (this._input.first);
        while(true) {
            Vala.SourceLocation start;
            Vala.SourceLocation end;
            var type = scanner.read_token (out start, out end);
            list.add (new Vls.Token() {
                type = type,
                start = start,
                end = end
            });
            if(type == Vala.TokenType.EOF)
                break;
        }
        uint expected_indentation_depth = 0;
        // Open '('
        uint open_parens = 0;
        // Open '['
        uint open_brackets = 0;
        // Open '{'
        uint open_curly = 0;
        for(var i = 0; i < list.size;) {
            var token = list.@get(i);
            switch(token.type) {
                case Vala.TokenType.NAMESPACE:
                    if(current_char != 0) {
                        new_source_string.append_c ('\n');
                    }
                    new_source_string.append (generate_indentation (expected_indentation_depth)).append ("namespace");
                    if(formatting_properties.@get ("indent_after_namespace"))
                        expected_indentation_depth++;
                    // Skip namespace token
                    i++;
                    while (true) {
                        var c_token = list.@get(i);
                        if(c_token.type == Vala.TokenType.OPEN_BRACE)
                            break;
                        switch(c_token.type) {
                            case Vala.TokenType.DOT:
                                new_source_string.append_c ('.');
                                break;
                            case Vala.TokenType.IDENTIFIER:
                                new_source_string.append (this.get_token_value(c_token, this._input.first));
                                break;
                            default:
                                warning ("Unexpected token between NAMESPACE and OPEN_BRACE: %s\n", c_token.type.to_string ());
                                break;
                        }
                        i++;
                    }
                    // Skip '{'
                    i++;
                    if(formatting_properties.@get ("break_before_curly_brace")) {
                        new_source_string.append ("\n").append (generate_indentation (expected_indentation_depth)).append ("{\n");
                    } else {
                        new_source_string.append ("{\n");
                    }
                    open_curly++;
                    break;
                case Vala.TokenType.IDENTIFIER:
                    var identifier_name = get_token_value (token, this._input.first);
                    i++;
                    if(i < list.size) {
                        var next_token = list.@get(i);
                        switch(next_token.type) {
                            case Vala.TokenType.OPEN_PARENS:
                                new_source_string.append(identifier_name);
                                if(formatting_properties.@get ("space_between_identifier_and_parens"))
                                    new_source_string.append_c(' ');
                                new_source_string.append("(");
                                i++;
                                open_parens++;
                                break;
                            case Vala.TokenType.COMMA:
                                new_source_string.append(identifier_name);
                                new_source_string.append(", ");
                                i++;
                                break;
                        }
                    }
                    break;
                case Vala.TokenType.WHILE:
                case Vala.TokenType.FOR:
                case Vala.TokenType.SWITCH:
                case Vala.TokenType.FOREACH:
                case Vala.TokenType.LOCK:
                case Vala.TokenType.UNLOCK:
                case Vala.TokenType.IF:
                    new_source_string.append (token_to_string(token.type));
                    if(formatting_properties.@get ("space_between_identifier_and_parens"))
                        new_source_string.append_c(' ');
                    i++;
                    break;
                case Vala.TokenType.OPEN_PARENS:
                    open_parens++;
                    new_source_string.append_c ('(');
                    break;
                case Vala.TokenType.CLOSE_PARENS:
                    open_parens--;
                    new_source_string.append_c (')');
                    i++;
                    if(i < list.size) {
                        var next_token = list.@get(i);
                        if(next_token.type == Vala.TokenType.OPEN_BRACE) {
                            new_source_string.append_c (' ');
                            if(formatting_properties.@get ("break_before_curly_brace")) {
                                new_source_string.append ("\n").append (generate_indentation (expected_indentation_depth)).append ("{\n");
                            } else {
                                new_source_string.append ("{\n");
                            }
                            expected_indentation_depth++;
                        }
                    }
                    break;
                default:
                    debug("Unexpected token: %s %u %u %u\n", token.type.to_string (), open_parens, open_brackets, open_curly);
                    break;
            }
        }
        return null;
    }
    string token_to_string(Vala.TokenType t) {
        var original = t.to_string ();
        return original.slice(1, original.length);
    }
    string get_token_value(Vls.Token token, Vala.SourceFile file) {
        var start = token.start;
        var end = token.end;
        assert(start.line == end.line);
        var source_line = this._input.first.get_source_line (start.line);
        return source_line.slice(start.column, end.column + 1);
    }
    string generate_indentation (uint repeats) {
        // TODO: StringBuilder or caching instead of this loop?
        string ret = "";
        for (var i = 0; i < repeats; i++) {
            ret += _indenting_string;
        }
        return ret;
    }
}
class Vls.Token {
    public Vala.TokenType type;
    public Vala.SourceLocation start;
    public Vala.SourceLocation end;
}