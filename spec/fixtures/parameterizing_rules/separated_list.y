/*
 * This is comment for this file.
 */

%{
// Prologue
static int yylex(YYSTYPE *val, YYLTYPE *loc);
static int yyerror(YYLTYPE *loc, const char *str);
%}

%include-stdlib

%union {
    int i;
}

%token <i> number

%%

program         : separated_list(',', number)
                ;

%%

static int yylex(YYSTYPE *yylval, YYLTYPE *loc) {
{
  return 0;
}

static int yyerror(YYLTYPE *loc, const char *str) {
{
  return 0;
}

int main(int argc, char *argv[])
{
}
