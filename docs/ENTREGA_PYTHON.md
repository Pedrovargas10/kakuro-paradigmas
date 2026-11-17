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

## Preparação da entrega Python — Fase 4

Este checklist prepara a parte Python de Caio (#11) e a documentação de execução
(#5). O congelamento coletivo depende do aceite da Fase 3 (#28/#29).

### Evidências disponíveis

| Conferência | Evidência | Limite |
|---|---|---|
| Dependências | `make install-backend` com lockfile | Ambiente local, não instalação limpa |
| Testes | 83 pytest e 21 plunit passaram | plunit executa duas vezes (#13) |
| HTTP | Dez partidas; média 1,861 s, máximo 8,659 s | Amostra local, não garantia de desempenho |
| Erros e preservação | Verificador ampliado no commit `b07cd4d` do PR #42 | Não testa o estado do navegador |
| Execução | `/docs` respondeu 200 com polling | Monitor nativo atingiu limite de arquivos |

Ambiente das evidências: Python 3.12.3, SWI-Prolog 9.2.9, Node 24.21.0,
uv 0.13.9 e Janus 1.5.3. Repetir as verificações no commit final.

### Antes de congelar

- [ ] Integrar os PRs #30 e #42 e revisar a documentação contra a main final.
- [ ] Usar os fixtures compartilhados quando #14 estiver concluída.
- [ ] Revalidar Python após as correções Prolog #12/#13/#21.
- [ ] Concluir o teste visual #29 com a equipe Elm.
- [ ] Conferir contribuições, fontes e uso de IA com o grupo no relatório.
- [ ] Obter o validador oficial (#9), sem reimplementá-lo ou modificar seu conteúdo.
- [ ] Executar `make validar` com o arquivo oficial e corrigir os erros documentais.

### Revisão e entrega (Fase 5)

- [ ] Testar instalação em máquina limpa seguindo apenas o README.
- [ ] Executar testes, build e formatação Elm e verificador documental.
- [ ] Registrar o commit/tag final e capturas reais no relatório.
- [ ] Preencher a avaliação 360 individual com dados do próprio integrante.

Nenhum item pendente deve ser marcado apenas porque os testes Python passaram.
