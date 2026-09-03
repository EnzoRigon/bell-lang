# Compiler and tool definitions
CC = gcc
LEX = flex

# Compiler flags (-Wall enables warnings, -g adds debugging symbols)
CFLAGS = -Wall -g

# Libraries (-lfl links the Flex library for standard yywrap)
LIBS = -lfl

# Name of your final executable output
TARGET = analisador 

# Name of your source files
FLEX_SRC = analisador.l
GEN_C = lex.yy.c

# Default rule executed when typing 'make'
all: $(TARGET)

# Rule to build the final executable
$(TARGET): $(GEN_C)
	$(CC) $(CFLAGS) -o $(TARGET) $(GEN_C) $(LIBS)

# Rule to generate the C source code from the Flex file
$(GEN_C): $(FLEX_SRC)
	$(LEX) $(FLEX_SRC)

# Clean rule to delete generated files and start fresh
clean:
	rm -f $(TARGET) $(GEN_C) *.o
