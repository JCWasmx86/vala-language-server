using Gee;
using Vala;


int main (string[] args) {
    if(args.length == 1) {
        GLib.stderr.puts ("Expected path to directory containing two folders: `input' and `expected'");
        return 1;
    }
    var path = args[1];
    var input = path + "/input";
    var expected = path + "/expected";
    var files = 0;
    var errors = 0;
    var skipped = 0;
    try {
        var enumerator = File.new_for_path(input).enumerate_children ("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        FileInfo info = null;
        while ((info = enumerator.next_file ()) != null) {
            if(!info.get_name ().has_suffix (".vala"))
                continue;
            files++;
            var name = input + "/" + info.get_name ();
            var expected_output_name = expected + "/" + info.get_name ();
            if(!File.new_for_path (expected_output_name).query_exists ()) {
                warning ("Couldn't find %s", expected_output_name);
                skipped++;
                continue;
            }
            var code_context = new CodeContext ();
            code_context.add_source_filename (name, true, false);
            Vala.CodeContext.push (code_context);
            var visitor = new Vls.FormattingVisitor();
            var parser = new Parser();
            parser.parse (code_context);
            var file = code_context.get_source_file (name);
            file.accept (visitor);
            string expected_contents;
            size_t len;
            FileUtils.get_contents (expected_output_name, out expected_contents, out len);
            if(expected_contents != visitor.get_string()) {
                warning("Formatting %s failed!", info.get_name ());
                errors++;
                var return_value = FileUtils.set_contents (expected + "/" + info.get_name() + ".real", visitor.get_string ());
                assert(return_value);
            }
            Vala.CodeContext.pop ();
        }
    } catch(GLib.Error e) {
        critical ("%s", e.message);
        return 1;
    }
    stdout.printf("Looked at %u files\n", files);
    var successes = files - (errors + skipped);
    stdout.printf("%u were successfully formatted (%.2lf%%)\n", successes, (successes / (double) files) * 100);
    stdout.printf("%u were skipped (%.2lf%%)\n", skipped, (skipped / (double) files) * 100);
    stdout.printf("%u failed (%.2lf%%)\n", errors, (errors / (double) files) * 100);
    return errors > 0 ? 1 : 0;
}