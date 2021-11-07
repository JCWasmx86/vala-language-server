using Gee;

class Vls.Formatter : Object {
    private Pair<Vala.SourceFile, Compilation> input;
    private Lsp.FormattingOptions options;
    private int start_line;
    private int end_line;
    private string indent_string;

    public Formatter (Lsp.FormattingOptions options, Pair<Vala.SourceFile, Compilation> input, Lsp.Range? range) {
        this.options = options;
        this.input = input;
        if (range == null) {
            start_line = 0;
            end_line = int.MAX;
        } else {
            start_line = (int) range.start.line;
            end_line = (int) range.end.line;
        }
        indent_string = options.insertSpaces ? string.nfill (options.tabSize, ' ') : "\t";
    }

    public string? format (out Lsp.TextEdit edit, out Jsonrpc.ClientError error) {
        error = 0;
        var new_lines = new ArrayList<string> ();
        var source_file = input.first;
        var is_at_eof = false;
        for (var i = start_line; i <=  end_line; i++) {
            var line_to_format = source_file.get_source_line (i + 1);
            // EOF reached
            if (line_to_format == null) {
                is_at_eof = true;
                break;
            }
            if (options.trimTrailingWhitespace)
                line_to_format = line_to_format.chomp ();
            line_to_format = fix_indenting (line_to_format);
        }
        if(source_file.get_source_line (end_line + 2) == null)
            is_at_eof = true;
        if (is_at_eof)
            fix_eof (new_lines);

        // Estimate just 80 chars per line
        var new_file = new StringBuilder.sized (new_lines.size * 80);
        for (var i = 0; i  < new_lines.size; i++) {
            new_file.append (new_lines.get (i));
            if(is_at_eof && i == new_lines.size)
                break;
            new_file.append_c ('\n');
        }
        edit = new Lsp.TextEdit () {
            range = new Lsp.Range () {
                start = new Lsp.Position () {
                    line = start_line,
                    character = -1 // If I choose "0", the first character is cut away
                },
                end = new Lsp.Position () {
                    line = start_line + new_lines.size,
                    // Just for the trailing newline
                    character = 1
                }
            },
            newText = new_file.str
        };
        return null;
    }

    void fix_eof (ArrayList<string> lines) {
        if(options.insertFinalNewline && lines.last () != "") {
            lines.add ("");
            return;
        }
        if (options.trimFinalNewlines) {
            for (var i = lines.size  - 1; i >= 0; i--) {
                if(lines.get (i) == "")
                    lines.remove_at (i);
            }
            lines.add ("");
        }
    }
    string fix_indenting (string line) {
        if(line.length == 0)
            return line;
        var real_char_offset = 0;
        for (var i = 0; i < line.length; i++) {
            var c = line.get (i);
            if (c  != ' ' && c != '\t') {
                if (c  == '\r'  || c  == '\n')
                    return "";
                real_char_offset = i;
                break;
            }
        }
        var indent_string = line.substring (0, real_char_offset);
        var spaces_to_tab = string.nfill (options.tabSize, ' ');
        if (this.options.insertSpaces) 
            indent_string = indent_string.replace ("\t", this.indent_string);
        else
            indent_string = indent_string.replace (spaces_to_tab, "\t");
        return indent_string + line.substring (real_char_offset == 0 ? 0 : real_char_offset - 1);
    }
}
