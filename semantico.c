/* ==========================================================================
   MODULO SEMANTICO E TRADUCAO DIRIGIDA (IMPLEMENTACAO) -- Linguagem bell
   Trabalho do Grau B -- Compiladores -- UNISINOS
   ========================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "semantico.h"

/* Tabela de Simbolos em memoria e contador de simbolos cadastrados. */
static Simbolo tabela[MAX_SIMBOLOS];
static int n_simbolos = 0;

/* Lista de instrucoes traduzidas para Notacao Pos-Fixada (RPN). */
typedef struct {
    int linha;
    char *texto;
} LinhaTraduzida;

static LinhaTraduzida traducoes[MAX_TRADUCOES];
static int n_traducoes = 0;

/* Contador global de erros semanticos. */
int erros_semanticos = 0;

/* --------------------------------------------------------------------------
   Funcao auxiliar interna para padronizar mensagens de erro semantico.
   Atende ao requisito do enunciado: identifica a linguagem, a natureza
   do erro (SEMANTICO) e o numero da linha.
   -------------------------------------------------------------------------- */
static void erro_semantico(int linha, const char *msg) {
    printf("  [%s - ERRO SEMANTICO] linha %d: %s\n", NOME_LINGUAGEM, linha, msg);
    erros_semanticos++;
}

/* Converte o enum TipoDado para string legivel. */
const char* nome_tipo(TipoDado tipo) {
    switch (tipo) {
        case TIPO_INT:   return "int";
        case TIPO_FLOAT: return "float";
        default:         return "erro";
    }
}

/* --------------------------------------------------------------------------
   1. BUSCA NA TABELA DE SIMBOLOS
   Percorre a tabela procurando pelo nome exato da variavel.
   Retorna a posicao no vetor se encontrar, ou -1 se nao existir.
   -------------------------------------------------------------------------- */
int buscar_simbolo(const char *nome) {
    for (int i = 0; i < n_simbolos; i++) {
        if (strcmp(tabela[i].nome, nome) == 0) {
            return i;
        }
    }
    return -1;
}

/* --------------------------------------------------------------------------
   2. DECLARACAO DE VARIAVEL (Ex.: int a, b;)
   Regra semantica verificada:
   - Uma variavel nao pode ser declarada mais de uma vez.
   -------------------------------------------------------------------------- */
void declarar_variavel(const char *nome, TipoDado tipo, int linha) {
    int idx = buscar_simbolo(nome);
    if (idx != -1) {
        char msg[160];
        snprintf(msg, sizeof(msg),
                 "variavel '%s' ja foi declarada anteriormente na linha %d",
                 nome, tabela[idx].linha_decl);
        erro_semantico(linha, msg);
        return;
    }

    if (n_simbolos >= MAX_SIMBOLOS) {
        erro_semantico(linha, "limite maximo da Tabela de Simbolos atingido");
        return;
    }

    tabela[n_simbolos].nome = strdup(nome);
    tabela[n_simbolos].tipo = tipo;
    tabela[n_simbolos].linha_decl = linha;
    n_simbolos++;
}

/* --------------------------------------------------------------------------
   3. USO DE VARIAVEL EM EXPRESSAO (Ex.: x + 10)
   Regra semantica verificada:
   - A variavel precisa ter sido declarada antes do uso.
   Retorna o TipoDado da variavel (ou TIPO_ERRO se nao declarada).
   -------------------------------------------------------------------------- */
TipoDado obter_tipo_variavel(const char *nome, int linha) {
    int idx = buscar_simbolo(nome);
    if (idx == -1) {
        char msg[160];
        snprintf(msg, sizeof(msg),
                 "variavel '%s' usada sem ter sido declarada", nome);
        erro_semantico(linha, msg);
        return TIPO_ERRO;
    }
    return tabela[idx].tipo;
}

/* --------------------------------------------------------------------------
   4. COMPATIBILIDADE DE TIPOS EM OPERACOES ARITMETICAS (+, -, *, /)
   Regra semantica verificada (Tipagem Estrita):
   - Ambos os lados devem ter o mesmo tipo (int com int, ou float com float).
   - Se algum lado ja for TIPO_ERRO, apenas propaga TIPO_ERRO sem emitir
     nova mensagem repetida.
   -------------------------------------------------------------------------- */
TipoDado verificar_operacao_aritmetica(TipoDado esq, TipoDado dir, const char *op, int linha) {
    if (esq == TIPO_ERRO || dir == TIPO_ERRO) {
        return TIPO_ERRO;
    }

    if (esq != dir) {
        char msg[160];
        snprintf(msg, sizeof(msg),
                 "operacao '%s' incompativel entre '%s' e '%s' (tipagem estrita)",
                 op, nome_tipo(esq), nome_tipo(dir));
        erro_semantico(linha, msg);
        return TIPO_ERRO;
    }

    return esq; /* Como esq == dir, o resultado mantem o mesmo tipo. */
}

/* --------------------------------------------------------------------------
   5. COMPATIBILIDADE DE TIPOS EM ATRIBUICAO (Ex.: limite = 10 + 5;)
   Regras semanticas verificadas:
   - A variavel que recebe o valor (lado esquerdo) deve estar declarada.
   - O tipo da variavel deve ser identico ao tipo resultante da expressao
     do lado direito (tipagem estrita).
   -------------------------------------------------------------------------- */
void verificar_atribuicao(const char *nome_var, TipoDado tipo_expr, int linha) {
    int idx = buscar_simbolo(nome_var);
    if (idx == -1) {
        char msg[160];
        snprintf(msg, sizeof(msg),
                 "variavel '%s' recebeu atribuicao sem ter sido declarada",
                 nome_var);
        erro_semantico(linha, msg);
        return;
    }

    /* Se a expressao da direita ja teve erro de tipo, nao reportamos segundo erro. */
    if (tipo_expr == TIPO_ERRO) {
        return;
    }

    TipoDado tipo_var = tabela[idx].tipo;
    if (tipo_var != tipo_expr) {
        char msg[160];
        snprintf(msg, sizeof(msg),
                 "atribuicao incompativel para '%s': variavel eh '%s', mas expressao eh '%s'",
                 nome_var, nome_tipo(tipo_var), nome_tipo(tipo_expr));
        erro_semantico(linha, msg);
    }
}

/* --------------------------------------------------------------------------
   6. COMPATIBILIDADE DE TIPOS EM CONDICOES RELACIONAIS (==, !=, >, <, >=, <=)
   Regra semantica verificada (Tipagem Estrita):
   - So permite comparar grandezas do mesmo tipo (int com int, float com float).
   -------------------------------------------------------------------------- */
void verificar_condicao_relacional(TipoDado esq, TipoDado dir, const char *op, int linha) {
    if (esq == TIPO_ERRO || dir == TIPO_ERRO) {
        return;
    }

    if (esq != dir) {
        char msg[160];
        snprintf(msg, sizeof(msg),
                 "condicao '%s' incompativel entre '%s' e '%s' (tipagem estrita)",
                 op, nome_tipo(esq), nome_tipo(dir));
        erro_semantico(linha, msg);
    }
}

/* --------------------------------------------------------------------------
   7. VERIFICACAO DO COMANDO DE SELECAO MULTIPLA (switch)
   Regra semantica verificada:
   - Como os casos (case 1:, case 2:) sao constantes inteiras, a expressao
     avaliada no 'switch (expr)' deve ser obrigatoriamente do tipo 'int'.
   -------------------------------------------------------------------------- */
void verificar_selecao_switch(TipoDado tipo_expr, int linha) {
    if (tipo_expr == TIPO_ERRO) {
        return;
    }

    if (tipo_expr != TIPO_INT) {
        char msg[160];
        snprintf(msg, sizeof(msg),
                 "expressao do 'switch' deve ser 'int', mas recebeu '%s'",
                 nome_tipo(tipo_expr));
        erro_semantico(linha, msg);
    }
}

/* --------------------------------------------------------------------------
   8. TRADUCAO DIRIGIDA POR SINTAXE: NOTACAO POS-FIXADA (RPN)
   Na notacao pos-fixada (Polonesa Reversa), os operandos vem primeiro e o
   operador vem DEPOIS:
     Infixa     : 10 + 5 * 2
     Pos-Fixada : 10 5 2 * +
   Por que ela eh excelente para compiladores?
   Porque dispensa parenteses: a ordem em que o Bison reduz as regras (guiada
   pela precedencia de '*' sobre '+' e pelos parenteses) ja monta a string
   pos-fixada na ordem exata de execucao!
   -------------------------------------------------------------------------- */
char* combinar_rpn(char *esq, char *dir, const char *op) {
    size_t tam = strlen(esq) + strlen(dir) + strlen(op) + 3;
    char *nova = (char *)malloc(tam);
    if (nova) {
        snprintf(nova, tam, "%s %s %s", esq, dir, op);
    }
    free(esq);
    free(dir);
    return nova;
}

void registrar_traducao(int linha, const char *contexto, const char *rpn) {
    if (n_traducoes >= MAX_TRADUCOES) {
        return;
    }
    size_t tam = strlen(contexto) + strlen(rpn) + 16;
    char *buf = (char *)malloc(tam);
    if (buf) {
        snprintf(buf, tam, "%-14s %s", contexto, rpn);
        traducoes[n_traducoes].linha = linha;
        traducoes[n_traducoes].texto = buf;
        n_traducoes++;
    }
}

void imprimir_traducao_posfixada(void) {
    printf("\n===== TRADUCAO DIRIGIDA POR SINTAXE (POS-FIXADA) =====\n");
    if (n_traducoes == 0) {
        printf("(nenhuma expressao traduzida)\n");
        return;
    }
    printf("%-8s %-14s %s\n", "LINHA", "CONSTRUCAO", "NOTACAO POS-FIXADA (RPN)");
    for (int i = 0; i < n_traducoes; i++) {
        printf("%-8d %s\n", traducoes[i].linha, traducoes[i].texto);
    }
}

/* --------------------------------------------------------------------------
   IMPRESSAO E LIMPEZA DE MEMORIA
   -------------------------------------------------------------------------- */
void imprimir_tabela_simbolos(void) {
    printf("\n===== TABELA DE SIMBOLOS =====\n");
    if (n_simbolos == 0) {
        printf("(vazia)\n");
        return;
    }
    printf("%-20s %-10s %s\n", "NOME", "TIPO", "LINHA DECL.");
    for (int i = 0; i < n_simbolos; i++) {
        printf("%-20s %-10s %d\n",
               tabela[i].nome,
               nome_tipo(tabela[i].tipo),
               tabela[i].linha_decl);
    }
}

void liberar_memoria_semantica(void) {
    for (int i = 0; i < n_simbolos; i++) {
        free(tabela[i].nome);
        tabela[i].nome = NULL;
    }
    n_simbolos = 0;

    for (int i = 0; i < n_traducoes; i++) {
        free(traducoes[i].texto);
        traducoes[i].texto = NULL;
    }
    n_traducoes = 0;
}
