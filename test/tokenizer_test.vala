using Gee;
using Vls;

void test_keywords() {
    var lines = lineify(
        """
            class namespace errordomain as is new static construct static 
        """
    );
    var expected_tokens = new ArrayList<Token>();
    expected_tokens.add(new Keyword("class"));
    expected_tokens.add(new Keyword("namespace"));
    expected_tokens.add(new Keyword("errordomain"));
    expected_tokens.add(new Keyword("as"));
    expected_tokens.add(new Keyword("is"));
    expected_tokens.add(new Keyword("new"));
    expected_tokens.add(new Keyword("static construct"));
    expected_tokens.add(new Keyword("static"));
    var tokenizer = new Tokenizer.with_lines(lines);
    var tokens = tokenizer.tokenize();
    assert(expected_tokens.size == tokens.size);
    for(var i = 0; i < expected_tokens.size; i++) {
        assert(expected_tokens.@get(i).equals(tokens.@get(i)));
    }
}
Gee.List<string> lineify(string line) {
    var lines = line.split("\n");
    var ret = new ArrayList<string>();
    foreach(var l in lines) {
        if(l != null)
            ret.add(l);
    }
    return ret;
}
public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/test_keywords", test_keywords);
    return Test.run ();
}