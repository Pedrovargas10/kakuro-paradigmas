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
|-----------|-------|-----------|
| `solution_count(+Puzzle, +Entradas, -N)` | [`backend/prolog/kakuro.pl:199`](backend/prolog/kakuro.pl#L199) | Conta soluções até o limite de 2 (`N` em `{0, 1, 2}`) usando `findnsols/4`, evitando enumerar todas as soluções |
| `solve(+Puzzle, +Entradas, -Solucao)` | [`backend/prolog/kakuro.pl:206`](backend/prolog/kakuro.pl#L206) | Monta as restrições CLP(FD) respeitando `Entradas` e resolve com `labeling([ff], AllVars)`; falha se não houver solução |
| `check(+Puzzle, +Entradas, -Estado)` | [`backend/prolog/kakuro.pl:225`](backend/prolog/kakuro.pl#L225) | Verifica se as entradas cobrem todas as casas brancas e se há solução compatível, devolvendo `"solved"`, `"incomplete"` ou `"inconsistent"` |
| `hint(+Puzzle, +Entradas, -Resultado)` | [`backend/prolog/kakuro.pl:239`](backend/prolog/kakuro.pl#L239) | Devolve `["hint", L, C, V]` apenas para casa vazia sem solução alternativa; trata `"complete"`, `"inconsistent"` e `"no_forced_hint"` |
| `setup(+Puzzle, +Entradas, -VarMap, -AllVars)` | [`backend/prolog/kakuro.pl:129`](backend/prolog/kakuro.pl#L129) | Normaliza e valida a grade 6×6, cria uma variável FD (`1..9`) por casa branca, aplica entradas e posta as restrições de cada sequência |
| `generate(-Puzzle)` / `generate(+Seed, -Puzzle)` | [`backend/prolog/generator.pl:22`](backend/prolog/generator.pl#L22) | Gera um puzzle 6×6 aleatório (ou determinístico via `Seed`) com solução única verificada por `solution_count/3`, com limite de 10 s |
| `generate_with_solution(-Puzzle, -Solution)` | [`backend/prolog/generator.pl:29`](backend/prolog/generator.pl#L29) | Gera o puzzle 6×6 junto com a lista de respostas `[Linha, Coluna, Valor]` |

### 5.2 Conceitos do paradigma lógico utilizados

- [x] Unificação e casamento de padrões: conversão de células em `normalize_cell/2` (`backend/prolog/kakuro.pl:15-24`), extração de pistas direcionais em `clue_value/3` e `make_pos/4` (`backend/prolog/kakuro.pl:94-98`) e montagem das células em `puzzle_cell/4` (`backend/prolog/generator.pl:174-176`).
- [x] Recursão (inclusive sobre listas): varredura de linhas e colunas em `dir_seqs/4`, `line_seqs/5` e `collect_whites/7` (`backend/prolog/kakuro.pl:60-92`), aplicação das entradas em `apply_entries/3` (`backend/prolog/kakuro.pl:169-183`) e rotulagem aleatória em `random_bits/1` e `random_labeling/1` (`backend/prolog/generator.pl:88-92`, `141-146`).
- [x] Backtracking e múltiplas soluções: busca de soluções em `solve/3` (`backend/prolog/kakuro.pl:206-209`), tentativa de novas máscaras e preenchimentos via `repeat` e `between(1, 20, _)` em `try_generate/2` (`backend/prolog/generator.pl:35-46`) e teste de alternativa em `alternative_exists/5` (`backend/prolog/kakuro.pl:263-266`).
- [x] `findall/3`, `bagof/3`, `setof/3` ou similares: `findnsols/4` em `solution_count/3` (`backend/prolog/kakuro.pl:200`) para interromper a busca na segunda solução; `findall/3` em `seq_positions/2` (`backend/prolog/kakuro.pl:152-153`) e `grid_solution/2` (`backend/prolog/generator.pl:178-183`).
- [x] Corte (`!`) ou negação (`\+`), e por que foram necessários: corte `!` em `normalize_cell/2`, `lookup/3` e `try_generate/2` (`backend/prolog/generator.pl:46`) para tornar determinísticas a normalização/busca em mapa e encerrar o `repeat` ao obter solução única; negação por falha `\+` em `first_forced/5` (`backend/prolog/kakuro.pl:256-257`) para aceitar uma dica apenas quando não existe solução com outro valor naquela casa.
- [x] Programação por restrições (CLP(FD) ou outra): `library(clpfd)` em `setup/4` e `post_constraints/2` (`backend/prolog/kakuro.pl:129-138`, `185-190`) com `ins 1..9`, `all_distinct/1`, `sum/3`, `#=` e `#\=`; e no gerador (`backend/prolog/generator.pl:67-85`, `127-129`) para garantir 8 a 12 casas brancas sem células isoladas.
- [x] Predicados de ordem superior (`maplist`, `foldl`, `include`...): `maplist` em `normalize_puzzle/2` (`backend/prolog/kakuro.pl:30`), `transp/2` (`backend/prolog/kakuro.pl:40`), `post_constraints/2` (`backend/prolog/kakuro.pl:187`), `grid_clues/2` (`backend/prolog/generator.pl:159-163`) e `attempts_average/2` (`backend/prolog/generator.pl:51`).

### 5.3 Trecho em destaque

```prolog
% backend/prolog/kakuro.pl:129-138 e 185-190
setup(Puzzle, Entradas, VarMap, AllVars) :-
    normalize_puzzle(Puzzle, NPuzzle),
    white_positions(NPuzzle, Positions),
    sequences(NPuzzle, HSeqs, VSeqs),
    validate_white_coverage(Positions, HSeqs, VSeqs),
    append(HSeqs, VSeqs, Seqs),
    make_varmap(Positions, VarMap, AllVars),
    AllVars ins 1..9,
    apply_entries(Entradas, VarMap),
    post_constraints(Seqs, VarMap).

post_constraints([], _).
post_constraints([seq(Clue, Cells)|Seqs], Map) :-
    maplist(lookup_in(Map), Cells, Vars),
    all_distinct(Vars),
    sum(Vars, #=, Clue),
    post_constraints(Seqs, Map).
```

Em vez de implementar um algoritmo passo a passo (com laços testando números e desfazendo jogadas manualmente), o trecho acima declara **o que** precisa ser verdadeiro para que um tabuleiro seja um Kakuro válido:

1. **Preparação e validação (`setup/4`):** `normalize_puzzle/2` converte as células recebidas para o formato interno e valida a grade 6×6. Em seguida, `white_positions/2` lista todas as coordenadas brancas, `sequences/3` agrupa as casas de cada pista horizontal e vertical, e `validate_white_coverage/3` garante que nenhuma casa branca fique isolada sem pertencer às duas direções.
2. **Caixas vazias e compartilhamento nos cruzamentos (`make_varmap/3`):** para cada coordenada `pos(L, C)`, o Prolog cria uma variável lógica ainda sem número e guarda o par `pos(L, C)-Var` em `VarMap`. Com `AllVars ins 1..9`, todas recebem o domínio de 1 a 9, e `apply_entries/2` fixa os dígitos já preenchidos pelo jogador (`Var #= Val`).
3. **Regras por sequência (`post_constraints/2`):** para cada sequência `seq(Clue, Cells)`, `maplist(lookup_in(Map), Cells, Vars)` troca as coordenadas pelas suas variáveis em `VarMap`. Como uma casa no cruzamento aparece tanto em uma sequência horizontal quanto em uma vertical, **a mesma variável lógica participa das duas listas** — qualquer redução de possibilidades em uma linha reflete imediatamente na coluna, sem cópia de dados. Em seguida, `all_distinct(Vars)` proíbe dígitos repetidos na sequência e `sum(Vars, #=, Clue)` exige que a soma seja igual à pista.
4. **Propagação antes da busca:** ao declarar essas restrições, o motor CLP(FD) já elimina valores impossíveis dos domínios antes mesmo de testar qualquer chute. Só depois disso predicados como `solve/3` e `check/3` chamam `labeling([ff], AllVars)`, que escolhe primeiro a variável com menos opções restantes (*first-fail*) e usa *backtracking* caso algum caminho leve a contradição.
5. **Dica sem chutes (`hint/3`):** seguindo a mesma lógica declarativa (`backend/prolog/kakuro.pl:239-266`), o sistema encontra uma solução candidata e, para cada casa vazia com valor `V`, testa se ainda existe solução com `X #\= V`. Se essa alternativa falhar, o valor é logicamente forçado e pode ser revelado ao jogador.

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

O Python conecta a interface Elm ao motor Prolog. Ele recebe o tabuleiro e os números preenchidos pelo jogador, valida os dados e consulta o Prolog por meio do Janus. A resposta volta ao Elm para atualizar a tela.

| Rota | Corpo da requisição | Resposta HTTP 200 | Consulta Prolog |
|---|---|---|---|
| `/api/generate` | `{}` | Objeto `puzzle` com a grade, sem os dígitos da solução | `generator:generate/1` |
| `/api/check` | Objeto `puzzle` e lista `entries` | Campo `state` com incomplete, inconsistent ou solved | `kakuro:check/3` |
| `/api/solve` | Objeto `puzzle` e lista `entries` | Campo `solution` com todas as casas resolvidas, respeitando as entradas | `kakuro:solve/3` |
| `/api/hint` | Objeto `puzzle` e lista `entries` | Campos `kind`, `row`, `col`, `value` para uma dica, ou `kind` com complete, inconsistent ou no_forced_hint | `kakuro:hint/3` |

As rotas estão em `backend/app/main.py` e a comunicação com o Prolog em `backend/app/prolog.py`. O Prolog decide as regras, as soluções e as dicas. O Python adapta os dados e devolve mensagens de erro quando necessário, inclusive se a geração ultrapassar o limite de dez segundos. Dica e resolução preservam os números já preenchidos pelo jogador.

A integração é conferida pelos testes da API e pelo comando `make test-integration PARTIDAS=10`. O roteiro e os exemplos de uso estão em `docs/API_PYTHON.md`; os resultados estão na seção 8.

## 8. Testes e validação

A validação do projeto combina testes automatizados com conferências da aplicação em funcionamento. Foram usados puzzles fixos com solução conhecida para verificar se o sistema reconhece uma partida incompleta, identifica um preenchimento incompatível e aceita uma solução correta. Também foram testadas a preservação dos números digitados pelo jogador e a aplicação da dica na casa vazia correta.

Na parte Python, os testes verificam as quatro operações da API e sua comunicação real com o Prolog. Foram considerados casos como valores fora de 1 a 9, posições repetidas e tentativas de preencher casas de pista ou bloqueio. Na execução registrada em 18/11/2026, os 113 testes Python passaram. Os testes Prolog verificam as regras, as soluções e a geração dos puzzles. No Elm, os testes cobrem as operações do tabuleiro e a leitura e escrita dos dados trocados com a API.

A comunicação entre as partes também foi exercitada em dez partidas consecutivas, passando por geração, verificação, dica, resolução e conclusão. Nessa amostra, a geração levou em média 3,374 segundos e no máximo 7,312 segundos. A instalação e a inicialização foram conferidas em um ambiente Linux limpo. Nesse ambiente, 39 dos 40 testes Prolog passaram, com uma falha no teste de várias gerações seguidas.

A conferência no navegador incluiu dica, resolução e recuperação após falha de comunicação. Houve uma falha de geração no quinto novo jogo, quando o tempo limite foi atingido. Por isso, a estabilidade do gerador ainda precisa de acompanhamento e o fluxo completo deve ser repetido na versão final.

O relatório é conferido pelo validador oficial do professor. Ele identifica campos pendentes, problemas de formatação e referências a arquivos inexistentes. As seções de Prolog e Elm e as contribuições individuais continuam aguardando preenchimento pelos respectivos responsáveis antes da validação final da entrega.

## 9. Limitações e problemas conhecidos

- A geração pode atingir o limite de dez segundos e retornar HTTP 503. A conferência de navegador registrada na seção 8 apresentou essa falha no quinto novo jogo. O limite protege a requisição, mas exige oferecer uma nova tentativa ao jogador.

Como continuidade técnica, a estabilidade e o número de tentativas do gerador podem ser medidos com sementes reproduzíveis e `attempts_average/2` (`backend/prolog/generator.pl:49`), preservando a checagem de unicidade.

## 10. Contribuição de cada integrante

| Integrante | Principais contribuições |
|------------|--------------------------|
| Pedro Vargas | Responsável pela infraestrutura do backend, ponte de geração/verificação, rotas generate/check, seus testes e documentação. |
| Caio Soares | Modelos compartilhados, ponte e rotas solve/hint (#33/#34), Makefile e alvos do backend (#30/#51), guarda do validador (#46), README/.gitignore (#52), ampliação do verificador HTTP (#50), suíte solve/hint com fixtures (#55), revisão assistida dos PRs Python de Pedro e documentação de integração (#42). Evidências: PRs #30, #33, #34, #42, #46, #50, #51, #52 e #55. |
| Davi Nobre | Implementação inicial do motor lógico em `backend/prolog/kakuro.pl` (normalização, extração de sequências, restrições CLP(FD), `solution_count/3`, `solve/3`, `check/3`, `hint/3`), criação da suíte inicial de testes `plunit` em `backend/prolog/test_kakuro.pl`, criação dos puzzles de referência em `docs/fixtures/` (JSON e Prolog) e correções do PR #49 (cobertura das entradas em `check/3` e `hint/3`, busca limitada com `findnsols/4` e busca de alternativa em `hint/3`). |
| Lucas Machado | [Preenchimento individual pendente] |
| Samuel Lobo | [Preenchimento individual pendente] |
| Caio Rocha (@Dexmachi) | Validações estruturais do puzzle e das entradas em `backend/prolog/kakuro.pl`, otimização de `hint/3`, unificação da extração de sequências horizontais e verticais, adição de testes `plunit` em `backend/prolog/test_kakuro.pl`. |
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
| Codex (OpenAI), Claude (Anthropic) e Antigravity (Caio Soares — @CaioSoandrd) | Apoio na escrita e nos ajustes da minha parte do backend Python (modelos compartilhados em `schemas.py`, ponte com o Prolog e rotas `/api/solve` e `/api/hint`), na criação e correção do `Makefile` (como o encerramento dos processos no `make dev`), na escrita de testes com os fixtures compartilhados e na revisão de PRs, contratos da API e documentação (`README.md` e relatório). | Li e revisei todas as alterações antes de commitar ou abrir os PRs, rodando localmente os testes `pytest` com o Prolog/Janus real, os testes `plunit` e o servidor FastAPI via `/docs` e pelo verificador HTTP para conferir se o comportamento batia com o contrato combinado pelo grupo. |
| Claude Code (Anthropic, modelo Claude Opus 5.5) | Geração e refatoração do frontend Elm (`frontend/src/`: `Kakuro.elm`, `Api.elm`, `Main.elm`, `View/`, `style.css`), dos testes elm-test (`frontend/tests/`), de ajustes de infraestrutura do frontend e da documentação da branch `feat/elm-interface` (issues #17 a #28), sob direção de @vitorfleonardo | `elm make` e `elm-format --validate`; 43 testes elm-test do domínio e da API; verificação dos encoders e decoders contra o backend real; roteiro automatizado no navegador (Edge headless) cobrindo teclado, controles, dica, resolver, 10 puzzles seguidos e queda do backend. Revisão humana do PR pendente. |
| Antigravity Gemini 4 (Caio Rocha @Dexmachi) | Ajuda na análise de código presente no repositório, suporte ao implementar testes automatizados para o elm, e ajuda em análise do estado atual de issues e PRs no repositório (para identificar quais issues ainda estavam realmente abertas) | `make test` e testes rodados manualmente 1 por 1; verificação, correção e leitura manual de código.
| DeepSeek v4.1 Flash e Gemini Hydrogen (Davi Nobre @Jagaima) | DeepSeek v4.1 Flash utilizado para auxiliar na escrita de trechos de código em `backend/prolog/kakuro.pl`; Gemini Hydrogen utilizado para auxiliar na escrita dos testes `plunit` (`backend/prolog/test_kakuro.pl`) e dos puzzles manuais de referência para testagem (`docs/fixtures/`). | Execução da suíte `plunit` (`swipl -g run_tests -t halt test_kakuro.pl`, 40 testes), execução da suíte Python via WSL com Janus real (`uv run pytest`, 83 testes) e revisão manual dos puzzles e restrições. |

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

---

### Checklist antes da entrega

- [ ] Executar `make validar` e corrigir todos os erros apontados.
- [ ] Conferir os nomes, matrículas, turmas e usuários GitHub dos sete integrantes na seção 1.
- [ ] Atualizar o commit ou tag da seção 1 para a versão final que será enviada.
- [ ] Repetir as instruções da seção 3 em uma máquina limpa.
- [ ] Completar as seções 5 e 6 com os responsáveis por Prolog e Elm.
- [ ] Conferir as referências de arquivos e linhas contra a versão final.
- [ ] Cada integrante preencher e confirmar sua contribuição na seção 10.
- [ ] Revisar as fontes, o código de terceiros e as declarações da seção 11 com todo o grupo.
- [ ] Confirmar o roteiro da apresentação e os responsáveis da seção 12.
- [ ] Conferir a indicação de slides nas seções 1 e 12 e incluir o arquivo ou link se forem utilizados.
- [ ] Cada integrante enviar sua avaliação 360 na atividade individual do Codehood.
- [ ] Conferir que todos os campos do modelo foram preenchidos e que os comentários de instrução foram removidos.
- [ ] Enviar a versão final da main ao Codehood e conferir o commit e o horário registrados na página da entrega.
