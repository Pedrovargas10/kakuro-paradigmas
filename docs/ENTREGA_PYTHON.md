# Conferência da integração Python

Os comandos abaixo são executados na raiz, com SWI-Prolog disponível no PATH.

## API e testes

1. Executar `make install-backend`.
2. Executar `make test-backend` e `make test-prolog`.
3. Iniciar a API com `make dev-backend` e abrir `/docs` na porta 8000.
4. Em outro terminal, executar `make test-integration PARTIDAS=10`.
5. Registrar o commit testado, o resultado e os tempos informados pelo comando.

Os fixtures de referência estão em `docs/fixtures/`. Cada `puzzle_XX.json`
contém a matriz de células, e `puzzle_XX_solution.json` contém a lista de
entradas da solução. A API recebe a matriz dentro de `puzzle.cells`.

O verificador HTTP confere respostas, entradas inválidas, preservação do
preenchimento parcial e recuperação após rejeições. Um resultado positivo
não comprova o funcionamento da interface Elm nem garante que qualquer
chamada futura ao gerador terminará dentro do limite de tempo.

## Aceite por fase em 18/11/2026

A API, o navegador e os fixtures foram conferidos na base `f9da1bf`.
Para a instalação em ambiente limpo, a revisão `765a750` do PR #58 usa os
lockfiles dessa mesma base.

| Fase | Evidência da integração Python | Pendência |
|---|---|---|
| 0 · Preparação | Em um contêiner Debian trixie com Python 3.13.5, SWI-Prolog 9.2.9 e Node 24.22.3, `make install` compilou o Janus. Com `make dev`, o frontend encaminhou o puzzle 01 para a API e recebeu `incomplete`. | A aprovação coletiva do contrato segue na #3. |
| 1 · Base | A ponte e as rotas de verificação e solução foram exercitadas com os puzzles de `docs/fixtures`, inclusive com preenchimento parcial. | A validação estrutural de tabuleiros recebidos continua no escopo do motor (#12). |
| 2 · Funcionalidades | Na base conferida, os 113 testes Python passaram com Janus real, incluindo os resultados de dica, preservação de entradas e erros 422/503. | Na execução de `make test` no contêiner, 39 de 40 testes Prolog passaram. A falha foi em `generator:varias_geracoes` (#20/#22). |
| 3 · Integração | O verificador HTTP completou dez partidas na máquina local. A geração levou em média 3,374 s e no máximo 7,312 s. No navegador, a conferência do PR #57 exercitou dica, solução e recuperação após falha de comunicação. | Na amostra do navegador, o quinto novo jogo retornou 503. Repetir as dez partidas consecutivas no navegador para o aceite da #29. |
| 4 · Congelamento | Os testes com fixtures dos PRs #53 e #55 e o frontend dos PRs #54 e #57 estão integrados. As contribuições Python estão no relatório. | Obter o script oficial do professor (#9), executar `make validar` e tratar as pendências que ele apontar. |
| 5 · Entrega | O PR #58 registra o ensaio de instalação e inicialização em ambiente limpo. | Repetir os comandos no commit final, registrar a referência de entrega e concluir a avaliação 360 individual. |

A issue #11 acompanha o aceite dos alvos da #8. O script oficial em
`scripts/validar_entrega.py` continua vazio na base conferida.
