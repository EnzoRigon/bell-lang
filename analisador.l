%{
/* ==========================================================================
   ANALISADOR LEXICO + VERIFICACAO ESTRUTURAL DE DECLARACOES
   Linguagem estilo C -- apenas declaracoes dos tipos int, float e char.
   Trabalho de Grau A -- Compiladores -- UNISINOS.

   Um arquivo Flex (.l) tem 3 partes separadas por %% :
     1) este bloco entre %{ e %} : codigo C que fica disponivel para tudo;
     2) as DEFINICOES (apelidos de padroes) logo abaixo;
     3) as REGRAS (padrao -> acao) entre os dois %% ;
   e, no final, a funcao main.
   ========================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int  erros = 0;   /* quantos erros ja foram encontrados (lexicos+estruturais) */

/* --------------------------------------------------------------------------
   AUTOMATO DA GRAMATICA DE DECLARACOES
   A regra  declaracao -> tipo lista_id ';'  eh verificada por um automato
   de 3 estados, dirigido pela sequencia de tokens que vao chegando:
     ESPERA_TIPO       -> comeco de declaracao; tem que vir um tipo;
     ESPERA_ID         -> ja veio o tipo; tem que vir um identificador;
     ESPERA_VIRG_PVIRG -> ja veio um id; so pode vir ',' (mais nomes) ou ';'.
   -------------------------------------------------------------------------- */
enum Estado { ESPERA_TIPO, ESPERA_ID, ESPERA_VIRG_PVIRG };
enum Estado estado = ESPERA_TIPO;   /* comecamos esperando um tipo            */
char tipo_atual[16] = "";           /* guarda o tipo da declaracao em curso   */

/* --------------------------------------------------------------------------
   TABELA DE SIMBOLOS
   Lista das variaveis declaradas, com nome e tipo de cada uma.
   -------------------------------------------------------------------------- */
#define MAX 200
int n_simb = 0;                     /* quantas variaveis ja foram anotadas    */

typedef struct Token {
    char *nome;
    char *tipo;
} Token;

Token tabela[MAX] = {0};

void libera(Token token) {
    free(token.nome);
    free(token.tipo);
}

/* Anota uma variavel (nome + tipo) na tabela de simbolos. */
void insere(char *nome, char *tipo) {
    if (n_simb < MAX) {
        tabela[n_simb].nome = strdup(nome);
        tabela[n_simb].tipo = strdup(tipo);
        n_simb++;
    }
}

/* Imprime uma mensagem de erro COM o numero da linha e conta o erro. */
void erro(const char *msg) {
    printf("  [ERRO] linha %d: %s\n", yylineno, msg);
    erros++;
}
%}

/* %option noyywrap : dispensa a funcao yywrap(); analisamos um arquivo so. */
%option noyywrap yylineno

/* DEFINICOES: apelidos para os padroes (expressoes regulares), so p/ clareza.
   LETRA  = uma letra maiuscula/minuscula ou sublinhado
   DIGITO = um digito de 0 a 9
   ID     = primeiro caractere LETRA, seguido de LETRA/DIGITO em qualquer qtd */
LETRA   [A-Za-z_]
DIGITO  [0-9]
ID      {LETRA}({LETRA}|{DIGITO})*

%%

"int"|"float"|"char"   {
    /* PALAVRA RESERVADA (tipo). Vem ANTES da regra do identificador: como
       'int' casa com os dois padroes, a ordem resolve o empate a favor do tipo. */
    printf("%-15s %s\n", "TIPO", yytext);
    if (estado != ESPERA_TIPO)
        erro("tipo inesperado -- a declaracao anterior nao terminou com ';'");
    strncpy(tipo_atual, yytext, 15); tipo_atual[15] = '\0';
    estado = ESPERA_ID;                 /* depois do tipo, esperamos um nome  */
}

{ID}   {
    /* IDENTIFICADOR (nome de variavel). A acao consulta o automato para saber
       se o nome apareceu no lugar certo da declaracao. */
    printf("%-15s %s\n", "IDENTIFICADOR", yytext);
    if (estado == ESPERA_ID) {
        insere(yytext, tipo_atual);     /* nome no lugar certo: anota         */
        estado = ESPERA_VIRG_PVIRG;
    } else if (estado == ESPERA_TIPO) {
        /* Ex.: 'double z;' -- 'double' nao eh um dos tres tipos validos.     */
        char m[128];
        snprintf(m, sizeof m, "'%s' nao e um tipo valido (use int, float ou char)", yytext);
        erro(m);
        strncpy(tipo_atual, yytext, 15); tipo_atual[15] = '\0';  /* recuperacao */
        estado = ESPERA_ID;
    } else {
        /* Ex.: 'int a b;' -- depois de 'a' esperavamos ',' ou ';', veio 'b'. */
        char m[128];
        snprintf(m, sizeof m, "esperado ',' ou ';' antes de '%s'", yytext);
        erro(m);
        insere(yytext, tipo_atual);     /* recuperacao: segue analisando      */
    }
}

{DIGITO}+{LETRA}({LETRA}|{DIGITO})*   {
    /* IDENTIFICADOR COMECANDO COM DIGITO (ex.: '2contador'). Erro classico
       citado no enunciado. Precisa vir antes do numero para casar tudo. */
    char m[128];
    snprintf(m, sizeof m, "identificador nao pode comecar com digito: '%s'", yytext);
    erro(m);
    if (estado == ESPERA_ID) estado = ESPERA_VIRG_PVIRG;  /* recuperacao       */
}

{DIGITO}+(\.{DIGITO}+)?   {
    /* LITERAL NUMERICO (ex.: 3, 42, 3.5). Proibido: nesta etapa nao existe
       inicializacao. O '\.' eh ponto LITERAL (sem a barra, '.' seria
       "qualquer caractere"). */
    char m[128];
    snprintf(m, sizeof m, "literal numerico '%s' nao e permitido (variaveis sao apenas declaradas)", yytext);
    erro(m);
}

"="   {
    /* ATRIBUICAO. Tambem proibida: nao ha inicializacao nesta etapa. */
    erro("atribuicao '=' nao e permitida (sem inicializacao nesta etapa)");
}

","   {
    /* VIRGULA: separa nomes numa lista (int a, b, c;). */
    printf("%-15s %s\n", "VIRGULA", yytext);
    if (estado == ESPERA_VIRG_PVIRG)
        estado = ESPERA_ID;             /* apos a virgula, vem outro nome     */
    else
        erro("',' em posicao invalida");
}

";"   {
    /* PONTO E VIRGULA: encerra a declaracao. */
    printf("%-15s %s\n", "PONTO_VIRGULA", yytext);
    if (estado == ESPERA_VIRG_PVIRG)
        estado = ESPERA_TIPO;           /* fechou; pronto p/ proxima declaracao */
    else {
        erro("';' inesperado (declaracao incompleta)");
        estado = ESPERA_TIPO;           /* recuperacao                        */
    }
}

[ \t\r\n]+   {
    /* ESPACOS, TABULACOES e LINHA: ignorados (casa e nao faz nada). */
}

.   {
    /* REDE DE SEGURANCA: qualquer caractere que nao casou acima eh invalido. */
    char m[64];
    snprintf(m, sizeof m, "caractere invalido '%s'", yytext);
    erro(m);
}

%%

/* --------------------------------------------------------------------------
   FUNCAO PRINCIPAL: abre o arquivo, roda o analisador (yylex), e no final
   imprime a tabela de simbolos e o resumo (erros + veredito).
   -------------------------------------------------------------------------- */
int main(int argc, char **argv) {
    if (argc > 1) {                     /* se passaram um arquivo, usa ele    */
        yyin = fopen(argv[1], "r");
        if (!yyin) { perror("Erro ao abrir arquivo"); return 1; }
        printf("Arquivo: %s\n", argv[1]);
    }

    printf("\n===== SEQUENCIA DE TOKENS =====\n");
    yylex();                            /* le todo o texto, aplicando as regras */

    /* Se o texto acabou com uma declaracao aberta (sem ';'), acusa. */
    if (estado != ESPERA_TIPO)
        erro("fim do arquivo: ultima declaracao nao terminou com ';'");

    printf("\n===== TABELA DE SIMBOLOS =====\n");
    if (n_simb == 0) {
        printf("(vazia)\n");
    } else {
        printf("%-20s %s\n", "NOME", "TIPO");
        for (int i = 0; i < n_simb; i++)
            printf("%-20s %s\n", tabela[i].nome, tabela[i].tipo);
    }

    printf("\n===== RESUMO =====\n");
    printf("Erros encontrados: %d\n", erros);
    printf("%s\n", erros == 0 ? ">> PROGRAMA VALIDO" : ">> PROGRAMA INVALIDO");

    for (int i = 0; i < n_simb; i++) {
        libera(tabela[i]);
    }

    return 0;
}
