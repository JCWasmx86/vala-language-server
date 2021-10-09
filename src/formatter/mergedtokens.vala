using Gee;

class Vls.MergedToken : GLib.Object {
    internal abstract string to_string(ref uint indent);
}
class Vls.File : Vls.MergedToken {
    Gee.List<MergedToken> children;
    internal string to_string(ref uint indent) {
        return "";
    }
    internal static Vls.File merge(Gee.List<Token> tokens) {
        var children = new Gee.ArrayList<MergedToken>();
        for(var i = 0; i < tokens.size; i++) {
            var token = tokens[i];
            if(token is Vls.Identifier) {
                if(token.content == "using") {
                    children.add(Vls.Using.merge(tokens, ref i));
                } else if(token.content == "namespace") {
                    children.add(Vls.Namespace.merge(tokens, ref i));
                }
            }
        }
    }
}
class Vls.Using : Vls.MergedToken {
    string name;
    internal static Vls.Using merge(Gee.List<Token> tokens, ref int i) {
        i++; // Skip "using" token
        string s = "";
        for(; i < tokens.size; i++) {
            var token = tokens[i];
            if(token.content == ";")
                break;
            else
                s += token.name;
        }
        return new Vls.Using() {
            name = s
        };
    }
}
class Vls.Namespace : Vls.MergedToken {
    string name;
    Gee.List<MergedToken> children;
    internal static Vls.Using merge(Gee.List<Token> tokens, ref int i) {
        i++; // Skip "namespace" token
        string s = "";
        for(; i < tokens.size; i++) {
            var token = tokens[i];
            if(token.content == "{")
                break;
            else
                s += token.name;
        }
        i++; // Skip "{"
        // Until now we have scanned "namespace foo.bar.baz {"
        var children = new Gee.List<MergedToken>();
        for(; i < tokens.size; i++) {
            var token = tokens[i];
            if(token.content == '}') {
                break;
            }
        }
        return null;
    }
}
class Vls.Class : Vls.MergedToken {
    Gee.List<MergedToken> children;
    Gee.List<MergedToken> parents;
    MergedToken name;
    Gee.List<MergedToken> modifiers;
    Gee.List<MergedToken> attributes;
}
class Vls.Attribute : Vls.MergedToken {
    MergedToken name;
    Gee.List<MergedToken> details;
}
class Vls.Method : Vls.MergedToken {
    MergedToken? access;
    MergedToken return_type;
    MergedToken name;
    Gee.List<MergedToken> arguments;
    Gee.List<MergedToken> errors;
    Gee.List<MergedToken> contracts;
    MergedToken body;
}
class Vls.Struct : Vls.MergedToken {
    MergedToken? access;
    MergedToken name;
    MergedToken? super;
    Gee.List<MergedToken> members;
}
class Vls.Delegate : Vls.MergedToken {
    MergedToken? access;
    bool is_static;
    MergedToken return_type;
    MergedToken name;
    Gee.List<MergedToken> arguments;
    Gee.List<MergedToken> errors;
}
class Vls.Enum : Vls.MergedToken {
    MergedToken? access;
    MergedToken name;
    Gee.List<MergedToken> members;
    Gee.List<MergedToken> methods;
    bool is_error = false;
}
class Vls.Interface : Vls.MergedToken {
    MergedToken? access;
    MergedToken name;
    Gee.List<MergedToken> parents;
    Gee.List<MergedToken> children;
}
class Vls.Field : Vls.MergedToken {

}

class Vls.TokenStream : Vls.MergedToken {
    Gee.List<Token> tokens;
}
class Vls.IdentifierString : Vls.MergedToken {
    string content;
}
class Vls.SingleToken : Vls.MergedToken {
    Token token;
}
class Vls.PreprocessorLine : Vls.MergedToken {
    Token name;
    Gee.List<Token> rest_of_line;
}