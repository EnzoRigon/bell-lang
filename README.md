# Compilador bell — Trabalho do Grau B (UNISINOS)

Analisador Léxico (Flex), Sintático (Bison), Verificador Semântico (Tipagem Estrita e Tabela de Símbolos) e Tradutor Dirigido por Sintaxe (Notação Pós-Fixada / RPN).

## Estrutura do Projeto

- `semantico.h` / `semantico.c`: Tabela de Símbolos, regras de verificação semântica (`declarar_variavel`, `obter_tipo_variavel`, `verificar_operacao_aritmetica`, `verificar_atribuicao`, `verificar_condicao_relacional`, `verificar_selecao_switch`) e gerador de Notação Pós-Fixada (`combinar_rpn`, `registrar_traducao`).
- `analisador.l`: Especificação léxica (Flex) da linguagem **bell**.
- `analisador.y`: Gramática Livre de Contexto (Bison) com ações semânticas e tradução dirigida por sintaxe.
- `examples/valido1.bell` .. `examples/valido4.bell`: 4 programas de teste válidos cobrindo todas as construções da linguagem.
- `examples/invalido1.bell` .. `examples/invalido4.bell`: 4 programas de teste inválidos (semânticos, sintáticos e léxicos).

## Como Compilar e Executar

```bash
make
./bellc examples/valido1.bell
./bellc examples/valido2.bell
./bellc examples/invalido1.bell
./bellc examples/invalido2.bell
```

## Extra

- [bell.nvim](https://github.com/gabrielmusskopf/bell.nvim): Plugin para aplicar syntax highlighting em código-fonte `.bell` para NeoVim
