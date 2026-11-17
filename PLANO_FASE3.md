# Plano de Implementação — Fase 3: Integração (Kakuro: Prolog + Python + Elm)

Este documento reúne o estado real do repositório e o roteiro exato que **outro agente** deve seguir para executar a **Fase 3 (Integração)** do projeto, cobrindo as **Issues #28 e #29**, os desbloqueios necessários dos PRs abertos e os contratos de integração entre **Frontend (Elm)**, **API (FastAPI/Python)** e **Motor Lógico (SWI-Prolog)**.

---

## 1. Estado Atual do Projeto (Ponto de Partida)

Antes de iniciar qualquer alteração da Fase 3, verifique a linha de base atual do repositório `Pedrovargas10/kakuro-paradigmas`:

### 1.1 O que já está mergeado na `main` (`d9faa6d`)
- **Prolog (`backend/prolog/`):**
  - `kakuro.pl`: predicados `solution_count/3`, `solve/3`, `check/3`, `hint/3` (formato Opção A: `"block"`, `"white"`, `[Across, Down]`, coordenadas `0..5`).
  - `generator.pl`: predicados `generate/1`, `generate/2`, `generate_with_solution/2` com limite de 10 segundos e unicidade (`solution_count = 1`).
  - `test_kakuro.pl`: 21 testes `plunit` passando.
- **Python (`backend/app/` e `backend/tests/` — PRs #33 e #34 de Caio):**
  - `schemas.py`: validação estrita (`StrictInt`) de `Puzzle` 6×6 (`BlockCell`, `PlayableCell`, `ClueCell`), `Entry` (`0..5`, `1..9`), bloqueio de duplicatas e de entradas em `block`/`clue`, `SolveRequest`, `SolveResponse`, `HintRequest`, `HintResponse` e `ErrorResponse`.
  - `prolog.py`: `ensure_prolog_loaded`, conversores Opção A (`cell_to_prolog`, `puzzle_to_prolog`, `entries_to_prolog`, `prolog_to_entries`), `query_prolog` (diferenciando `PrologInputError` → 422 de falhas internas → 500), `solve_puzzle` e `get_hint`.
  - `main.py`: FastAPI com CORS liberado (`allow_origins=["*"]`), handlers padronizados `422` (`{"detail": "<mensagem>"}`) e `500` (sem stack trace), e rotas `POST /api/solve` e `POST /api/hint`.
  - `tests/test_api.py`: testes unitários e de integração de `schemas`, `solve` e `hint`.

### 1.2 PRs abertos que precisam de merge/revisão para a Fase 3 rodar
1. **PR #30 (`feat/python-makefile` — Caio, Issues #8 e #11):**
   - Implementa `Makefile` (`install`, `dev`, `test-prolog`, `test-backend`, `test`, `validar`).
   - Revisão de `make dev` corrigida no commit `e030f6a` (cleanup de sinais sem `kill 0` e propagação de código de saída). Aguardando re-revisão/merge do `@Pedrovargas10`.
2. **PRs #35 a #40 (`Pedrovargas10` — Issues #6, #15, #16, #23, #24, #10):**
   - **#35:** `backend/pyproject.toml`, `backend/uv.lock`, `backend/README.md`, `lifespan` carregando `kakuro.pl` e `generator.pl`.
   - **#36:** `prolog_to_cell`, `prolog_to_puzzle`, `generate_puzzle`, `check_puzzle`, `GenerationUnavailableError`.
   - **#37:** `CheckRequest`, `CheckResponse`, `POST /api/check`.
   - **#38:** `GenerateRequest`, `GenerateResponse`, `POST /api/generate` e handler HTTP `503`.
   - **#39:** `backend/tests/test_backend_contract.py`, `fixtures/mini.json` e ajuste `_is_validation_prolog_error` usando `exc.term` para termos reais do Janus.
   - **#40:** `docs/API_PYTHON.md`, `backend/scripts/verificar_api.py` (fluxo HTTP de ponta a ponta) e `RELATORIO.md`.
   - **Ação para o agente:** verificar se os PRs #30 e #35–#40 já entraram na `main`; caso #35–#40 ainda estejam abertos, realizar a **revisão cruzada** deles (verificando especialmente integração real com SWI-Prolog 9.2+ e `uv run --locked pytest`).

### 1.3 Pendências de outras áreas que bloqueiam o E2E completo no navegador
- **Frontend Elm (`frontend/`):** atualmente todos os arquivos em `frontend/` (`package.json`, `elm.json`, `vite.config.js`, `src/*.elm`) estão vazios na `main` (Issues `#7`, `#17`, `#18`, `#19`, `#25`, `#26`, `#27`, `#28` ainda abertas).
- **Prolog (`backend/prolog/`):** ainda abertas as Issues `#12` (validação estrutural em `kakuro.pl`), `#13` (`catch` amplo, `check`/`hint` com tabuleiro completo errado e testes duplicados em `test_kakuro.pl`), `#14` (`docs/fixtures/`) e `#21` (`hint/3` só revelar valor logicamente forçado).
- **Validador (`scripts/validar_entrega.py`):** ainda vazio (Issue `#9`).

---

## 2. Contrato HTTP Exato para Integração (Elm ↔ Python)

Qualquer código de integração (Elm ou scripts de teste) deve obedecer aos contratos abaixo. O conjunto completo está implementado na pilha dos PRs #35–#40; na `main` atual, apenas `solve` e `hint` estão integrados.

- **Método e Content-Type:** todas as rotas são `POST` com `application/json`.
- **Base URL no desenvolvimento:** backend em `http://127.0.0.1:8000`; o Vite (`frontend/vite.config.js`, Issue #7) deve fazer proxy de `/api` para `http://localhost:8000`.
- **Regras rígidas de tipos (`StrictInt` e `extra="forbid"`):**
  - `row` e `col`: inteiros JSON estritos de `0` a `5` (nunca strings `"1"` ou floats `1.0`).
  - `value`: inteiro JSON estrito de `1` a `9`.
  - `across` e `down` em células `"clue"`: inteiros estritos `> 0` ou `null` (ao menos um não nulo).
  - Não enviar campos extras não previstos no schema.
  - Em `entries`: sem coordenadas `(row, col)` repetidas e apenas em células `"playable"`.

| Rota | Request JSON | Response `200` | Erros esperados |
| :--- | :--- | :--- | :--- |
| `POST /api/generate` | `{}` | `{"puzzle": {"cells": [[...6...], ...6...]}}` (sem solução) | `422` (payload inválido), `503` (timeout > 10s), `500` |
| `POST /api/check` | `{"puzzle": {...}, "entries": [...]}` | `{"state": "incomplete" \| "inconsistent" \| "solved"}` | `422` (`{"detail": "str"}`), `500` |
| `POST /api/solve` | `{"puzzle": {...}, "entries": [...]}` | `{"solution": [{"row": int, "col": int, "value": int}, ...]}` | `422` (sem solução ou entrada inválida), `500` |
| `POST /api/hint` | `{"puzzle": {...}, "entries": [...]}` | `{"kind": "hint", "row": int, "col": int, "value": int}` ou `{"kind": "complete" \| "inconsistent" \| "no_forced_hint"}` | `422` (`{"detail": "str"}`), `500` |

> **Formato de erro padrão:** qualquer erro (`422`, `503`, `500`) retorna `{"detail": "mensagem legível"}`, onde `detail` é sempre uma **string simples** (nunca array do Pydantic nem stack trace).

---

## 3. Roteiro de Execução da Fase 3 (Para o Agente)

Execute as etapas na ordem abaixo. Só avance para uma etapa após validar os pré-requisitos da anterior.

### Etapa 1 — Preparação do Ambiente e Sincronização (`Issue #2`, `#8`, `#10`)
1. **Validar ferramentas da máquina:**
   - `swipl --version` deve ser **9.2+** (o pacote `9.0.4` padrão do Ubuntu **não** possui Janus; atualizar via `ppa:swi-prolog/stable` se necessário).
   - `node --version` deve ser **20+** (`v24.21.0` já disponível nesta máquina).
   - `uv --version` deve estar instalado e no `PATH`.
   - Comentar as versões verificadas na **Issue #2** quando todas estiverem prontas.
2. **Sincronizar a branch `main`:**
   - Garantir que o **PR #30** (`Makefile`) e os **PRs #35–#40** (`@Pedrovargas10`) tenham sido revisados e mergeados na `main`.
   - Caso os PRs `#35–#40` ainda estejam abertos, fazer a revisão cruzada conferindo:
     - `cd backend && uv sync --locked && uv run --locked pytest` (todos os testes passam contra SWI-Prolog real);
     - `swipl -g run_tests -t halt backend/prolog/test_kakuro.pl`.
   - Atualizar a `main` local (`git checkout main && git pull --ff-only origin main`).
3. **Validar a API Python de ponta a ponta (sem depender do navegador):**
   - Subir o backend: `cd backend && uv run --locked fastapi dev app/main.py`
   - Em outro terminal: `cd backend && uv run --locked python scripts/verificar_api.py --partidas 10`
   - Confirmar saída JSON com `partidas_verificadas: 10` e `status 0`, observando os tempos máximos e médios de geração para o relatório.

---

### Etapa 2 — Integração no Frontend Elm (`Issue #28`)
> **Pré-requisito:** as Issues `#7`, `#17`, `#18`, `#19`, `#25`, `#26` e `#27` (base Elm, tipos, encoders/decoders, views e botão Verificar) já devem estar na `main` ou na branch base.

Se você for atuar na implementação da **Issue #28** em `frontend/src/Main.elm` (em branch `feat/elm-integracao-solve-hint`):
1. **Botão Dica (`POST /api/hint`):**
   - Enviar o `puzzle` atual e as `entries` preenchidas pelo jogador.
   - Se receber `{"kind": "hint", row, col, value}`: preencher **apenas** a célula `(row, col)` (sem apagar nem alterar outras casas preenchidas pelo jogador) e invalidar eventual estado anterior de verificação.
   - Se receber `complete`, `inconsistent` ou `no_forced_hint`: exibir mensagem clara ao jogador na UI sem modificar o tabuleiro.
2. **Botão Resolver (`POST /api/solve`):**
   - Enviar o `puzzle` atual e as `entries` do jogador.
   - Aplicar a solução recebida **sem sobrescrever** os dígitos já digitados pelo jogador (o backend já preserva as entradas compatíveis; no Elm, fazer merge respeitando as entradas do usuário e atualizar para o estado adequado).
   - Se receber HTTP `422`, exibir a mensagem de `detail` informando que não há solução compatível com o preenchimento atual, mantendo tudo o que o jogador digitou.
3. **Estado de conclusão (`solved`):**
   - Quando `/api/check` retornar `{"state": "solved"}`, transicionar o `Model` para o estado de partida concluída e exibir mensagem clara de conclusão.
4. **Bloqueio durante requisição HTTP em andamento:**
   - Enquanto houver uma requisição pendente (`/api/generate`, `/api/check`, `/api/hint`, `/api/solve`), o `Model` deve permanecer em estado de operação em andamento e **ignorar/desabilitar** edição de dígitos, seleção que altere valor, clique em `Novo jogo` e clique em `Reiniciar`.
   - Isso impede condições de corrida (respostas chegando e sendo aplicadas a um tabuleiro diferente).
5. **Preservação em caso de falha de rede ou erro HTTP (`503`, `422`, `500`, timeout):**
   - Nunca limpar `entries` ou descartar o `puzzle` atual quando uma requisição falhar.
   - Extrair o campo `detail` (quando for `BadStatus` JSON com `422`/`503`/`500`) ou exibir mensagem amigável de erro de comunicação (ex.: backend offline), destravando os controles para permitir nova tentativa.
6. **Validação obrigatória do Elm antes de abrir PR:**
   - `cd frontend && npm run build` (sem erros)
   - `cd frontend && npx --no-install elm-format --validate src/` (sem erros de formatação)
   - Revisar a arquitetura: `Kakuro.elm` puro (sem `Http` nem `Html`), `View/*.elm` sem `Http`, `Main.elm` coordenando efeitos.

---

### Etapa 3 — Testes de Fluxo Completo e Estabilidade (`Issue #29`)

Com **Prolog + Python + Elm** integrados na `main` (ou em uma branch de integração para conferência):

1. **Subir o sistema completo pelo ponto de entrada oficial:**
   ```sh
   make install
   make dev
   ```
   Confirmar que backend (`http://127.0.0.1:8000/docs`) e frontend (`http://localhost:5173`) sobem juntos e respondem sem erro de CORS ou proxy.

2. **Executar o checklist completo da Issue #29 no navegador:**
   - [ ] **Fluxo principal:** abrir o app (gera puzzle automaticamente) $\rightarrow$ preencher parte das casas $\rightarrow$ clicar em **Verificar** (deve mostrar `incomplete`) $\rightarrow$ colocar dígito conflitante ou errado e verificar (`inconsistent`) $\rightarrow$ apagar erro $\rightarrow$ pedir **Dica** (preenche só a casa indicada, ou avisa caso `no_forced_hint`) $\rightarrow$ clicar em **Resolver** (preenche o restante sem apagar o que foi digitado) $\rightarrow$ **Verificar** confirma `solved` e exibe mensagem de conclusão.
   - [ ] **Estabilidade do gerador:** clicar em **Novo jogo** e gerar **10 puzzles seguidos** sem erro `503` ou puzzle inválido/ambíguo.
   - [ ] **Reiniciar:** preencher algumas casas e clicar em **Reiniciar** $\rightarrow$ apenas os dígitos do jogador são limpos; pistas (`across`/`down`) e bloqueios permanecem intactos.
   - [ ] **Teclado:** navegar pelas casas jogáveis com setas (`ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`), digitar `1` a `9`, apagar com `Backspace` e `Delete`.
   - [ ] **Bloqueio de casas não jogáveis:** tentar clicar ou digitar sobre casas `block` e `clue` $\rightarrow$ nada é alterado.
   - [ ] **Bloqueio durante requisição:** observar que botões de ação/edição ficam travados enquanto uma requisição está em andamento.
   - [ ] **Resiliência a falha de rede:** com uma partida parcialmente preenchida no navegador, parar somente o backend, mantendo o frontend ativo (subir os dois em terminais separados para este teste; `Ctrl+C` no `make dev` encerra ambos), acionar **Verificar** / **Dica** / **Resolver** e conferir que:
     1. O preenchimento do jogador **não se perde**;
     2. Aparece uma mensagem de erro legível;
     3. Ao religar o backend, uma nova tentativa funciona normalmente.

3. **Executar todas as suítes automatizadas:**
   ```sh
   make test
   cd frontend && npm run build && npx --no-install elm-format --validate src/
   ```

4. **Registro de Bugs:**
   - Para cada falha encontrada na Etapa 3, **abrir uma issue nova** no GitHub (`Pedrovargas10/kakuro-paradigmas`) contendo:
     - Label da área responsável (`prolog`, `python` ou `elm`) + `bug`;
     - Passos exatos para reproduzir (incluindo o JSON do puzzle ou semente do gerador, se aplicável);
     - Resultado observado vs. resultado esperado.

---

## 4. Critérios de Decisão e Saída da Fase 3

- **Ponto de decisão sobre o gerador (`PLANOEXECUCAO.md`):** se após os testes de integração o `generator.pl` apresentar falhas frequentes (`503` nos 10 testes seguidos ou travamentos), o grupo deve decidir imediatamente entre ajustar as máscaras/heurística no Prolog (`Issue #20`) ou acionar o plano de contingência antes da Fase 4.
- **Fase 3 concluída quando:**
  1. Os PRs `#30` e `#35–#40` e as issues de Elm/Prolog estão integrados na `main`;
  2. Todos os checkboxes da **Issue #28** e da **Issue #29** foram validados;
  3. `make install`, `make dev`, `make test`, `npm run build` e `elm-format --validate src/` rodam limpos;
  4. Bugs que impedem qualquer critério obrigatório de #28/#29 estão corrigidos. Os demais estão registrados com passos de reprodução e decisão explícita do grupo para a Fase 4.


## 5. Retomada da execução — 17/11/2026

Branch de trabalho: `feat/fase3-integracao`, criada a partir de `origin/main` em `d9faa6d`.

### Evidências já obtidas

- Ambiente: Python 3.12.3, SWI-Prolog 9.2.9, Node 24.21.0, uv 0.13.9 e Janus 1.5.3. `uv` e `swipl` instalados em `~/.local`; PATH configurado no Bash.
- Revisão dos diffs #35–#40 concluída, com reviews APPROVED publicadas como `CaioSoandrd`, identificando assistência do Codex e autorização do usuário.
- Validação acumulada em `d6837b06d593b2e2bf8bb577d1ac187718409742`: 83 testes pytest passaram com Janus real; 21 testes plunit passaram, com execução duplicada confirmada (#13).
- Dez partidas HTTP passaram: geração média 1,827 s, máxima 5,841 s. Isso não valida o navegador nem substitui as 20 gerações exigidas pela #20.
- Cópia utilizada para validação: `/tmp/kakuro-pedro-review`. Esse diretório é temporário; repetir os testes na branch integrada antes de encerrar a fase.
- PRs #30 e #35–#40 ainda abertos. Aprovação não equivale a merge.

### Ordem de integração e condições de entrada

1. Integrar #35 → #36 → #37 → #38 → #39 → #40; após cada integração, mudar a base do próximo para `main` e conferir o diff. #30 é independente dessa pilha.
2. Conferir #2 (versões dos sete integrantes), #3 (aprovação do contrato pelos sete) e #5 (README e arquivos ignorados). Na consulta desta sessão, #2 tinha zero comentários e #3 apenas o aceite de Caio. #4 está encerrada com a Opção A confirmada.
3. Antes de implementar #28, obter a base Elm das #7, #17–#19 e #25–#27. Os arquivos estão vazios na `main`; implementar essa base representa ampliar o escopo para tarefas anteriores da equipe Elm.
4. Conferir explicitamente #12, #13, #14, #20, #21 e #22 antes do aceite integrado. #14 exige 2 ou 3 puzzles compartilhados com solução JSON, representação Prolog e unicidade comprovada. O fixture temporário dos testes Python não encerra #14.
5. Para #20, comprovar 20 gerações válidas e únicas dentro do limite e registrar média de tentativas. Para #22, verificar testes de entradas/puzzles inválidos, quatro resultados de dica, gerador e uso dos fixtures compartilhados.

### Regressões adicionais no navegador

- [ ] Feedback local imediato para repetição e soma excedida (#25).
- [ ] Invalidar a verificação anterior a cada edição (#26).
- [ ] Botões 1 a 9, destaque de seleção/conflitos e orientação das pistas diagonais (#27).
- [ ] Registrar commit testado, comandos, resultados e bugs associados antes de marcar cada item de #28/#29.

### Pendências de acompanhamento

As issues #10 e #11 atravessam fases e atualmente não têm milestone. Os milestones das fases 4 e 5 ainda não têm issues: cadastrar as tarefas de documentação, validação e entrega quando o grupo organizar essas fases. A issue #1 é referência até o fim do projeto e não deve impedir o avanço apenas por permanecer aberta.


### Escopo autorizado para esta branch

Manter o trabalho em Python e preparar a integração; a base Elm será entregue
pela equipe responsável. A branch reúne localmente a pilha #35–#40 e #30, sem
merge na `main` remota. Usar `make install-backend`, `make dev-backend` e
`make test-integration` enquanto o frontend não estiver disponível.
O verificador HTTP agora cobre também erros de entrada e nova tentativa válida.


### Validação desta preparação Python

- `make install-backend`: dependências instaladas com lockfile.
- `make test`: 83 testes Python e 21 testes Prolog passaram; duplicação plunit
  segue registrada na #13.
- `make test-integration`: dez partidas com os novos cenários passaram;
  geração média 1,861 s e máxima 8,659 s nesta execução.
- `make dev-backend`: o monitor nativo encontrou o limite de arquivos abertos
  desta máquina; usar `WATCHFILES_FORCE_POLLING=true make dev-backend`.
- O frontend não foi alterado. #28/#29 permanecem pendentes de validação visual.

## 6. Preparação Python da Fase 4

Branch `docs/python-fase4-entrega`, baseada na integração #42 e atualizada com
`main` após os merges #35–#40. A preparação inclui README, arquivos ignorados,
contribuições de Caio e checklist em `docs/ENTREGA_PYTHON.md`.

`make validar` agora rejeita o arquivo oficial ausente/vazio para evitar falso
sucesso. O script do professor permanece pendente na #9. Foram conferidos o
caminho de rejeição e a execução de um script não vazio em diretório temporário;
isso valida o alvo Makefile, não os documentos de entrega.

A Fase 3 coletiva continua aberta: preparar documentação não substitui #28/#29
nem autoriza marcar congelamento ou entrega como concluídos.
