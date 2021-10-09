using Gee;

class Vls.TokenMerger {
    Gee.List<Token> tokens;

    internal TokenMerger(Gee.List<Token> tokens) {
        this.tokens = tokens;
    }
    void merge() {
        Vls.File.merge(tokens);
    }
}