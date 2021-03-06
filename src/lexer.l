%option yylineno nodefault noyywrap noinput nounput
%option never-interactive
%option reentrant
%{
#include "driver.h"
#include "parser.tab.hh"

#undef yywrap
#define yywrap(x) 1

static bpftrace::location loc;
static std::string string_buffer;

#define YY_USER_ACTION loc.columns(yyleng);
#define yyterminate() return bpftrace::Parser::make_END(loc)

using namespace bpftrace;
%}

ident  [_a-zA-Z][_a-zA-Z0-9]*
map    @{ident}|@
var    ${ident}
int    [0-9]+|0[xX][0-9a-fA-F]+
hspace [ \t]
vspace [\n\r]
space  {hspace}|{vspace}
path   :(\\.|[_\-\./a-zA-Z0-9])*:
header <(\\.|[_\-\./a-zA-Z0-9])*>
%x STR

%%

%{
  loc.step();
%}

{hspace}+               { loc.step(); }
{vspace}+               { loc.lines(yyleng); loc.step(); }
"//".*$  // Comments

pid|tid|uid|gid|nsecs|cpu|comm|stack|ustack|arg[0-9]|retval|func {
                          return Parser::make_BUILTIN(yytext, loc); }
{ident}                 { return Parser::make_IDENT(yytext, loc); }
{path}                  { return Parser::make_PATH(yytext, loc); }
{header}                { return Parser::make_HEADER(yytext, loc); }
{map}                   { return Parser::make_MAP(yytext, loc); }
{var}                   { return Parser::make_VAR(yytext, loc); }
{int}                   { return Parser::make_INT(strtoul(yytext, NULL, 0), loc); }
":"                     { return Parser::make_COLON(loc); }
";"                     { return Parser::make_SEMI(loc); }
"{"                     { return Parser::make_LBRACE(loc); }
"}"                     { return Parser::make_RBRACE(loc); }
"["                     { return Parser::make_LBRACKET(loc); }
"]"                     { return Parser::make_RBRACKET(loc); }
"("                     { return Parser::make_LPAREN(loc); }
")"                     { return Parser::make_RPAREN(loc); }
\//{space}*[\/\{]       { return Parser::make_ENDPRED(loc); } // If "/" is followed by "/" or "{", choose ENDPRED, otherwise DIV
","                     { return Parser::make_COMMA(loc); }
"="                     { return Parser::make_ASSIGN(loc); }
"=="                    { return Parser::make_EQ(loc); }
"!="                    { return Parser::make_NE(loc); }
"<="                    { return Parser::make_LE(loc); }
">="                    { return Parser::make_GE(loc); }
"<"                     { return Parser::make_LT(loc); }
">"                     { return Parser::make_GT(loc); }
"&&"                    { return Parser::make_LAND(loc); }
"||"                    { return Parser::make_LOR(loc); }
"+"                     { return Parser::make_PLUS(loc); }
"-"                     { return Parser::make_MINUS(loc); }
"*"                     { return Parser::make_MUL(loc); }
"/"                     { return Parser::make_DIV(loc); }
"%"                     { return Parser::make_MOD(loc); }
"&"                     { return Parser::make_BAND(loc); }
"|"                     { return Parser::make_BOR(loc); }
"^"                     { return Parser::make_BXOR(loc); }
"!"                     { return Parser::make_LNOT(loc); }
"~"                     { return Parser::make_BNOT(loc); }
"#include"              { return Parser::make_INCLUDE(loc); }
"."                     { return Parser::make_DOT(loc); }
"->"                    { return Parser::make_PTR(loc); }

\"                      { BEGIN(STR); string_buffer.clear(); }
<STR>\"                 { BEGIN(INITIAL); return Parser::make_STRING(string_buffer, loc); }
<STR>[^\\\n\"]+         { string_buffer += std::string(yytext); }
<STR>\\n                { string_buffer += std::string("\n"); }
<STR>\\t                { string_buffer += std::string("\t"); }
<STR>\\\"               { string_buffer += std::string("\""); }
<STR>\\\\               { string_buffer += std::string("\\"); }
<STR>\n                 { driver.error(loc, std::string("unterminated string")); }
<STR><<EOF>>            { driver.error(loc, std::string("unterminated string")); }
<STR>\\.                { driver.error(loc, std::string("invalid escape character '") +
                                            std::string(yytext) + std::string("'")); }
<STR>.                  { driver.error(loc, std::string("invalid character '") +
                                            std::string(yytext) + std::string("'")); }

.                       { driver.error(loc, std::string("invalid character '") +
                                            std::string(yytext) + std::string("'")); }

%%
