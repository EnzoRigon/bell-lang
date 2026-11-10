%{
/* ==========================================================================
   ANALISADOR LEXICO (FLEX) -- Linguagem bell
   Trabalho do Grau B -- Compiladores -- UNISINOS

   Papel deste arquivo (analisador.l) no Grau B:
   1) Agrupa os caracteres do arquivo em lexemas;
   2) Rastreia linha (yylineno) e colunas (token_col_ini, token_col_fim);
   3) Identifica a categoria (token) de cada lexema;
   4) Para identificadores e literais numericos, guarda o texto em 'yylval.texto'
      (usado na Tabela de Simbolos e na Traducao Pos-Fixada);
   5) Devolve o codigo do token (ex.: T_INT, T_ID, T_MAIS) para o Bison!
   ========================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "semantico.h"
#include "analisador.tab.h" /* Cabecalho gerado pelo Bison com os tokens T_... */

int erros_lexicos = 0;      /* Contador de erros lexicos */
int num_tokens = 0;         /* Contador de tokens validos reconhecidos */

/* Controle de posicao de colunas (base 1) e modo de listagem de tokens (--tokens) */
int listar_tokens = 0;
int coluna_atual  = 1;
int token_col_ini = 1;
int token_col_fim = 1;

/* YY_USER_ACTION eh executada automaticamente pelo Flex antes de cada regra,
   atualizando a coluna inicial e final do lexema recem-lido. */
#define YY_USER_ACTION \
    token_col_ini = coluna_atual; \
    for (int i = 0; i < yyleng; i++) { \
        if (yytext[i] == '\n') { \
            coluna_atual = 1; \
        } else { \
            coluna_atual++; \
        } \
    } \
    token_col_fim = coluna_atual - 1;

void registrar_token_lexico(const char *categoria) {
    if (listar_tokens) {
        printf("%d %d %d %-20s %s\n",
               yylineno, token_col_ini, token_col_fim, categoria, yytext);
    }
}

void erro_lexico(const char *msg) {
    if (!listar_tokens) {
        printf("  [%s - ERRO LEXICO] linha %d: %s\n", NOME_LINGUAGEM, yylineno, msg);
    }
    erros_lexicos++;
}
%}

%option noyywrap yylineno
%option nounput noinput

/* Apelidos para expressoes regulares basicas */
LETRA   [A-Za-z_]
DIGITO  [0-9]
ID      {LETRA}({LETRA}|{DIGITO})*

%%

 /* -------------------------------------------------------------------------
    1. PALAVRAS RESERVADAS DA LINGUAGEM (Estilo C)
    Devem vir ANTES da regra de identificador ({ID}) para terem prioridade.
    ------------------------------------------------------------------------- */
"int"       { num_tokens++; registrar_token_lexico("TIPO"); return T_INT; }
"float"     { num_tokens++; registrar_token_lexico("TIPO"); return T_FLOAT; }
"if"        { num_tokens++; registrar_token_lexico("PALAVRA_RESERVADA"); return T_IF; }
"else"      { num_tokens++; registrar_token_lexico("PALAVRA_RESERVADA"); return T_ELSE; }
"switch"    { num_tokens++; registrar_token_lexico("PALAVRA_RESERVADA"); return T_SWITCH; }
"case"      { num_tokens++; registrar_token_lexico("PALAVRA_RESERVADA"); return T_CASE; }
"break"     { num_tokens++; registrar_token_lexico("PALAVRA_RESERVADA"); return T_BREAK; }
"default"   { num_tokens++; registrar_token_lexico("PALAVRA_RESERVADA"); return T_DEFAULT; }

 /* -------------------------------------------------------------------------
    2. IDENTIFICADORES E ERRO LEXICO DE ID COMECANDO COM DIGITO
    ------------------------------------------------------------------------- */
{DIGITO}+{LETRA}({LETRA}|{DIGITO})*   {
    /* Exemplo: '2contador'. Erro lexico classico mantido do Grau A. */
    char m[128];
    snprintf(m, sizeof(m), "identificador nao pode comecar com digito: '%s'", yytext);
    erro_lexico(m);
    registrar_token_lexico("ERRO_LEXICO");
    yylval.texto = strdup(yytext);
    return T_ID;
}

{ID}        {
    num_tokens++;
    registrar_token_lexico("IDENTIFICADOR");
    yylval.texto = strdup(yytext);
    return T_ID;
}

 /* -------------------------------------------------------------------------
    3. LITERAIS NUMERICOS (FLOAT e INT)
    Guardamos tambem o texto do numero em yylval.texto para montar a
    Notacao Pos-Fixada (RPN) na traducao dirigida por sintaxe!
    ------------------------------------------------------------------------- */
{DIGITO}+"."{DIGITO}+   {
    num_tokens++;
    registrar_token_lexico("LITERAL_FLOAT");
    yylval.texto = strdup(yytext);
    return T_NUM_FLOAT;
}

{DIGITO}+               {
    num_tokens++;
    registrar_token_lexico("LITERAL_INT");
    yylval.texto = strdup(yytext);
    return T_NUM_INT;
}

 /* -------------------------------------------------------------------------
    4. OPERADORES RELACIONAIS (6 obrigatorios pelo enunciado)
    ------------------------------------------------------------------------- */
"=="        { num_tokens++; registrar_token_lexico("OP_RELACIONAL"); return T_IGUAL; }
"!="        { num_tokens++; registrar_token_lexico("OP_RELACIONAL"); return T_DIF; }
">="        { num_tokens++; registrar_token_lexico("OP_RELACIONAL"); return T_MAIOR_IGUAL; }
"<="        { num_tokens++; registrar_token_lexico("OP_RELACIONAL"); return T_MENOR_IGUAL; }
">"         { num_tokens++; registrar_token_lexico("OP_RELACIONAL"); return T_MAIOR; }
"<"         { num_tokens++; registrar_token_lexico("OP_RELACIONAL"); return T_MENOR; }

 /* -------------------------------------------------------------------------
    5. OPERADORES ARITMETICOS E DE ATRIBUICAO
    ------------------------------------------------------------------------- */
"="         { num_tokens++; registrar_token_lexico("OP_ATRIBUICAO"); return T_ATRIB; }
"+"         { num_tokens++; registrar_token_lexico("OP_ARITMETICO"); return T_MAIS; }
"-"         { num_tokens++; registrar_token_lexico("OP_ARITMETICO"); return T_MENOS; }
"*"         { num_tokens++; registrar_token_lexico("OP_ARITMETICO"); return T_MULT; }
"/"         { num_tokens++; registrar_token_lexico("OP_ARITMETICO"); return T_DIV; }

 /* -------------------------------------------------------------------------
    6. DELIMITADORES E PONTUACAO
    ------------------------------------------------------------------------- */
"("         { num_tokens++; registrar_token_lexico("DELIMITADOR"); return T_ABRE_PAR; }
")"         { num_tokens++; registrar_token_lexico("DELIMITADOR"); return T_FECHA_PAR; }
"{"         { num_tokens++; registrar_token_lexico("DELIMITADOR"); return T_ABRE_CHAVE; }
"}"         { num_tokens++; registrar_token_lexico("DELIMITADOR"); return T_FECHA_CHAVE; }
":"         { num_tokens++; registrar_token_lexico("DELIMITADOR"); return T_DOIS_PONTOS; }
","         { num_tokens++; registrar_token_lexico("DELIMITADOR"); return T_VIRG; }
";"         { num_tokens++; registrar_token_lexico("DELIMITADOR"); return T_PVIRG; }

 /* -------------------------------------------------------------------------
    7. ESPACOS EM BRANCO E COMENTARIOS (ignorados pelo sintatico)
    ------------------------------------------------------------------------- */
"//".*          { registrar_token_lexico("COMENTARIO"); }
[ \t\r\n]+      { /* Espacos, tabulacoes e quebras de linha: ignorados */ }

 /* -------------------------------------------------------------------------
    8. CARACTERE INVALIDO (Qualquer simbolo que nao pertence a linguagem)
    ------------------------------------------------------------------------- */
.           {
    char m[64];
    snprintf(m, sizeof(m), "caractere invalido '%s'", yytext);
    erro_lexico(m);
    registrar_token_lexico("ERRO_LEXICO");
}

%%
