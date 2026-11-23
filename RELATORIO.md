# Kakuro — Prolog, Python e Elm

## 1. Identificação

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---------------|-----------|-----------------|----------------|
| [Nome]        | [000000]  | [14h]           | [@usuario]     |
| [Nome]        | [000000]  | [16h]           | [@usuario]     |
| [Nome]        | [000000]  | [14h]           | [@usuario]     |
| [Nome]        | [000000]  | [16h]           | [@usuario]     |
| [Nome]        | [000000]  | [14h]           | [@usuario]     |

- **Nome do projeto:** Kakuro — Prolog, Python e Elm
- **Nome do grupo:** Equipe kakuro
- **Repositório:** https://github.com/Pedrovargas10/kakuro-paradigmas
- **Commit ou tag entregue:** `f98d0a418c4b77ecb5f0583a892931330bcedf35`
- **Ponto de partida:** outro jogo conhecido
- **Slides da apresentação oral:** [`docs/apresentacao.pdf` | link externo | não há]
A referência acima identifica a base técnica desta revisão documental. O grupo deve atualizá-la para a versão final antes da entrega.

## 2. Resumo

Kakuro é um quebra-cabeça de somas em uma grade 6×6. O jogador preenche as casas com dígitos de 1 a 9, sem repetição dentro de cada sequência, respeitando as pistas horizontais e verticais. O Prolog gera puzzles com solução única, verifica preenchimentos, encontra soluções e identifica dicas forçadas. A interface Elm permite jogar no navegador e usa uma API Python para consultar o motor lógico.

Captura real da interface pendente de inclusão antes da entrega. A versão disponível neste ambiente não tem as dependências do frontend instaladas.

## 3. Como executar

**Requisitos**

- SWI-Prolog 9.2 ou superior no PATH.
- Python 3.12 ou superior, uv, compilador C e cabeçalhos de desenvolvimento para compilar Janus.
- Node.js 20 ou superior, npm e GNU Make. As versões exatas dos pacotes estão nos lockfiles.

**Instalação e execução**

```sh
git clone https://github.com/Pedrovargas10/kakuro-paradigmas.git
cd kakuro-paradigmas
make install
make dev
```

A interface abre em http://localhost:5173 e a API em http://127.0.0.1:8000/docs. O proxy Vite encaminha `/api` ao backend (`frontend/vite.config.js`). Para executar só a API, usar `make install-backend` e `make dev-backend`.

**Testes**

```sh
make test
cd frontend
npm run build
npx --no-install elm-format --validate src/ tests/
cd ..
make validar
```

Com a API já iniciada em outro terminal:

```sh
make test-integration PARTIDAS=10
```

**Testado em** Linux. O ensaio registrado em `docs/ENTREGA_PYTHON.md` usou contêiner Debian trixie, Python 3.13.5, SWI-Prolog 9.2.9 e Node 24.22.3. Os resultados e as limitações dessa execução estão na seção 8. As dependências são instaladas por `uv sync --locked` e `npm ci`, conforme o Makefile.

## 4. Arquitetura

```text
Navegador com Elm → HTTP/JSON → FastAPI em Python → Janus → SWI-Prolog
```

| Parte | Responsabilidade | Arquivos principais |
|---|---|---|
| Prolog | Restrições, busca de soluções, unicidade, geração e dicas | `backend/prolog/kakuro.pl`, `backend/prolog/generator.pl` |
| Elm | Domínio da interface, edição, seleção, feedback local e estado das requisições | `frontend/src/Kakuro.elm`, `frontend/src/Main.elm`, `frontend/src/Api.elm`, `frontend/src/View/` |
| Python | Validação do contrato HTTP, conversões, consultas parametrizadas ao Prolog e respostas de erro | `backend/app/schemas.py`, `backend/app/prolog.py`, `backend/app/main.py` |

As views recebem dados e mensagens. O módulo `Kakuro` concentra funções puras, `Api` trata a comunicação e `Main` coordena as mudanças de estado.

## 5. Parte em Prolog

### 5.1 Predicados principais

| Predicado | Local | O que faz |
|---|---|---|
| `solve(+Puzzle, +Entradas, -Solucao)` | `backend/prolog/kakuro.pl:206` | Encontra uma solução respeitando as entradas |
| `solution_count(+Puzzle, +Entradas, -N)` | `backend/prolog/kakuro.pl:199` | Conta até duas soluções para distinguir ausência, unicidade e ambiguidade |
| `check(+Puzzle, +Entradas, -Estado)` | `backend/prolog/kakuro.pl:225` | Classifica o preenchimento em incomplete, inconsistent ou solved |
| `hint(+Puzzle, +Entradas, -Resultado)` | `backend/prolog/kakuro.pl:239` | Procura uma casa vazia cujo valor não admite alternativa compatível |
| `generate(-Puzzle)` e `generate(+Seed, -Puzzle)` | `backend/prolog/generator.pl:22` | Gera um puzzle único com limite de tempo e semente opcional |

### 5.2 Conceitos do paradigma lógico utilizados

- Unificação e casamento de padrões distinguem bloqueios, casas brancas e pistas em `normalize_cell/2`, `backend/prolog/kakuro.pl:15`.
- A recursão percorre linhas, posições e sequências em `dir_seqs/4` e `white_pos_/3`, nas linhas 60 e 110.
- CLP(FD) define domínio dos dígitos, ausência de repetição e somas em `setup/4` e `post_constraints/2`, nas linhas 129 e 185.
- `labeling/2` realiza a busca depois da montagem das restrições em `solve/3`, linha 206.
- `findnsols/4`, limitado por `once/1`, interrompe a contagem após duas soluções, linha 199.
- A negação em `first_forced/5`, linha 255, verifica a ausência de solução com valor alternativo antes de fornecer uma dica.
- `maplist/2` e `maplist/3` aplicam restrições e conversões às listas. Cortes nas consultas de posição evitam alternativas depois de uma posição encontrada (`lookup/3`, linha 159).

### 5.3 Trecho em destaque

Trecho de `backend/prolog/kakuro.pl:185`:

```prolog
post_constraints([], _).
post_constraints([seq(Clue, Cells)|Seqs], Map) :-
    maplist(lookup_in(Map), Cells, Vars),
    all_distinct(Vars),
    sum(Vars, #=, Clue),
    post_constraints(Seqs, Map).
```

Cada sequência reúne as variáveis das casas associadas à pista. `all_distinct/1` e `sum/3` declaram condições que devem valer simultaneamente. Os cruzamentos compartilham variáveis no mapa de posições. Assim, as restrições de uma direção também reduzem os valores possíveis na outra. A seleção dos valores restantes acontece posteriormente com `labeling/2`.

## 6. Parte em Elm

### 6.1 Modelo e mensagens

Trechos de `frontend/src/Main.elm:24` e `frontend/src/Main.elm:38`:

```elm
type Model
    = Loading
    | LoadFailed Api.Error
    | InGame Game

type Phase
    = Ready Stage
    | Waiting Request Stage
```

`Game` reúne `board`, `selection`, `phase` e `notice`. As mensagens incluem `PressDigit`, `Check`, `AskHint`, `Solve` e as respostas `GotPuzzle`, `GotCheck`, `GotHint` e `GotSolution`. As respostas HTTP usam `Result Api.Error`, permitindo tratar sucesso e falha por casamento de padrões.

`Maybe Editable` representa uma seleção opcional. Os construtores de `Digit`, `Sums` e `Board` ficam encapsulados no módulo `Kakuro`. `digitFromInt` aceita apenas 1 a 9, `sums` exige uma pista positiva e `fromRows` verifica a grade 6×6 (`frontend/src/Kakuro.elm:40`, `:65` e `:135`).

### 6.2 Conceitos do paradigma funcional utilizados

- A Arquitetura Elm reúne `init`, `update`, `subscriptions` e `view` em `frontend/src/Main.elm:14`.
- Custom types e `case` distinguem carregamento, falha, partida e operação em andamento (`Main.elm:24`).
- `Maybe` representa ausência de seleção e dígito. `Result` representa erros de construção do tabuleiro e respostas HTTP (`Kakuro.elm:135`, `Api.elm:124`).
- `List.map`, `Array.map` e aplicação parcial transformam coleções sem mutação (`Kakuro.elm:150`).
- Encoders e decoders centralizam o contrato JSON (`Api.elm:160` e `:219`).
- `Cmd Msg` representa requisições, e `subscriptions` recebe eventos de teclado (`Main.elm:229` e `:324`).
- A atualização de records cria novos estados. `edit`, `reset` e `receive` controlam quando uma alteração é aceita (`Main.elm:176`, `:186` e `:245`).

### 6.3 Trecho em destaque

Trecho de `frontend/src/Kakuro.elm:304`:

```elm
fillIfEmpty : Entry -> Board -> Board
fillIfEmpty entry board =
    if digitAt entry.position board == Nothing then
        setDigit entry.position (Just entry.digit) board

    else
        board
```

`fillIfEmpty` verifica se a posição está vazia antes de chamar `setDigit`. Esta segunda função só altera células `Playable` (`Kakuro.elm:318`). Nos demais casos, o tabuleiro é preservado. `fillEmptyCells` aplica essa função às entradas de uma solução. Isso preserva os números digitados pelo jogador durante dica e resolução. A assinatura e o casamento de padrões explicitam as condições de atualização.

O relato de implementação do PR #57 registra duas refatorações guiadas pelo compilador. Ao trocar `LoadFailed String` por `LoadFailed Api.Error`, o compilador apontou os locais de criação e exibição afetados. Ao renomear o tipo de pistas de `Clue` para `Sums`, listou os usos em `Kakuro`, `Api` e `View.Board`. A versão atual usa `LoadFailed Api.Error` e `Sums`, conforme `Main.elm:26` e `Kakuro.elm:59`. O relato original está em https://github.com/Pedrovargas10/kakuro-paradigmas/pull/57.

## 7. Integração

O Elm se comunica por HTTP/JSON com FastAPI. O Python valida o formato,
converte os dados e consulta o SWI-Prolog pelo Janus com parâmetros vinculados.
As regras do jogo permanecem no Prolog. A opção A acordada na issue #4 usa
`"block"`, `"white"` e pistas como pares numéricos na fronteira Janus;
entradas e soluções são triplas de linha, coluna e valor, com coordenadas desde 0.

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|----------------|---------|-------|------------------|
| `POST /api/generate` | Objeto vazio | Puzzle 6x6 sem solução | `generator:generate/1` |
| `POST /api/check` | Puzzle e entradas | Estado incomplete, inconsistent ou solved | `kakuro:check/3` |
| `POST /api/solve` | Puzzle e entradas | Lista de valores da solução compatível | `kakuro:solve/3` |
| `POST /api/hint` | Puzzle e entradas | Dica ou estado complete, inconsistent, no_forced_hint | `kakuro:hint/3` |

A implementação está em `backend/app/main.py:113`, `backend/app/main.py:143`
e `backend/app/prolog.py:144`. Entrada inválida retorna 422; geração que falha
ou esgota 10 segundos retorna 503; erro interno retorna 500 com mensagem controlada.
O roteiro de Swagger e o teste HTTP estão em `docs/API_PYTHON.md`.

## 8. Testes e validação

A suíte pytest cobre as rotas HTTP, o contrato de tipos, as conversões Janus e os erros 422, 500 e 503. Os fixtures oficiais cobrem preenchimento parcial, solução conhecida, dica, conclusão e entradas incompatíveis. Os testes Prolog exercitam contagem, restrições, geração e dicas; os testes Elm cobrem domínio e codificação JSON.

Na entrega Python das issues #6, #10, #15, #16, #23 e #24, a suíte
`cd backend && uv run --locked pytest` passou 83 testes. Ela cobre contratos
estritos, entradas duplicadas ou em casas não jogáveis, erros 422/500/503,
conversões e integração Janus real. A contagem de soluções é conferida pelo
próprio Prolog. Os dados fixos de teste têm sua origem documentada em
`backend/tests/fixtures/README.md`. Esses resultados não substituem os testes
plunit nem a verificação do frontend.

O comando `uv run --locked python scripts/verificar_api.py --partidas 10`,
contra um servidor `fastapi dev` real, completou dez partidas pelo fluxo
gerar, verificar, resolver, dica e conclusão. Neste ambiente (Python 3.12.3,
SWI-Prolog 10.0.2 e uv 0.8.14), a geração levou em média 1,985 s e no máximo
6,166 s. É uma amostra local, não uma garantia de desempenho em outras máquinas.

Na preparação de Caio para a Fase 3 (PRs #50 e #51, amostra pré-#49), `make test`
passou 83 testes Python e 21 testes Prolog. O verificador ampliado testa entradas
incompatíveis, 422 com mensagem legível, preservação das entradas parciais e
nova resolução válida após rejeições. Dez partidas passaram com geração média
de 1,861 s e máxima de 8,659 s, usando Python 3.12.3, SWI-Prolog 9.2.9,
uv 0.13.9 e Janus 1.5.3. Após a entrada dos PRs #30, #42, #46, #49, #50, #51 e
#52 na `main`, os 21 casos determinísticos de fixtures de `solve`/`hint` (PR #55)
passaram integralmente (104/104 no `pytest` nessa execução), enquanto em
reexecução sobre a `main` `test_generate_with_real_prolog_excludes_solution`
retornou HTTP 503 por esgotamento do gerador Prolog (82/83 no `pytest`) e
`make test-prolog` executou 40 testes sem duplicação (39 passaram e
`generator:varias_geracoes` falhou neste ambiente, conforme #20/#22). Essa medição
é separada da amostra anterior de Pedro. Em 18/11/2026, na revisão `f9da1bf`, os 113 testes Python passaram com
Janus real. O verificador HTTP completou dez partidas, com geração média de
3,374 s e máxima de 7,312 s. Na conferência do navegador houve HTTP 503 no
quinto novo jogo. No ambiente limpo do PR #58, a instalação e a inicialização
passaram e o plunit registrou 39/40, com falha em `generator:varias_geracoes`.
O aceite do fluxo no navegador segue na #29. O validador oficial foi integrado no PR #63 e passou a executar a conferência documental; os apontamentos precisam ser resolvidos antes da entrega.

## 9. Limitações e problemas conhecidos

- A geração pode atingir o limite de dez segundos e retornar HTTP 503. A conferência de navegador registrada na seção 8 apresentou essa falha no quinto novo jogo. O limite protege a requisição, mas exige oferecer uma nova tentativa ao jogador.
- Os resultados históricos de testes e de instalação não comprovam a execução da versão final em qualquer máquina. Os comandos devem ser repetidos na referência escolhida para entrega.
- O aceite de dez jogos consecutivos no navegador continua pendente na issue #29.
- Identificação dos integrantes, responsáveis pela apresentação, material de slides ainda exigem confirmação do grupo.
- A captura real da interface deve ser adicionada antes da entrega.

Como continuidade técnica, a estabilidade e o número de tentativas do gerador podem ser medidos com sementes reproduzíveis e `attempts_average/2` (`backend/prolog/generator.pl:49`), preservando a checagem de unicidade.

## 10. Contribuição de cada integrante

| Integrante | Principais contribuições |
|------------|--------------------------|
| Pedro Vargas (@Pedrovargas10) | Responsável pela infraestrutura do backend, ponte de geração/verificação, rotas generate/check, seus testes e documentação. |
| Caio (@CaioSoandrd) | Modelos compartilhados, ponte e rotas solve/hint (#33/#34), Makefile e alvos do backend (#30/#51), guarda do validador (#46), README/.gitignore (#52), ampliação do verificador HTTP (#50), suíte solve/hint com fixtures (#55), revisão assistida dos PRs Python de Pedro e documentação de integração (#42). Evidências: PRs #30, #33, #34, #42, #46, #50, #51, #52 e #55. |
| [Nome]     | [...] |
| [Nome]     | [...] |
| [Nome]     | [...] |
| [Nome]     | [...] |

## 11. Fontes, código de terceiros e uso de IA

**Código reaproveitado.** A origem do validador de entrega está registrada abaixo. O grupo ainda precisa confirmar se há outros trechos de terceiros a declarar.

O arquivo `scripts/validar_entrega.py` foi copiado integralmente, sem alterações, do [repositório-modelo de Fábio Macêdo Mendes](https://github.com/fabiommendes/paradigmas-trabalho-final/blob/8454eea9bd08b9ef5e3b0538532d18a23174a93c/scripts/validar_entrega.py), no commit `8454eea9bd08b9ef5e3b0538532d18a23174a93c`, para a conferência dos documentos de entrega (issue #9).

**Referências.** A documentação técnica consultada para a integração Python está listada abaixo. Os módulos Prolog usam `library(clpfd)`, e o frontend usa as bibliotecas Elm declaradas em `frontend/elm.json`.

Para a entrega Python: [Janus: chamadas Prolog a partir de Python](https://www.swi-prolog.org/pldoc/man?section=janus-call-prolog),
[FastAPI CLI](https://fastapi.tiangolo.com/fastapi-cli/) e
[uv: lockfile e sincronização](https://docs.astral.sh/uv/concepts/projects/sync/).

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** auxiliar

| Ferramenta | Para que foi usada | Como o grupo verificou o resultado |
|------------|--------------------|------------------------------------|
| Codex (OpenAI) | Utilizada apenas para tirar dúvidas sobre o funcionamento do jogo e para gerar alguns trechos do código que estavam causando bugs, tendo em vista que toda alteração era revisado por mim | Execução de pytest, prolog real e servidor HTTP. |
| Codex (OpenAI), Claude (Anthropic) e Antigravity (Caio — @CaioSoandrd) | Revisão dos PRs #35–#40, apoio em código/ajustes (Makefile, rotas solve/hint e verificação), ampliação do verificador HTTP (#50), suíte de fixtures (#55) e documentação de integração/entrega | Execução local de pytest com Janus real (83 baseline e 104 no PR #55; 82/83 em reteste por 503 do gerador), `make test-prolog` (39/40 pós-#49) e dez partidas HTTP; todas as alterações foram revisadas por Caio antes de cada envio. O ensaio posterior em contêiner limpo e os resultados do fluxo integrado estão na seção 8. |
| Claude Code (Anthropic, modelo Claude Opus 5.5) | Geração e refatoração do frontend Elm (`frontend/src/`: `Kakuro.elm`, `Api.elm`, `Main.elm`, `View/`, `style.css`), dos testes elm-test (`frontend/tests/`), de ajustes de infraestrutura do frontend e da documentação da branch `feat/elm-interface` (issues #17 a #28), sob direção de @vitorfleonardo | `elm make` e `elm-format --validate`; 43 testes elm-test do domínio e da API; verificação dos encoders e decoders contra o backend real; roteiro automatizado no navegador (Edge headless) cobrindo teclado, controles, dica, resolver, 10 puzzles seguidos e queda do backend. Revisão humana do PR pendente. |

## 12. Apresentação oral

- **Slides:** [mesmo caminho indicado na seção 1, ou "não há"]
- **Roteiro:**

| Parte | Duração | Quem apresenta |
|-------|:-------:|----------------|
| Contexto e objetivo | 2 min | [Responsável a confirmar] |
| Demonstração | 5 min | [Responsável a confirmar] |
| Código Prolog | 3 min | [Responsável a confirmar] |
| Código Elm | 3 min | [Responsável a confirmar] |
| Limitações e aprendizados | 2 min | [Responsável a confirmar] |

## 13. Reflexão sobre os paradigmas

A modelagem por restrições concentra as regras de somas e de dígitos distintos no Prolog. O mapa de posições compartilha variáveis entre sequências que se cruzam, permitindo propagação antes da enumeração. Para uma dica, encontrar uma solução candidata é insuficiente: a implementação também verifica se existe uma solução com valor diferente naquela posição. A ausência dessa alternativa fundamenta a revelação de um valor forçado.

No Elm, os estados de carregamento, erro e partida aparecem como alternativas de um tipo, e as respostas HTTP exigem tratar `Ok` e `Err`. O encapsulamento de `Digit` e `Board` concentra validações na construção dos dados. Funções como `fillIfEmpty` deixam explícito que dica e resolução só preenchem casas vazias. O custo dessa organização é escrever conversões e decoders que preservem o contrato com a API.

A integração aproxima duas formas de modelagem: restrições e busca no motor lógico, e transformação imutável de estados na interface. O Python traduz formatos e erros na fronteira entre elas. Os testes com os mesmos fixtures ajudam a detectar divergências de coordenadas, estados e soluções entre os módulos. Os exemplos de refatoração relatados pelo responsável pelo frontend estão registrados na seção 6.3. O grupo deve revisar esta análise e complementar com sua experiência de desenvolvimento.
