%{
/* ==========================================================================
   ANALISADOR SINTATICO, SEMANTICO E TRADUTOR (BISON) -- Linguagem bell
   Trabalho do Grau B -- Compiladores -- UNISINOS

   Construcoes reconhecidas neste arquivo:
   a) Declaracao de variaveis (int, float) individuais ou em lista;
   b) Comando condicional (if com bloco else opcional);
   c) Comando de selecao multipla (switch / case / break / default opcional);
   d) Expressoes aritmeticas (+, -, *, /) com precedencia e parenteses;
   e) Atribuicao a variaveis declaradas (=);
   f) Condicoes com os 6 operadores relacionais (==, !=, >, <, >=, <=).

   Traducao Dirigida por Sintaxe:
   - Gera e registra a Notacao Pos-Fixada (Polonesa Reversa / RPN) de todas
     as expressoes, atribuicoes, condicoes e selecoes do programa!
   ========================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "semantico.h"

/* Declaracoes vindas do Flex (analisador.l) */
extern int yylex(void);
extern int yylineno;
extern char *yytext;
extern FILE *yyin;
extern int erros_lexicos;
extern int num_tokens;

/* Contador de erros sintaticos (estruturais) */
int erros_sintaticos = 0;

/* Guarda temporariamente o tipo da declaracao em curso (ex.: em 'int a, b;',
   guarda TIPO_INT para aplicar tanto em 'a' quanto em 'b'). */
static TipoDado tipo_declaracao_atual;

/* Funcao chamada automaticamente pelo Bison quando encontra erro sintatico. */
void yyerror(const char *msg);
%}

/* --------------------------------------------------------------------------
   %union: Define a "mochila" (yylval) que carrega valores do Flex para o Bison
   e entre as regras da arvore sintatica.
   - 'texto' : strings de identificadores, numeros e operadores relacionais;
   - 'tipo'  : TipoDado (TIPO_INT, TIPO_FLOAT, TIPO_ERRO);
   - 'expr'  : AtributoExpressao (carrega juntos o 'tipo' semantico e a
               string 'rpn' da Traducao Pos-Fixada!).
   -------------------------------------------------------------------------- */
%union {
    char *texto;
    TipoDado tipo;
    AtributoExpressao expr;
}

/* --------------------------------------------------------------------------
   DECLARACAO DOS TOKENS (Simbolos Terminais vindos do Flex)
   -------------------------------------------------------------------------- */
%token T_INT T_FLOAT
%token T_IF T_ELSE
%token T_SWITCH T_CASE T_BREAK T_DEFAULT
%token <texto> T_ID T_NUM_INT T_NUM_FLOAT
%token T_IGUAL T_DIF T_MAIOR T_MENOR T_MAIOR_IGUAL T_MENOR_IGUAL
%token T_ATRIB
%token T_MAIS T_MENOS T_MULT T_DIV
%token T_ABRE_PAR T_FECHA_PAR T_ABRE_CHAVE T_FECHA_CHAVE
%token T_DOIS_PONTOS T_VIRG T_PVIRG

/* --------------------------------------------------------------------------
   TIPAGEM DOS NAO-TERMINAIS (Simbolos da Gramatica)
   -------------------------------------------------------------------------- */
%type <tipo> tipo
%type <expr> expressao
%type <texto> op_relacional

/* --------------------------------------------------------------------------
   PRECEDENCIA E ASSOCIATIVIDADE DE OPERADORES
   1) '+' e '-' tem menor precedencia e sao associativos a esquerda (%left).
   2) '*' e '/' tem MAIOR precedencia que '+' e '-' e tambem sao %left.
   -------------------------------------------------------------------------- */
%left T_MAIS T_MENOS
%left T_MULT T_DIV

%%

/* ==========================================================================
   REGRAS DA GRAMATICA + ACOES SEMANTICAS + TRADUCAO DIRIGIDA POR SINTAXE
   ========================================================================== */

programa
    : lista_comandos
    ;

lista_comandos
    : /* vazio: permite bloco vazio ou fim da recursao */
    | lista_comandos comando
    ;

comando
    : declaracao
    | atribuicao
    | condicional
    | selecao_multipla
    | error T_PVIRG {
        /* Recuperacao de erro sintatico ate o proximo ';' */
        yyerrok;
    }
    ;

/* --------------------------------------------------------------------------
   1. DECLARACAO DE VARIAVEIS (Ex.: int limite, faixa; ou float media;)
   -------------------------------------------------------------------------- */
declaracao
    : tipo lista_ids T_PVIRG
    ;

tipo
    : T_INT {
        $$ = TIPO_INT;
        tipo_declaracao_atual = TIPO_INT;
    }
    | T_FLOAT {
        $$ = TIPO_FLOAT;
        tipo_declaracao_atual = TIPO_FLOAT;
    }
    ;

lista_ids
    : T_ID {
        declarar_variavel($1, tipo_declaracao_atual, yylineno);
        free($1);
    }
    | lista_ids T_VIRG T_ID {
        declarar_variavel($3, tipo_declaracao_atual, yylineno);
        free($3);
    }
    ;

/* --------------------------------------------------------------------------
   2. ATRIBUICAO (Ex.: limite = 10 + 5 * 2;)
   - Verificacao Semantica: confere se $1 foi declarada e tem o mesmo tipo de $3.tipo.
   - Traducao Pos-Fixada: monta "<id> <expr_rpn> =" (ex.: "limite 10 5 2 * + =").
   -------------------------------------------------------------------------- */
atribuicao
    : T_ID T_ATRIB expressao T_PVIRG {
        verificar_atribuicao($1, $3.tipo, yylineno);

        char *rpn_atrib = combinar_rpn($1, $3.rpn, "=");
        registrar_traducao(yylineno, "[ATRIBUICAO]", rpn_atrib);
        free(rpn_atrib);
    }
    ;

/* --------------------------------------------------------------------------
   3. COMANDO CONDICIONAL (if com bloco else opcional)
   -------------------------------------------------------------------------- */
condicional
    : T_IF T_ABRE_PAR condicao T_FECHA_PAR bloco bloco_else_opc
    ;

bloco
    : T_ABRE_CHAVE lista_comandos T_FECHA_CHAVE
    ;

bloco_else_opc
    : /* vazio: quando o 'if' nao tem 'else' */
    | T_ELSE bloco
    ;

/* --------------------------------------------------------------------------
   4. CONDICOES COM OS 6 OPERADORES RELACIONAIS (==, !=, >, <, >=, <=)
   - Verificacao Semantica: compara $1.tipo com $3.tipo.
   - Traducao Pos-Fixada: monta "<esq_rpn> <dir_rpn> <op>" (ex.: "limite 20 >").
   -------------------------------------------------------------------------- */
condicao
    : expressao op_relacional expressao {
        verificar_condicao_relacional($1.tipo, $3.tipo, $2, yylineno);

        char *rpn_cond = combinar_rpn($1.rpn, $3.rpn, $2);
        registrar_traducao(yylineno, "[CONDICAO IF]", rpn_cond);
        free(rpn_cond);
    }
    ;

op_relacional
    : T_IGUAL       { $$ = "=="; }
    | T_DIF         { $$ = "!="; }
    | T_MAIOR       { $$ = ">";  }
    | T_MENOR       { $$ = "<";  }
    | T_MAIOR_IGUAL { $$ = ">="; }
    | T_MENOR_IGUAL { $$ = "<="; }
    ;

/* --------------------------------------------------------------------------
   5. COMANDO DE SELECAO MULTIPLA (switch / case / break / default)
   -------------------------------------------------------------------------- */
selecao_multipla
    : cabecalho_switch T_ABRE_CHAVE lista_casos caso_padrao_opc T_FECHA_CHAVE
    ;

cabecalho_switch
    : T_SWITCH T_ABRE_PAR expressao T_FECHA_PAR {
        verificar_selecao_switch($3.tipo, yylineno);
        registrar_traducao(yylineno, "[SWITCH]", $3.rpn);
        free($3.rpn);
    }
    ;

lista_casos
    : caso
    | lista_casos caso
    ;

caso
    : rotulos_caso lista_comandos T_BREAK T_PVIRG
    ;

rotulos_caso
    : T_CASE lista_inteiros T_DOIS_PONTOS
    | rotulos_caso T_CASE lista_inteiros T_DOIS_PONTOS
    ;

lista_inteiros
    : T_NUM_INT {
        free($1);
    }
    | lista_inteiros T_VIRG T_NUM_INT {
        free($3);
    }
    ;

caso_padrao_opc
    : /* vazio: default eh opcional */
    | T_DEFAULT T_DOIS_PONTOS lista_comandos break_opc
    ;

break_opc
    : /* vazio: permite default sem break */
    | T_BREAK T_PVIRG
    ;

/* --------------------------------------------------------------------------
   6. EXPRESSOES ARITMETICAS (+, -, *, /, parenteses, literais e variaveis)
   Repare na elegancia da Traducao Dirigida por Sintaxe:
   Cada regra calcula:
     1) $$.tipo -> Validacao semantica dos tipos;
     2) $$.rpn  -> String na Notacao Pos-Fixada (Polonesa Reversa).
   -------------------------------------------------------------------------- */
expressao
    : expressao T_MAIS expressao {
        $$.tipo = verificar_operacao_aritmetica($1.tipo, $3.tipo, "+", yylineno);
        $$.rpn  = combinar_rpn($1.rpn, $3.rpn, "+");
    }
    | expressao T_MENOS expressao {
        $$.tipo = verificar_operacao_aritmetica($1.tipo, $3.tipo, "-", yylineno);
        $$.rpn  = combinar_rpn($1.rpn, $3.rpn, "-");
    }
    | expressao T_MULT expressao {
        $$.tipo = verificar_operacao_aritmetica($1.tipo, $3.tipo, "*", yylineno);
        $$.rpn  = combinar_rpn($1.rpn, $3.rpn, "*");
    }
    | expressao T_DIV expressao {
        $$.tipo = verificar_operacao_aritmetica($1.tipo, $3.tipo, "/", yylineno);
        $$.rpn  = combinar_rpn($1.rpn, $3.rpn, "/");
    }
    | T_ABRE_PAR expressao T_FECHA_PAR {
        /* Na notacao pos-fixada, parenteses nao precisam aparecer no texto,
           pois eles ja cumpriram seu papel de alterar a ordem de reducao! */
        $$ = $2;
    }
    | T_NUM_INT {
        $$.tipo = TIPO_INT;
        $$.rpn  = $1;
    }
    | T_NUM_FLOAT {
        $$.tipo = TIPO_FLOAT;
        $$.rpn  = $1;
    }
    | T_ID {
        $$.tipo = obter_tipo_variavel($1, yylineno);
        $$.rpn  = $1;
    }
    ;

%%

/* --------------------------------------------------------------------------
   TRATAMENTO DE ERRO SINTATICO
   -------------------------------------------------------------------------- */
void yyerror(const char *msg) {
    (void)msg;
    printf("  [%s - ERRO SINTATICO] linha %d: token inesperado '%s'\n",
           NOME_LINGUAGEM, yylineno, yytext);
    erros_sintaticos++;
}

/* --------------------------------------------------------------------------
   FUNCAO PRINCIPAL
   -------------------------------------------------------------------------- */
int main(int argc, char **argv) {
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            perror("Erro ao abrir arquivo");
            return 1;
        }
        printf("Arquivo analisado (%s): %s\n", NOME_LINGUAGEM, argv[1]);
    }

    printf("\n===== ANALISE EM EXECUCAO =====\n");
    yyparse();

    imprimir_tabela_simbolos();

    int total_erros = erros_lexicos + erros_sintaticos + erros_semanticos;

    /* Se o programa eh valido, exibe a Traducao Dirigida por Sintaxe completa;
       mesmo se houver erros, exibe o que foi traduzido para fins didaticos. */
    imprimir_traducao_posfixada();

    printf("\n===== RESUMO (%s) =====\n", NOME_LINGUAGEM);
    printf("Tokens reconhecidos : %d\n", num_tokens);
    printf("Erros lexicos       : %d\n", erros_lexicos);
    printf("Erros sintaticos    : %d\n", erros_sintaticos);
    printf("Erros semanticos    : %d\n\n", erros_semanticos);
    printf("%s\n", total_erros == 0 ? ">> PROGRAMA VALIDO" : ">> PROGRAMA INVALIDO");

    liberar_memoria_semantica();
    if (argc > 1 && yyin) {
        fclose(yyin);
    }
    return 0;
}
