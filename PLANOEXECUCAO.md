# Plano de execução: Kakuro (Prolog + Python + Elm)

Este documento é só de **consulta**: explica o que precisa ser feito, em que ordem e como. Ninguém precisa preencher nem atualizar este arquivo.

O acompanhamento (quem está fazendo o quê, o que já foi concluído) fica no **quadro de projeto e nas Issues do GitHub**.

## 1. Visão geral

**Objetivo:** um Kakuro jogável no navegador. O Prolog gera puzzles 6x6 com solução única, resolve, verifica e dá dicas. O Elm cuida do domínio do jogo e da interface. O Python só faz a ponte entre os dois.

```
Navegador (Elm) ──HTTP/JSON──▶ FastAPI (Python) ──Janus──▶ SWI-Prolog
```

**O que o jogo precisa fazer**
- Gerar um novo puzzle 6x6 a cada partida (sem catálogo fixo).
- Permitir digitar, apagar, navegar pelo teclado e reiniciar. Pistas e bloqueios nunca mudam.
- Verificar o preenchimento (incompleto, inconsistente ou resolvido), dar dica e resolver.
- Se a comunicação falhar, o preenchimento do jogador não se perde e dá para tentar de novo.

**Regras do Kakuro:** preencher as casas brancas com dígitos de 1 a 9. Cada pista indica a soma de uma sequência de casas (à direita ou abaixo). Dentro de uma mesma sequência, nenhum dígito se repete. Uma casa branca pertence a uma sequência horizontal e a uma vertical.

## 2. Divisão do trabalho por área

| Área | Pessoas | O que cobre |
|------|---------|-------------|
| Prolog | 2 | Regras, resolução, gerador, dica e testes |
| Elm | 3 | Domínio e API, estado e eventos, telas e CSS |
| Python | 2 | API e ponte com o Prolog |


Quem fica com cada parte dentro da área é combinado pelo grupo e registrado nas Issues. Todos devem conseguir **explicar o código dos outros**, então a revisão cruzada de Pull Requests também serve de estudo.

## 3. Contrato entre as partes

É o acordo de formatos de dados que permite Python e Elm trabalharem em paralelo sem esperar o Prolog. Deve ser fechado antes de tudo. Se for preciso mudar algo depois, avisar o grupo inteiro.

### Tabuleiro

Grade 6x6, coordenadas começando em 0. Cada casa é de um destes tipos:

```json
{ "kind": "block" }
{ "kind": "clue", "across": 10, "down": null }
{ "kind": "playable" }
```

- `across` é a soma da sequência à direita da casa; `down`, a soma da sequência abaixo. `null` significa que não há pista nessa direção.
- A solução **nunca** vai junto com o puzzle.

```json
{ "puzzle": { "cells": [ [ ...6 casas... ], ... 6 linhas ... ] } }
```

### Entradas do jogador

```json
[ { "row": 1, "col": 2, "value": 7 } ]
```

Uma casa jogável que não aparece na lista está vazia. `value` vai de 1 a 9.

### Rotas

| Rota | Envia | Recebe |
|------|-------|--------|
| `POST /api/generate` | `{}` | `{ "puzzle": {...} }` |
| `POST /api/check` | `puzzle` e `entries` | `{ "state": "incomplete" \| "inconsistent" \| "solved" }` |
| `POST /api/solve` | `puzzle` e `entries` | `{ "solution": [ {row, col, value}, ... ] }` |
| `POST /api/hint` | `puzzle` e `entries` | `{ "kind": "hint", "row": 1, "col": 2, "value": 7 }` ou `{ "kind": "complete" \| "inconsistent" \| "no_forced_hint" }` |

**Erros:** `422` com `{ "detail": "mensagem legível" }` para entrada inválida ou `solve` sem solução; `503` se a geração passar de 10 segundos. Nunca devolver detalhes internos (stack trace).

**Significado do `check`:**
- `incomplete`: ainda há casas vazias, mas existe ao menos uma solução compatível com o que foi preenchido.
- `inconsistent`: não existe nenhuma solução compatível com o que foi preenchido.
- `solved`: tudo preenchido e todas as somas e restrições satisfeitas.

### Passagem Python ↔ Prolog

O Janus não transporta termos compostos, só listas e números. Por isso:
- Casa: `[Tipo, Across, Down]`, com `Tipo` 0 = bloqueio, 1 = pista, 2 = jogável; `Across`/`Down` 0 = sem pista.
- Puzzle: lista de 6 linhas com 6 casas.
- Entradas e solução: lista de triplas `[Linha, Coluna, Valor]`.

### Predicados Prolog

```
generate(-Puzzle)
solve(+Puzzle, +Entradas, -Solucao)
check(+Puzzle, +Entradas, -Estado)
hint(+Puzzle, +Entradas, -Resultado)
solution_count(+Puzzle, +Entradas, -N)     % conta até 2
```

## 4. Sequência de execução

As fases são feitas **em ordem**: só se passa para a próxima quando a anterior está pronta. Dentro de uma fase, as áreas trabalham em paralelo.

### Fase 0: Preparação

- Todos clonam o repositório e rodam `make install` e `make dev` para confirmar que o template sobe.
- O grupo fecha o contrato (seção 3).
- Cada pessoa cria seu branch de trabalho.

**Passa para a Fase 1 quando:** o contrato está acordado e todos têm o ambiente funcionando.

### Fase 1: Base (versões mínimas)

- **Prolog:** `solve` e `check` funcionando no terminal (`swipl`) com um puzzle fixo. Criar 2 ou 3 puzzles fixos com solução conhecida, que o resto do grupo usa para testar.
- **Python:** rotas `check` e `solve` funcionando com o puzzle fixo (pode usar dados de mentira enquanto o Prolog não está pronto).
- **Elm:** tipos do domínio e decoder do puzzle; tabuleiro estático desenhando um puzzle fixo; esqueleto do `Main.elm` compilando.
- **Documentação:** começar as seções iniciais do relatório.

**Passa para a Fase 2 quando:** um puzzle fixo é resolvido e verificado de ponta a ponta e o tabuleiro aparece na tela.

### Fase 2: Funcionalidades

- **Prolog:** gerador com solução única, dica e testes.
- **Python:** rotas `generate` e `hint`, erros 422 e 503, testes da API.
- **Elm:** encoders/decoders de todas as rotas, edição de casas, teclado, botão Verificar e controles na tela.

**Passa para a Fase 3 quando:** cada peça funciona sozinha (Prolog no terminal, API na página `/docs`, Elm compilando).

### Fase 3: Integração

- Fluxo completo no navegador: gerar → preencher → verificar → dica → resolver → concluir.
- Bloqueio de ações durante requisições e preservação do preenchimento em caso de falha.
- Gerar vários puzzles seguidos para testar a estabilidade do gerador.

**Ponto de decisão:** se o gerador não estiver estável ao fim desta fase, o grupo decide entre reduzir o escopo ou usar um prazo com desconto de nota (ver `AVALIACAO.md`).

### Fase 4: Congelamento e documentação

- Congelar funcionalidades: daqui em diante, só correção de bugs.
- Preencher o relatório, tirar capturas de tela e conferir as referências `arquivo:linha`.
- Rodar todas as conferências de qualidade (seção 7).

### Fase 5: Revisão e entrega

- Testar a instalação em uma máquina limpa, seguindo apenas o README.
- Marcar a tag/commit final e registrá-la no relatório.
- Cada pessoa preenche e valida a própria avaliação 360.
- Entregar pelo GitHub Classroom.

## 5. O que cada área faz e como

### Prolog (arquivos em `backend/prolog/`)

**Núcleo das regras (`kakuro.pl`)**
- Validar o puzzle recebido (6x6, tipos válidos, sequências de 2 a 5 casas, cada casa branca em exatamente uma sequência horizontal e uma vertical).
- Criar **uma variável lógica por casa branca**. Uma casa que fica no cruzamento de duas sequências usa a **mesma variável** nas duas, e é assim que as restrições se comunicam.
- Para cada sequência: domínio `1..9`, `all_distinct/1` (sem repetição) e `sum/3` (soma igual à pista). Só depois de declarar todas as restrições é que se chama `labeling/2` para buscar os valores.
- Os valores que o jogador já preencheu são ligados às variáveis correspondentes, então a resolução respeita o que ele digitou.
- `solve/3` devolve uma solução compatível com as entradas (e falha se não houver).
- `check/3` devolve `incomplete` apenas se existir ao menos uma solução compatível; `inconsistent` se não existir; `solved` se estiver tudo preenchido e correto.
- `solution_count/3` conta soluções **até 2** (para saber se há 0, 1 ou mais de uma), usando por exemplo `call_nth/2`.

**Gerador (`generator.pl`)**
1. Escolher uma máscara 6x6 válida (um conjunto pré-definido de estruturas de bloqueios e pistas). Máscaras com muitas sequências curtas (2 a 3 casas) tendem a gerar menos ambiguidade.
2. Preencher as casas brancas aleatoriamente, respeitando dígitos distintos em cada sequência.
3. Calcular as pistas a partir desse preenchimento.
4. Esconder os valores e contar soluções (até 2). Só aceitar o puzzle se houver **exatamente 1**; se houver mais, sortear de novo.
5. Limite de 10 segundos. Ao estourar, devolver falha controlada (a API transforma em 503). Nunca publicar um puzzle inválido.
6. Aceitar uma semente opcional para reproduzir falhas.

**Dica (`hint/3`)**
- Primeiro verificar se existe solução. Depois, para uma casa **vazia**, testar se existe alguma solução em que ela tenha valor diferente do candidato. Se não existir, o valor é **logicamente forçado** e pode ser revelado.
- Nunca alterar números que o jogador já preencheu.
- Resultados possíveis: dica com coordenada e valor, `complete` (nada a dar), `inconsistent` (preenchimento sem solução) ou `no_forced_hint` (nenhum valor é forçado).

**Testes (`test_kakuro.pl`, com plunit)**
- Soma e repetição: sequência de 2 casas com soma 4 aceita `[1,3]` e `[3,1]` e rejeita `[2,2]`.
- Cruzamento: a mesma variável aparece nas duas sequências.
- Unicidade: detectar 0, 1 e 2 ou mais soluções.
- `solve` preserva as entradas e falha sem solução; `check` nos três estados; `hint` só em casa vazia e com valor forçado.
- Geração: resultado 6x6, estrutura válida e solução única.

### Python (`backend/app/` e `backend/tests/`)

O Python **não resolve nada**: só valida, converte e repassa.
- Descrever os formatos do contrato (`schemas.py`) e validar a entrada: coordenadas inválidas, posições repetidas, entrada em casa de pista ou bloqueio, valores fora de 1 a 9.
- Carregar os arquivos Prolog com o Janus e converter entre JSON e as listas da seção 3 (`prolog.py`). Os dados do usuário devem ir como **parâmetros** da consulta, nunca colados dentro de texto Prolog.
- Expor as 4 rotas (`main.py`) com erros 422 e 503 padronizados e mensagens legíveis.
- Testes com pytest usando os puzzles fixos criados pelo Prolog.
- Ajustar o `Makefile` (alvos de teste e consulta do Janus) e o título da página.

### Elm (`frontend/src/`)

Três frentes, que se encaixam:

**Domínio e API (`Kakuro.elm`, `Api.elm`)**
- Tipos do jogo: casa que pode ser bloqueio, pista (com `across` e `down` opcionais) ou jogável (com dígito opcional). Dígito e tabuleiro são criados por funções que validam (nada fora de 1 a 9, nada fora de 6x6).
- Funções puras: colocar e apagar dígito, reiniciar (limpa só o preenchimento), permitir seleção apenas de casas jogáveis.
- Feedback local imediato: repetição na sequência e soma excedida. Quem decide se existe solução é o Prolog, não o Elm.
- Encoders e decoders próprios para o contrato (puzzle, entradas, respostas e erros).
- **Publicar os tipos cedo**, porque as outras duas frentes dependem deles.

**Estado e eventos (`Main.elm`)**
- Estados do jogo como tipos próprios: carregando, partida pronta, operação em andamento, falha recuperável e concluído.
- Mensagens e `update` para novo jogo, selecionar, digitar, apagar, reiniciar, verificar, dica e resolver; teclado por `subscriptions` (setas, 1 a 9, Backspace/Delete).
- Invalidar o resultado da verificação a cada edição.
- Durante uma requisição HTTP, bloquear edição, troca de puzzle e reinício, para uma resposta não ser aplicada ao estado errado.
- Em caso de falha de comunicação: manter o preenchimento, mostrar erro legível, permitir nova tentativa. A dica altera só a casa indicada; o resolver não sobrescreve o que o jogador digitou.

**Telas e CSS (`View/Board.elm`, `View/Controls.elm`, `style.css`)**
- Tabuleiro 6x6 com pistas diagonais (soma horizontal no canto superior direito, vertical no inferior esquerdo), destaque da casa selecionada e dos conflitos.
- Botões 1 a 9, Novo jogo, Reiniciar, Verificar, Dica, Resolver e mensagens de estado e erro.
- As telas só recebem dados e funções de resposta; nunca fazem HTTP.
- Para o visual, partir do `style-simples.css` (mais fácil de adaptar) e ajustar as classes ao Kakuro.

### Documentação e qualidade

- Reunir e revisar o `RELATORIO.md` (as 13 seções), removendo comentários de instrução e campos não preenchidos.
- Tirar capturas de tela, conferir referências `arquivo:linha` e preparar o roteiro de apresentação (15 minutos, todos falam).
- Garantir o registro honesto do uso de IA, inclusive na elaboração deste plano, e das contribuições reais de cada pessoa.
- Rodar as conferências finais (seção 7).

## 6. Regras de trabalho em grupo

- Um branch por tarefa, com nomes como `feat/prolog-gerador` ou `feat/elm-views`.
- Commits pequenos, feitos por quem escreveu o código, com prefixo (`feat:`, `fix:`, `test:`, `docs:`). O relatório exige contribuições coerentes com o histórico de commits.
- Todo trabalho entra na `main` por **Pull Request**, revisado por pelo menos uma pessoa de outra área.
- Nada de `push --force` na `main` e nada de apagar código do template sem avisar.
- Antes de começar a trabalhar, atualizar seu branch com a `main`.
- Se algo travar, avisar o grupo na hora, dizendo o que falta e de quem.

## 7. Conferências antes de entregar

- `make install` e `make dev` funcionam em uma máquina limpa.
- `make test`, `make test-prolog` e `make test-backend` passam.
- O Prolog carrega sem avisos.
- `cd frontend && npm run build` roda sem erros.
- `cd frontend && npx --no-install elm-format --validate src/` roda sem erros.
- `make validar` roda sem erros.
- 10 puzzles gerados em sequência no navegador, sem falha.
- Teste manual de teclado, bloqueio durante requisição e preservação do preenchimento após falha de rede.
- `RELATORIO.md` completo, sem comentários de instrução nem campos entre colchetes, com capturas existentes.
- Tag/commit final registrado no relatório.
- Avaliação 360 de cada pessoa validada.

## 8. Linha de corte

- **Obrigatório:** geração 6x6 com solução única, partida completa, verificar, dica, resolver e documentação.
- **Se sobrar tempo:** testes em Elm, polimento visual, slides.
- **Pode ficar de fora:** dificuldade calculada, editor de puzzles, cronômetro e salvamento.