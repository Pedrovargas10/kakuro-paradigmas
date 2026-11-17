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

## Pendências coletivas

- Testar o fluxo no navegador, teclado, controles e falha de rede (#28/#29).
- Conferir a validação estrutural restante no Prolog (#12).
- Obter o validador oficial sem reimplementá-lo e executar `make validar` (#9).
- Repetir instalação e testes em uma máquina limpa antes da entrega.
- Preencher relatório, referências, contribuições e avaliação 360 com o grupo.

A documentação desta página cobre a API; não marca os critérios coletivos
como concluídos.
