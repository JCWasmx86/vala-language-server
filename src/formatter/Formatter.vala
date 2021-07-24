using Gee;

class Vls.Formatter : Object{
    private Pair<Vala.SourceFile, Compilation> _input;
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
        _indenting_string = options.insertSpaces ? string.nfill (options.tabSize, ' ') : "\t";
    }

    /**
    * Format the source file. If an error occurs, error is set and a non-null
    * error string is returned. Otherwise "edit" is set.
    */
    public string? format (out Lsp.TextEdit edit, out Jsonrpc.ClientError error) {
        error = 0;
        var new_lines = new ArrayList<string>();
        var expected_indentation_depth = 0;
        var source_file = _input.first;
        int i = _start_line;
        int real_end_line = 0;
        for (i = _start_line; i <= _end_line; i++) {
            // + 1, as libvala expects the line number to be 1-based,
            // while LSP provides it as 0-based.
            var line_to_format = source_file.get_source_line (i + 1);
            if(line_to_format == null) {
                break;
            }
            real_end_line = i;
            var trimmed_line = line_to_format.strip ();
            // Indented lines with no other content are replaced by really empty lines
            if(trimmed_line.length == 0) {
                new_lines.add("");
                continue;
            }
            string? raw_string = null;
            if (trimmed_line.has_prefix ("//")) {
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
                    line = real_end_line,
                    character = 1
                }
            },
            // Just one final newline
            newText = new_file.str.strip() + "\n"
        };
        return null;
    }

    string generate_indentation (int repeats) {
        // TODO: StringBuilder or caching instead of this loop?
        string ret = "";
        for (var i = 0; i < repeats; i++) {
            ret += _indenting_string;
        }
        return ret;
    }
}
