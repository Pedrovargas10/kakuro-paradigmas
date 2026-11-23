# Kakuro — Prolog, Python e Elm

## 1. Identificação

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---|---|---|---|
| Pedro Vargas | 231039178 | 16h | @Pedrovargas10 |
| Davi Nobre | 211062929 | 14h | @Jagaima |
| Lucas Machado | 232014093 | 14h | @Lucas-Ricarte |
| Samuel Lobo | 232014191 | 14h | @Samuelvlobo |
| Caio Rocha | 232001371 | 14h | @Dexmachi |
| Caio Soares | 232014638 | 16h | @CaioSoandrd |
| Vitor Feijó | 221008516 | 14h | @vitorfleonardo |

- **Nome do projeto:** Kakuro — Prolog, Python e Elm
- **Nome do grupo:** Equipe kakuro
- **Repositório:** https://github.com/Pedrovargas10/kakuro-paradigmas
- **Commit ou tag entregue:** `f98d0a418c4b77ecb5f0583a892931330bcedf35`
- **Ponto de partida:** outro jogo conhecido
- **Slides da apresentação oral:** não há
A referência acima identifica a base técnica desta revisão documental. O grupo deve atualizá-la para a versão final antes da entrega.

## 2. Resumo

Kakuro é um quebra-cabeça de somas em uma grade 6×6. O jogador preenche as casas com dígitos de 1 a 9, sem repetição dentro de cada sequência, respeitando as pistas horizontais e verticais. O Prolog gera puzzles com solução única, verifica preenchimentos, encontra soluções e identifica dicas forçadas. A interface Elm permite jogar no navegador e usa uma API Python para consultar o motor lógico.

![Interface real do Kakuro com puzzle gerado pelo backend](docs/captura.png)

Captura realizada em 23/11/2026 no navegador integrado do Orca, com a aplicação iniciada por `make dev` e puzzle obtido da API local.

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

<!--
  Os predicados mais importantes, com o local no código. Use a notação
  nome/aridade e indique entradas (+) e saídas (-), como na documentação
  do SWI-Prolog.
-->

| Predicado | Local | O que faz |
|-----------|-------|-----------|
| [`resolver(+Entrada, -Saida)`] | [`arquivo.pl:42`] | [...] |
| [...] | [...] | [...] |

### 5.2 Conceitos do paradigma lógico utilizados

<!--
  Marque o que o projeto usa DE FATO e indique onde. Não é preciso usar
  tudo; é preciso explicar bem o que foi usado.
-->

- [ ] Fatos e regras como base de conhecimento: [onde]
- [ ] Unificação e casamento de padrões: [onde]
- [ ] Recursão (inclusive sobre listas): [onde]
- [ ] Backtracking e múltiplas soluções: [onde]
- [ ] `findall/3`, `bagof/3`, `setof/3` ou similares: [onde]
- [ ] Corte (`!`) ou negação (`\+`), e por que foram necessários: [onde]
- [ ] Programação por restrições (CLP(FD) ou outra): [onde]
- [ ] Predicados de ordem superior (`maplist`, `foldl`, `include`...): [onde]
- [ ] Outro: [...]

### 5.3 Trecho em destaque

<!--
  Escolha o trecho de Prolog de que o grupo mais se orgulha (ou o mais
  difícil). Cole o código e explique como ele funciona: o que é declarado,
  como o Prolog chega à resposta, e por que essa solução é "lógica" e não
  uma tradução de um algoritmo imperativo.
-->

```prolog
[trecho]
```

[Explicação.]

## 6. Parte em Elm

### 6.1 Modelo e mensagens

<!--
  Os tipos centrais do programa: o Model, o tipo Msg e os custom types do
  domínio. Explique as escolhas: por que um custom type e não um Bool, por
  que Maybe ou Result, etc.
-->

```elm
[type alias Model = ...]
[type Msg = ...]
```

[Explicação das escolhas.]

### 6.2 Conceitos do paradigma funcional utilizados

- [ ] Arquitetura Elm (Model, update, view): [onde]
- [ ] Custom types e `case` exaustivo: [onde]
- [ ] `Maybe` e `Result` no lugar de null e exceções: [onde]
- [ ] Funções de ordem superior e aplicação parcial: [onde]
- [ ] Composição (`|>`, `>>`): [onde]
- [ ] Decoders e encoders JSON: [onde]
- [ ] Comandos e subscriptions (efeitos controlados): [onde]
- [ ] Imutabilidade e atualização de records: [onde]
- [ ] Outro: [...]

### 6.3 Trecho em destaque

```elm
[trecho]
```

[Explicação.]

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
- O roteiro de apresentação da seção 12 é uma proposta que o grupo precisa confirmar. Não há arquivo de slides no repositório consultado.

Como continuidade técnica, a estabilidade e o número de tentativas do gerador podem ser medidos com sementes reproduzíveis e `attempts_average/2` (`backend/prolog/generator.pl:49`), preservando a checagem de unicidade.

## 10. Contribuição de cada integrante

| Integrante | Principais contribuições |
|------------|--------------------------|
| Pedro Vargas | Responsável pela infraestrutura do backend, ponte de geração/verificação, rotas generate/check, seus testes e documentação. |
| Caio Soares | Modelos compartilhados, ponte e rotas solve/hint (#33/#34), Makefile e alvos do backend (#30/#51), guarda do validador (#46), README/.gitignore (#52), ampliação do verificador HTTP (#50), suíte solve/hint com fixtures (#55), revisão assistida dos PRs Python de Pedro e documentação de integração (#42). Evidências: PRs #30, #33, #34, #42, #46, #50, #51, #52 e #55. |
| Davi Nobre | [Preenchimento individual pendente] |
| Lucas Machado | [Preenchimento individual pendente] |
| Samuel Lobo | [Preenchimento individual pendente] |
| Caio Rocha | [Preenchimento individual pendente] |
| Vitor Feijó | [Preenchimento individual pendente] |

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

- **Slides:** não há
O roteiro abaixo é uma proposta de distribuição dos 15 minutos, baseada nas contribuições registradas. O grupo deve confirmar os responsáveis antes da apresentação. Os slides estão indicados como inexistentes porque nenhum arquivo foi encontrado no repositório consultado.

- **Roteiro proposto:**

| Parte | Duração | Quem apresenta |
|-------|:-------:|----------------|
| Contexto e objetivo | 2 min | Pedro Vargas |
| Demonstração | 5 min | Caio Soares |
| Código Prolog | 3 min | Davi Nobre, Lucas Machado e Caio Rocha |
| Código Elm | 3 min | Samuel Lobo e Vitor Feijó |
| Limitações e aprendizados | 2 min | Pedro Vargas |

## 13. Reflexão sobre os paradigmas

A modelagem por restrições concentra as regras de somas e de dígitos distintos no Prolog. O mapa de posições compartilha variáveis entre sequências que se cruzam, permitindo propagação antes da enumeração. Para uma dica, encontrar uma solução candidata é insuficiente: a implementação também verifica se existe uma solução com valor diferente naquela posição. A ausência dessa alternativa fundamenta a revelação de um valor forçado.

No Elm, os estados de carregamento, erro e partida aparecem como alternativas de um tipo, e as respostas HTTP exigem tratar `Ok` e `Err`. O encapsulamento de `Digit` e `Board` concentra validações na construção dos dados. Funções como `fillIfEmpty` deixam explícito que dica e resolução só preenchem casas vazias. O custo dessa organização é escrever conversões e decoders que preservem o contrato com a API.

A integração aproxima duas formas de modelagem: restrições e busca no motor lógico, e transformação imutável de estados na interface. O Python traduz formatos e erros na fronteira entre elas. Os testes com os mesmos fixtures ajudam a detectar divergências de coordenadas, estados e soluções entre os módulos. O grupo deve revisar esta análise e complementar com sua experiência de desenvolvimento.
