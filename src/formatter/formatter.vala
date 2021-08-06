using Gee;

class Vls.Formatter : Object{
    private Pair <Vala.SourceFile, Compilation> _input;
    private Lsp.FormattingOptions _options;
    private int _start_line;
    private int _end_line;
    private string _indenting_string;

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
        _indenting_string = options.insertSpaces ? string.nfill (options.tabSize, ' ')  : "\t";
    }

    /**
    * Format the source file. If an error occurs, error is set and a non-null
    * error string is returned. Otherwise "edit" is set.
    */
    public string? format (out Lsp.TextEdit edit, out Jsonrpc.ClientError error) {
        error = 0;
        var new_lines = new ArrayList < string >();
        var expected_indentation_depth = 0;
        var source_file = _input.first;
        bool is_in_multiline_comment = false;
        for (int i = _start_line; i <= _end_line; i++) {
            warning("LINE:                                               %d", i);
            // + 1, as libvala expects the line number to be 1-based,
            // while LSP provides it as 0-based.
            var line_to_format = source_file.get_source_line (i+ 1);
            // EOF reached
            if(line_to_format == null) {
                break;
            }
            var trimmed_line = line_to_format.strip ();
            // Indented lines with no other content are replaced by really empty lines
            if(trimmed_line.length == 0) {
                new_lines.add (is_in_multiline_comment ? (generate_indentation (expected_indentation_depth) + " *") : "");
                continue;
            }
            if(is_in_multiline_comment) {
                var indent = generate_indentation (expected_indentation_depth) +"";
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
            string ? raw_string = null;
            // Skip multiline comments, that are just one line
            if(trimmed_line.has_prefix ("/* ") || trimmed_line.has_prefix ("/** ") && trimmed_line.has_suffix ("*/")) {
                raw_string = trimmed_line;
            } else if(trimmed_line.has_prefix ("/*")) {
                is_in_multiline_comment = true;
                var is_doc = trimmed_line.has_prefix ("/**");
                var maybe_string = trimmed_line.slice (is_doc ? 3 : 2, trimmed_line.length).strip ();
                var indent = generate_indentation (expected_indentation_depth);
                new_lines.add (indent + (is_doc ? "/**" : "/*"));
                if(maybe_string.length > 0) {
                    new_lines.add (indent +" * " + maybe_string);
                }
                continue;
            } else if (trimmed_line.has_prefix ("//")) {
                // Convert "//<someComment>" to "// <someComment>"
                var comment = trimmed_line.slice (2, trimmed_line.length).strip ();
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
                raw_string = format_line (format_line (trimmed_line));
            }
            new_lines.add (generate_indentation (expected_indentation_depth) + raw_string);
        }
        var new_file = new StringBuilder.sized (new_lines.size * 80);
        foreach (var line in new_lines) {
            new_file.append (line);
            // Or use a platform dependent one? \n works everywhere
            new_file.append_c ('\n');
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
            newText = new_file.str.strip () +"\n"
        };
        return null;
    }
    string format_line (string l) {
        var l_new = l;
        if(!l.contains("\"") && !l.contains("\'")) {
            l_new = l.replace ("  ", " ").replace ("\t\t", "\t");
            l_new = l_new.replace (") (", ")(");
        }
        var sb = new StringBuilder ();
        for(var i = 0; i < l_new.length; i++) {
            var current_char = (char) l_new.data[i];
            var next_char = (char)(i + 1 < l_new.length  ? l_new.data[i + 1] : '\0');
            var overnext_char = (char)(i + 2 < l_new.length  ? l_new.data[i + 2] : '\0');
            var last_char = (char)(sb.len == 0  ? '\0' : sb.str.data[i - 1]);
            warning("Is at %d (%c)\n", i, current_char);
            if(current_char == '\'') {
                sb.append_c ('\'');
                sb.append_c (next_char);
                warning("Found char literal, next_char = %c, onc = %c", next_char, overnext_char);
                if(next_char == '\\') {
                    // Skip \
                    i++;
                    sb.append_c (overnext_char);
                }
                //Skip char and '
                i += 2;
                sb.append_c ('\'');
                warning(sb.str);
                continue;
            }
            if(current_char == '\"') {
                uint count_to_find =0;
                if(next_char == '\"' && overnext_char == '\"') {
                    sb.append_c ('\"').append_c ('\"');
                    count_to_find = 3;
                    i += 3;
                } else if(next_char != '\"'){
                    count_to_find = 1;
                    i++;
                } else {
                    return l;
                }
                warning("To find: %u", count_to_find);
                sb.append_c ('\"');
                while(i < l_new.length) {
                    var c = l_new.data[i];
                    sb.append_c ((char)c);
                    if(c == '\"') {
                        if(count_to_find == 1) {
                            i++;
                            break;
                        } else {
                            if(i + 3 < l_new.length) {
                                if(l_new.data[i + 1] == '\"' && l_new.data[i + 2] == '\"') {
                                    i += 3;
                                    sb.append_c ('\"').append_c ('\"');
                                    break;
                                }
                            }
                        }
                    } else if(c == '\\') {
                        i++;
                        sb.append_c (l_new[i]);
                        i++;
                    } else {
                        i++;
                    }
                }
                warning(sb.str);
                sb.append_c (l_new[i]);
                continue;
            }
            if(current_char.isalnum() || current_char == '_') {
                sb.append_c(current_char);
                warning(sb.str);
                continue;
            }
            if(current_char.isspace () && next_char.isspace ()) {
                sb.append_c (current_char);
                i++;
                warning(sb.str);
                continue;
            }
            if((current_char == ':' && !sb.str.contains("case ")) || current_char == '?') {
                if (!last_char.isspace ())
                    sb.append_c (' ');
                sb.append_c (current_char);
                if (!next_char.isspace ())
                    sb.append_c (' ');
                warning(sb.str);
                continue;
            }
            if(last_char.isalnum () && current_char == '(') {
                sb.append_c (' ').append_c ('(');
                warning(sb.str);
                continue;
            }
            if(last_char == ',' && !current_char.isspace ()) {
                sb.append_c (' ').append_c (current_char);
                warning(sb.str);
                continue;
            }
            if(current_char == ')' && next_char.isspace () && overnext_char == '(') {
                sb.append_c (')').append ("(");
                i += 2;
                warning(sb.str);
                continue;
            }
            if(current_char == '<') {
                var saved_i = i;
                i++; // Skip '<'
                var found_generics = false;
                var open_pointy_parentheses = 1;
                while(true) {
                    var looked_at = l_new.data[i];
                    i++;
                    // We can have e.g. Gee.List<Gee.List<T>>, nested generics
                    if(looked_at == '<')
                        open_pointy_parentheses++;
                    else if(looked_at == '>') {
                        open_pointy_parentheses--;
                        if(open_pointy_parentheses == 0) {
                            found_generics = true;
                            break;
                        }
                    // This is not a generic, this is just a "<"(Or "<<", "<<=")
                    } else if(looked_at == ')' || looked_at == '&' ||looked_at == '|' || looked_at == '(' || looked_at == '=' || looked_at == '<') {
                        break;
                    }
                    if(i == l_new.length)
                        break;
                }
                if(found_generics) {
                    //Add spaces after commas
                    var string_to_add = l_new.slice (saved_i, i + 1).replace (" ", "").replace (",", ", ");
                    sb.append (string_to_add);
                } else {
                    i = saved_i;
                    if(!last_char.isspace ())
                        sb.append_c (' ');
                    if(next_char == current_char && overnext_char == '=') {
                        i += 2;
                        sb.append ("<<=");
                    } else if(next_char == '='){
                        i++;
                        sb.append ("<=");
                    } else if (next_char == current_char) {
                        i++;
                        sb.append ("<<");
                    } else {
                        sb.append_c ('<');
                    }
                    if(!next_char.isspace ())
                        sb.append_c (' ');
                }
                warning(sb.str);
                continue;
            }
            int length_of_op;
            if(this.is_op (l_new, i, out length_of_op)) {
                //Special case for pre-/post increment
                if(length_of_op == -1) {
                    i++;
                    sb.append_c (current_char).append_c (current_char);
                    warning(sb.str);
                    continue;
                } else {
                    i += length_of_op - 1;
                    sb.append_c(current_char);
                    if(length_of_op == 2)
                        sb.append_c (next_char);
                    if(length_of_op == 3)
                        sb.append_c (overnext_char);
                    warning(sb.str);
                    continue;
                }
            }
            warning(sb.str);
            sb.append_c (current_char);
        }
        var l_new2 = sb.str;
        if(!sb.str.contains("\"") && !sb.str.contains("\'")) {
            l_new2 = sb.str.replace ("  ", " ").replace ("\t\t", "\t");
            l_new2 = l_new2.replace (") (", ")(").replace (" )", ")");
        }
        warning("Returning: %s", sb.str);
        return sb.str;
    }
    bool is_op(string l, uint current_index, out int length) {
        length = 0;
        var current_char = l.data[current_index];
        var next_char = current_index + 1 < l.length? l.data[current_index + 1] : '\0';
        switch(current_char) {
            case '&':
                if(next_char == '&' || next_char == '=')
                    length = 2;
                else
                    length = 1;
                return true;
            case '|':
                if(next_char == '|' || next_char == '=')
                    length = 2;
                else
                    length = 1;
                return true;
            case '+':
                if(next_char == '+')
                    length = -1;
                else if(next_char == '=')
                    length = 2;
                else
                    length = 1;
                return true;
            case '-':
                if(next_char == '-')
                    length = -1;
                else if(next_char == '=')
                    length = 2;
                else
                    length = 1;
                return true;
            case '^':
            case '*':
            case '/':
            case '%':
            case '=':
                if(next_char == '=')
                    length = 2;
                else
                    length = 1;
                return true;
            case '!':
                if(next_char == '=')
                    length = 2;
                else
                    return false;
                return true;
            case 'a':
                if(next_char == 's') {
                    length = 2;
                    return true;
                }
                return false;
            case 'i':
                if(next_char == 'n' || next_char == 's') {
                    length = 2;
                    return true;
                }
                return false;
            case '>':
                // Check for >>
                if(next_char == current_char) {
                    length = 2;
                    // Check for >>=
                    if(current_index + 2 < l.length && l.data[current_index + 2] == '=') {
                        length = 3;
                    }
                    return true;
                }
                //Check for >=
                if(next_char == '=') {
                    length = 2;
                    return true;
                }
                length = 0;
                return false;
        }
        // '<' is handled with the generics
        return false;
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
