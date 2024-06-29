/*
 * This is comment for this file.
 */

%{
// Prologue
%}

%code provides {

static enum yytokentype yylex(YYSTYPE *lval, YYLTYPE *yylloc);
static void yyerror(YYLTYPE *yylloc, const char *msg);

}

%expect 0
%define api.pure
%define parse.error verbose

%union {
    int i;
}

%token <i> number

%%

program         : expr
                ;

expr            : term '+' expr
                | term
                ;

term            : factor '*' term
                | factor
                ;

factor          : number
                ;

%%

// Epilogue

static enum yytokentype
yylex(YYSTYPE *lval, YYLTYPE *yylloc)
{
    return (enum yytokentype)(0);
}

static void yyerror(YYLTYPE *yylloc, const char *msg)
{
    (void) msg;
}

int main(int argc, char *argv[])
{
}
