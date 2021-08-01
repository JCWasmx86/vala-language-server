using Gee;

class Vls.FormattingConfig {
    Map<string, uint> int_values;
    Map<string, bool> bool_values;
    internal FormattingConfig() {
        int_values = new HashMap<string, uint>();
        bool_values = new HashMap<string, bool>();
        init_default();
    }

    void init_default() {
        int_values.clear();
        // The maximum line length. This is just a soft limit at the moment
        int_values.@set("line_length", 120);
        // How much a tab counts (Used for calculating the line length)
        int_values.@set("spaces_per_tab", 8);

        bool_values.clear();
        // Indent with spaces_per_tab spaces
        bool_values.@set("prefer_spaces", false);
        // Whether to sort using-directives
        bool_values.@set("sort_usings", true);
        // Whether to add a newline after a curly brace.
        bool_values.@set("brace_on_next_line", false);
        // Whether to indent in namespaces.
        // namespace foo {         namespace foo {
        // class bar{}          vs   class bar{}
        // }                       }
        bool_values.@set("indent_after_namespace", true);
        // Whether to sort the parents of a class alphabetically.
        bool_values.@set("sort_parents", false);
        // Whether to add a newline at the end.
        bool_values.@set("newline_at_end", true);
        // Whether to add a space between identifier/word and opening parentheses
        // "foo(" vs "foo ("
        bool_values.@set("space_before_parentheses", false);
    }

    internal bool get_bool(string identifier) {
        return this.bool_values.@get(identifier);
    }

    // internal uint get_int(string identifier) {
    //     return this.int_values.@get(identifier);
    // }
}
