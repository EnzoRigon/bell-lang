/* ==========================================================================
   MODULO SEMANTICO E TRADUCAO DIRIGIDA (CABECALHO) -- Linguagem bell
   Trabalho do Grau B -- Compiladores -- UNISINOS

   Por que separar o analisador semantico em um arquivo proprio?
   1) Mantem a gramatica do Bison (analisador.y) limpa e legivel;
   2) Facilita explicar na apresentacao onde ficam a Tabela de Simbolos,
      as regras de verificacao de tipos e a geracao da Notacao Pos-Fixada.
   ========================================================================== */

#ifndef SEMANTICO_H
#define SEMANTICO_H

/* Nome da linguagem projetada pelo grupo (aparece nas mensagens e relatorios). */
#define NOME_LINGUAGEM "bell"

/* Limites das tabelas em memoria. */
#define MAX_SIMBOLOS  200
#define MAX_TRADUCOES 500

/* --------------------------------------------------------------------------
   TIPOS DE DADOS DA LINGUAGEM
   Alem de TIPO_INT e TIPO_FLOAT, criamos o TIPO_ERRO.
   Por que TIPO_ERRO existe?
   Imagine a expressao: (10 + 2.5) + 3
   - Quando avaliamos (10 + 2.5), detectamos erro (int + float) e devolvemos
     TIPO_ERRO como resultado dessa subexpressao.
   - Assim, na soma externa (TIPO_ERRO + 3), sabemos que o erro ja foi avisado
     e evitamos imprimir varios erros repetidos na mesma linha!
   -------------------------------------------------------------------------- */
typedef enum {
    TIPO_INT,
    TIPO_FLOAT,
    TIPO_ERRO
} TipoDado;

/* --------------------------------------------------------------------------
   ATRIBUTO SINTETIZADO PELAS EXPRESSOES (Semantica + Traducao Dirigida)
   Cada no de 'expressao' na arvore do Bison carrega duas informacoes:
   1) tipo : o TipoDado resultante (para a verificacao semantica);
   2) rpn  : o texto em Notacao Pos-Fixada (Polonesa Reversa), ex.: "10 5 2 * +".
   -------------------------------------------------------------------------- */
typedef struct {
    TipoDado tipo;
    char *rpn;
} AtributoExpressao;

/* --------------------------------------------------------------------------
   ESTRUTURA DA TABELA DE SIMBOLOS
   Guarda cada variavel declarada no programa: seu nome, seu tipo e a linha
   onde ela foi declarada.
   -------------------------------------------------------------------------- */
typedef struct {
    char *nome;
    TipoDado tipo;
    int linha_decl;
} Simbolo;

/* Contador global de erros semanticos encontrados durante a analise. */
extern int erros_semanticos;

/* --- Operacoes da Tabela de Simbolos --- */

/* Procura uma variavel pelo nome. Retorna o indice (0..n-1) ou -1 se nao achar. */
int buscar_simbolo(const char *nome);

/* Registra uma nova variavel na Tabela de Simbolos (verifica duplicidade). */
void declarar_variavel(const char *nome, TipoDado tipo, int linha);

/* Consulta o tipo de uma variavel usada em expressao (verifica se foi declarada). */
TipoDado obter_tipo_variavel(const char *nome, int linha);

/* --- Regras de Verificacao Semantica de Tipos --- */

/* Verifica se dois operandos (esq e dir) tem tipos compativeis para +, -, *, /. */
TipoDado verificar_operacao_aritmetica(TipoDado esq, TipoDado dir, const char *op, int linha);

/* Verifica se a variavel do lado esquerdo de '=' existe e tem o mesmo tipo da expressao. */
void verificar_atribuicao(const char *nome_var, TipoDado tipo_expr, int linha);

/* Verifica se os dois lados de uma comparacao (==, !=, >, <, >=, <=) tem o mesmo tipo. */
void verificar_condicao_relacional(TipoDado esq, TipoDado dir, const char *op, int linha);

/* Verifica se a expressao usada em 'switch (expr)' eh do tipo inteiro (int). */
void verificar_selecao_switch(TipoDado tipo_expr, int linha);

/* --- Traducao Dirigida por Sintaxe (Notacao Pos-Fixada / RPN) --- */

/* Junta duas subexpressoes e um operador no formato pos-fixado: "esq dir op"
   e ja libera a memoria das strings antigas (esq e dir). */
char* combinar_rpn(char *esq, char *dir, const char *op);

/* Registra uma linha traduzida em Notacao Pos-Fixada (atribuicao, if, switch). */
void registrar_traducao(int linha, const char *contexto, const char *rpn);

/* Imprime todas as linhas traduzidas em Notacao Pos-Fixada. */
void imprimir_traducao_posfixada(void);

/* --- Utilitarios --- */

/* Converte o enum TipoDado em texto ("int", "float", "erro") para mensagens. */
const char* nome_tipo(TipoDado tipo);

/* Imprime toda a Tabela de Simbolos formatada no final da execucao. */
void imprimir_tabela_simbolos(void);

/* Libera a memoria alocada na Tabela de Simbolos e na lista de traducoes. */
void liberar_memoria_semantica(void);

#endif
