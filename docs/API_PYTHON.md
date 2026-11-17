# API Python do Kakuro

Em `backend/`, executar `uv sync --locked` e `uv run fastapi dev app/main.py`.
Pré-requisitos e testes estão em [backend/README.md](../backend/README.md).
O Swagger está em <http://127.0.0.1:8000/docs>; o contrato completo, em
<http://127.0.0.1:8000/openapi.json>.

Todas as rotas são POST. O tabuleiro é 6x6 com coordenadas de 0 a 5; o puzzle
usa `cells`, com casas `block`, `clue` (`across`/`down` opcionais) ou `playable`.
As entradas são objetos `row`, `col`, `value`, com dígitos inteiros de 1 a 9.
Strings, booleanos e decimais não são convertidos silenciosamente em inteiros.
Entradas omitidas representam uma lista vazia; casas ausentes nessa lista estão vazias.

| Rota | Corpo | Resposta de sucesso |
|---|---|---|
| `/api/generate` | `{}` | `{"puzzle": {"cells": ...}}`, sem solução |
| `/api/check` | `{"puzzle": ..., "entries": ...}` | `{"state": "incomplete"}`, `inconsistent` ou `solved` |
| `/api/solve` | `{"puzzle": ..., "entries": ...}` | `{"solution": [{"row": ..., "col": ..., "value": ...}]}` |
| `/api/hint` | `{"puzzle": ..., "entries": ...}` | `{"kind": "hint", "row": ..., "col": ..., "value": ...}` ou `complete`, `inconsistent`, `no_forced_hint` |

`inconsistent` e os estados de dica são resultados normais (HTTP 200).
Entrada inválida e resolução sem solução retornam HTTP 422. Geração que não
consegue produzir um puzzle em 10 segundos retorna HTTP 503; falhas internas,
HTTP 500. Os erros usam `{"detail": "mensagem legível"}`, sem detalhes internos.
O cliente pode repetir uma geração após 503. Não há sessões ou banco de dados.

## Conferência no Swagger

1. Executar `/api/generate` com `{}` e copiar o objeto `puzzle` da resposta.
2. Executar `/api/check` com esse puzzle e `entries: []`: resultado `incomplete`.
3. Executar `/api/solve` com o mesmo corpo e guardar `solution`.
4. Executar `/api/check` com essa solução como `entries`: resultado `solved`.
5. Executar `/api/hint` com todas as entradas exceto uma: a dica deve indicar
   a casa vazia. Com a solução completa, o resultado deve ser `complete`.
6. Enviar entrada em bloqueio/pista, posição repetida, coordenada 6 ou valor 0/10:
   esperar 422. Enviar campos extras a `/api/generate`: esperar 422.

O timeout e as falhas internas são cobertos pelos testes automatizados, sem
dependência de provocar uma falha aleatória do gerador no Swagger.

## Fluxo automatizado por HTTP real

Com o backend iniciado, em outro terminal dentro de `backend/`:

```sh
uv run --locked python scripts/verificar_api.py --partidas 10
```

O comando confere gerar, verificar, resolver, pedir dica, preservar uma entrada
e concluir, sem reproduzir regras do Kakuro em Python. Ele retorna status não zero
se o fluxo falhar e imprime as durações de geração quando passa. Não substitui
os testes do navegador, teclado e rede da equipe (#29).

## Contrato com Prolog

A opção A da issue #4 converte `block` em `"block"`, `playable` em `"white"`
e `clue` em `[Across, Down]`, com `null` convertido em `0`. Entradas e soluções
usam triplas `[Linha, Coluna, Valor]`. As consultas Janus têm texto fixo e dados
vinculados em parâmetros. O Prolog decide consistência, solução, unicidade e dica.

O gerador existente usa `generator:generate/1` e já limita sua busca a 10 segundos.
A ponte mantém esse limite e converte falha/timeout em 503. O Python não usa
`generate_with_solution/2`, catálogo fixo ou algoritmo próprio de geração.

## Dependências e limites desta entrega

- O alvo `make test-backend` está no PR #30 de Caio; até sua integração, executar
  `uv run --locked pytest` diretamente em `backend/`.
- Os fixtures compartilhados dependem da issue #14. Os testes Python usam uma
  transcrição identificada do puzzle fixo já presente nos testes Prolog.
- Validação estrutural e correções do motor Prolog continuam nas issues #12,
  #13 e #21. Esta entrega não declara essas tarefas concluídas.
- A documentação e a verificação acima cobrem a API. A infraestrutura Elm e o
  fluxo visual permanecem nas tarefas da equipe de frontend.
