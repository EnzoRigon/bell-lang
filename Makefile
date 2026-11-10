# ==========================================================================
# Makefile -- Compilador bell (Flex + Bison + Semantico em C)
# Trabalho do Grau B -- Compiladores -- UNISINOS
# ==========================================================================

CC     = gcc
LEX    = flex
YACC   = bison

CFLAGS = -Wall -Wextra -g

TARGET   = bellc
FLEX_SRC = analisador.l
YACC_SRC = analisador.y
SEM_SRC  = semantico.c

LEX_C    = lex.yy.c
YACC_C   = analisador.tab.c
YACC_H   = analisador.tab.h

all: $(TARGET)

# Passo 3: Compila tudo junto (Bison + Flex + Modulo Semantico)
$(TARGET): $(YACC_C) $(LEX_C) $(SEM_SRC) semantico.h
	$(CC) $(CFLAGS) -o $(TARGET) $(YACC_C) $(LEX_C) $(SEM_SRC)

# Passo 1: Bison gera analisador.tab.c e analisador.tab.h (flag -d)
$(YACC_C) $(YACC_H): $(YACC_SRC) semantico.h
	$(YACC) -d $(YACC_SRC)

# Passo 2: Flex gera lex.yy.c (precisa de analisador.tab.h pronto)
$(LEX_C): $(FLEX_SRC) $(YACC_H) semantico.h
	$(LEX) $(FLEX_SRC)

clean:
	rm -f $(TARGET) $(LEX_C) $(YACC_C) $(YACC_H) *.o
