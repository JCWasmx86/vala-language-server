using Vala;
using Gee;

class Vls.FormattingVisitor : CodeVisitor {
    StringBuilder builder;
    // To allow building the file back.
    string tmp_string = "";

    uint indentation_depth = 0;

    FormattingConfig config;

    internal FormattingVisitor() {
        builder = new StringBuilder.sized (5000);
        config = new FormattingConfig();
    }
    public override void visit_addressof_expression (Vala.AddressofExpression expr) {
        expr.accept_children (this);
        tmp_string = "&" + tmp_string;
    }

    public override void visit_array_creation_expression (Vala.ArrayCreationExpression expr) {
        // TODO: Check, how to get the element type name.
        tmp_string = "new " + expr.element_type.to_string ();
        for(int i = 0; i < expr.rank - 1; i++) {
            tmp_string += "[]";
        }
        tmp_string += "[";
        // TODO: What is sizes? is it just for the last element?
        var tmp = tmp_string;
        tmp_string = tmp + tmp_string + "]";
        if(expr.initializer_list != null) {
            tmp = tmp_string;
            expr.initializer_list.accept (this);
            tmp_string = tmp + tmp_string;
        }

    }

    public override void visit_assignment(Vala.Assignment expr) {
        expr.left.accept_children (this);
        var left_side = tmp_string;
        expr.right.accept_children (this);
        var right_side = tmp_string;
        tmp_string = right_side + " " + expr.operator.to_string () + " " + left_side;
    }

    public override void visit_base_access(Vala.BaseAccess expr) {
        tmp_string =  "base";
    }

    public override void visit_binary_expression(Vala.BinaryExpression expr) {
        expr.left.accept_children (this);
        var left_side = tmp_string;
        expr.right.accept_children (this);
        var right_side = tmp_string;
        tmp_string = right_side + " " + expr.operator.to_string () + " " + left_side;
    }

    public override void visit_block(Vala.Block expr) {
        var sb = new StringBuilder.sized(2048);
        if(config.get_bool ("brace_on_next_line"))
            sb.append_c ('\n').append(generate_indentation ()).append("{\n");
        else
            sb.append("{\n");
        warning("Depth: %u", indentation_depth);
        indentation_depth++;
        foreach(var stmt in expr.get_statements ()) {
            stmt.accept (this);
            sb.append(tmp_string).append_c ('\n');
        }
        indentation_depth--;
        sb.append("\n").append(generate_indentation ()).append ("}\n");
        tmp_string = sb.str;
    }

    public override void visit_boolean_literal(Vala.BooleanLiteral expr) {
        tmp_string = expr.value ? "true" : "false";
    }
    
    public override void visit_break_statement(Vala.BreakStatement expr) {
        tmp_string = "break;";
    }
    public override void visit_cast_expression(Vala.CastExpression expr) {
        expr.inner.accept_children(this);
        if(expr.is_non_null_cast) {
            tmp_string = "(!) " + tmp_string;
        } else if(expr.is_silent_cast) {
            var inner = tmp_string;
            expr.type_reference.accept_children(this);
            tmp_string = inner + " as " + tmp_string;
        } else {
            var inner = tmp_string;
            expr.type_reference.accept_children(this);
            tmp_string = "(" + tmp_string + ") " + inner;
        }
    }
    
    public override void visit_catch_clause(Vala.CatchClause expr) {
        if(config.get_bool ("space_before_parentheses") && expr.variable_name != null)
            tmp_string = "catch ";
        else
            tmp_string = "catch";
        if(expr.variable_name != null)
            tmp_string += "(" + expr.error_type.to_string () + " " + expr.variable_name + ")";
        var tmp = tmp_string;
        expr.body.accept (this);
        tmp_string = tmp + tmp_string;
    }

    public override void visit_character_literal(Vala.CharacterLiteral expr) {
        tmp_string = expr.to_string();
    }

    public override void visit_class(Vala.Class expr) {
        var sb = new StringBuilder.sized (16 * 1024);
        // TODO: Check, whether there is really "internal"
        sb.append(expr.access.to_string ()).append_c (' ');
        if(expr.is_abstract)
            sb.append ("abstract ");
        if(expr.is_extern)
            sb.append ("extern ");
        sb.append ("class ").append (expr.to_string ());
        if(expr.has_type_parameters ()) {
            sb.append_c ('<');
            var parameters = expr.get_type_parameters ();
            for(var i = 0; i < parameters.size; i++) {
                sb.append (parameters.get (i).to_string ());
                if(i != parameters.size - 1)
                    sb.append(", ");
            }
            sb.append_c ('>');
        }
        var base_types = expr.get_base_types ();
        if(!base_types.is_empty) {
            sb.append(" : ");
            for(var i = 0; i < base_types.size; i++) {
                var bt = base_types.get (i);
                if(bt.source_reference == null)
                    continue;
                sb.append (bt.symbol.name);
                if(i != base_types.size - 1)
                    sb.append(", ");
            }
        }
        if(config.get_bool ("brace_on_next_line"))
            sb.append_c ('\n').append(generate_indentation ()).append("{\n");
        else
            sb.append(" {\n");
        indentation_depth++;
        foreach (var member in expr.get_members ()) {
            tmp_string = "";
            member.accept (this);
            sb.append (tmp_string);
        }
        indentation_depth--;
        sb.append("\n").append(generate_indentation ()).append ("}\n");
        tmp_string = sb.str;
    }

    public override void visit_conditional_expression(Vala.ConditionalExpression expr) {
        expr.condition.accept_children(this);
        var condition = tmp_string;
        expr.true_expression.accept_children(this);
        var true_expr = tmp_string;
        expr.false_expression.accept_children(this);
        var false_expr = tmp_string;
        tmp_string = condition + " ? " + true_expr + " : " + false_expr;
    }

    public override void visit_constant(Vala.Constant expr) {
        warning("Unimplemented Constant: %s", expr.to_string());
    }

    public override void visit_constructor(Vala.Constructor expr) {
        warning("Unimplemented Constructor: %s", expr.to_string());
    }
    
    public override void visit_continue_statement(Vala.ContinueStatement expr) {
        tmp_string = "continue;";
    }

    public override void visit_creation_method(Vala.CreationMethod expr) {
        warning("Unimplemented CreationMethod: %s", expr.to_string());
    }

    public override void visit_data_type(Vala.DataType expr) {
        
    }

    public override void visit_declaration_statement (DeclarationStatement stmt) {

    }

    public override void visit_delegate (Delegate d) {

    }

    public override void visit_delete_statement (DeleteStatement stmt) {
        stmt.expression.accept_children(this);
        tmp_string = "delete " + tmp_string + ";";
    }
    public override void visit_destructor (Destructor d) {
        
    }

    public override void visit_do_statement (DoStatement stmt) {
        
    }
    public override void visit_element_access (ElementAccess expr) {

    }

    public override void visit_empty_statement (EmptyStatement stmt) {
        tmp_string = ";";
    }

    public override void visit_enum (Enum en) {

    }

    public override void visit_enum_value (Vala.EnumValue ev) {

    }

    public override void visit_error_code (ErrorCode ecode) {

    }

    public override void visit_error_domain (ErrorDomain edomain) {

    }

    public override void visit_expression (Expression expr) {

    }

    public override void visit_expression_statement (ExpressionStatement stmt) {

    }

    public override void visit_field (Field f) {

    }

    public override void visit_for_statement (ForStatement stmt) {

    }

    public override void visit_foreach_statement (ForeachStatement stmt) {

    }

    public override void visit_formal_parameter (Vala.Parameter p) {

    }

    public override void visit_if_statement (IfStatement stmt) {

    }

    public override void visit_initializer_list (InitializerList list) {

    }

    public override void visit_integer_literal (IntegerLiteral lit) {
        tmp_string = lit.to_string ();
    }

    public override void visit_interface (Interface iface) {
        
    }

    public override void visit_lambda_expression (LambdaExpression expr) {

    }

    public override void visit_local_variable (LocalVariable local) {

    }

    public override void visit_lock_statement (LockStatement stmt) {
        
    }

#if VALA_0_52
    public override void visit_loop_statement (Vala.LoopStatement stmt) {
#else
    public override void visit_loop (Vala.Loop stmt) {
#endif
    }

    public override void visit_member_access (MemberAccess expr) {

    }

    public override void visit_method (Method m) {
        var sb = new StringBuilder.sized(4 * 1024);
        sb.append (m.access.to_string ()).append_c (' ');
        if(m.is_async_callback)
            sb.append ("async ");
        if(m.is_extern)
            sb.append ("extern ");
        if(m.is_inline)
            sb.append ("inline ");
        if(!m.is_class_member ())
            sb.append ("static ");
        if(m.is_abstract)
            sb.append ("abstract ");
        if(m.is_virtual)
            sb.append ("virtual ");
        if(m.overrides)
            sb.append ("override ");
        sb.append (m.return_type.to_string ()).append_c (' ').append (m.name);
        if(m.has_type_parameters ()) {
            sb.append_c ('<');
            var parameters = m.get_type_parameters ();
            for(var i = 0; i < parameters.size; i++) {
                sb.append (parameters.get (i).to_string ());
                if(i != parameters.size - 1)
                    sb.append(", ");
            }
            sb.append_c ('>');
        }
        if(config.get_bool ("space_before_parentheses"))
            sb.append_c (' ');
        sb.append_c ('(');
        var parameters = m.get_parameters ();
        for(int i = 0; i < parameters.size; i++) {
            sb.append (parameters.get (i).to_string ());
            if(i != parameters.size - 1)
                sb.append (", ");
        }
        sb.append (") ");
        var thrown = new Vala.ArrayList<DataType>();
        // TODO: Sort?
        m.get_error_types (thrown);
        if(thrown.size > 0) {
            sb.append ("throws ");
            for(int i = 0; i < thrown.size; i++) {
                sb.append (thrown.get (i).to_string ());
                if(i != thrown.size)
                    sb.append(", ");
            }
        }
        if(m.is_abstract)
            sb.append (";\n");
        else {
            tmp_string = "";
            m.body.accept (this);
            sb.append (tmp_string);
        }
        tmp_string = sb.str;
    }

    public override void visit_method_call (MethodCall expr) {

    }

    public override void visit_named_argument (NamedArgument expr) {

    }

    public override void visit_namespace (Namespace ns) {
        if(config.get_bool("indent_after_namespace"))
            indentation_depth++;
        
    }

    public override void visit_null_literal (NullLiteral lit) {
        tmp_string = "null";
    }

    public override void visit_object_creation_expression (ObjectCreationExpression expr) {

    }

    public override void visit_pointer_indirection (PointerIndirection expr) {

    }

    public override void visit_postfix_expression (PostfixExpression expr) {
        expr.inner.accept_children (this);
        tmp_string += (expr.increment ? "++" : "--");
    }

    public override void visit_property (Property prop) {

    }

    public override void visit_property_accessor (PropertyAccessor acc) {

    }

    public override void visit_real_literal (RealLiteral lit) {

    }

    public override void visit_reference_transfer_expression (ReferenceTransferExpression expr) {

    }

    public override void visit_regex_literal (RegexLiteral lit) {

    }

    public override void visit_return_statement (ReturnStatement stmt) {
        stmt.return_expression.accept_children (this);
        tmp_string = "return " + tmp_string;
    }

    public override void visit_signal (Vala.Signal sig) {

    }

    public override void visit_sizeof_expression (SizeofExpression expr) {
        
    }

    public override void visit_slice_expression (SliceExpression expr) {

    }

    public override void visit_source_file (SourceFile source_file) {
        if(config.get_bool ("sort_usings")) {
            source_file.current_using_directives.sort ((a, b) => {
                return ((Namespace) a.namespace_symbol).name.collate(((Namespace) b.namespace_symbol).name);
            });
        }

        foreach (var directive in source_file.current_using_directives) {
            // E.g. implicit using GLib
            if(directive.source_reference == null)
                continue;
            tmp_string = "";
            directive.accept (this);
            this.builder.append (tmp_string).append_c ('\n');
        }
        this.builder.append ("\n\n");
        foreach (var node in source_file.get_nodes ()) {
            tmp_string = "";
            node.accept (this);
            this.builder.append (tmp_string).append_c ('\n');
        }
        GLib.stderr.puts (this.builder.str);
    }

    public override void visit_string_literal (StringLiteral lit) {

    }

    public override void visit_struct (Struct st) {

    }

    public override void visit_switch_label (SwitchLabel label) {

    }

    public override void visit_switch_section (SwitchSection section) {

    }

    public override void visit_switch_statement (SwitchStatement stmt) {

    }

    public override void visit_template (Template tmpl) {

    }

    public override void visit_throw_statement (ThrowStatement stmt) {
        stmt.accept_children (this);
        tmp_string = "throw " + tmp_string + ";";
    }

    public override void visit_try_statement (TryStatement stmt) {

    }

    public override void visit_tuple (Tuple tuple) {

    }

    public override void visit_type_check (TypeCheck expr) {

    }

    public override void visit_type_parameter (TypeParameter p)  {

    }

    public override void visit_typeof_expression (TypeofExpression expr) {

    }
    public override void visit_unary_expression (UnaryExpression expr) {
        expr.inner.accept_children (this);
        tmp_string = expr.operator.to_string () + tmp_string;
    }

    public override void visit_unlock_statement (UnlockStatement stmt) {
        stmt.accept_children (this);
        tmp_string = "unlock(" + tmp_string + ")";
    }

    public override void visit_using_directive (UsingDirective ns) {
        tmp_string = "using " + ((Namespace) ns.namespace_symbol).name + ";";
    }

    public override void visit_while_statement (WhileStatement stmt) {

    }

#if VALA_0_50
    public override void visit_with_statement (Vala.WithStatement stmt) {
        
    }
#endif


    public override void visit_yield_statement (YieldStatement y) {

    }
    string generate_indentation () {
        // TODO: StringBuilder or caching instead of this loop?
        string ret = "";
        for (var i = 0; i < this.indentation_depth; i++) {
            ret += "\t";
        }
        return ret;
    }
}