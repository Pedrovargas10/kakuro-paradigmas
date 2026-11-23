# Kakuro — Prolog, Python e Elm

Jogo de Kakuro 6×6: o Prolog gera, verifica e resolve puzzles; o Python expõe
uma API FastAPI; o Elm é responsável pela interface no navegador.

## Estado desta entrega

A API Python pode ser executada e testada separadamente. A interface Elm
(issues #17 a #28) gera, edita, verifica, dá dica e resolve pelo navegador,
com teclado, bloqueio durante requisições e recuperação de falhas de rede.

## Pré-requisitos

- Python 3.12 ou superior e uv.
- SWI-Prolog 9.2 ou superior, disponível como `swipl` no PATH.
- Compilador C e cabeçalhos de desenvolvimento Python/SWI-Prolog para o Janus.
- Node 20.19+ na série 20, 22.13+ na série 22 ou Node 24 LTS, com npm.
- GNU Make para os comandos da raiz.

Verifique `python3 --version`, `uv --version`, `swipl --version`,
`node --version` e `npm --version`. O compilador Elm e o `elm-format` são
instalados pelo npm em `frontend/node_modules`, sem instalação global.

## Executar a API

```sh
make install-backend
make dev-backend
```

API: http://127.0.0.1:8000; documentação interativa:
http://127.0.0.1:8000/docs. Todas as rotas de jogo são POST sob `/api`.
O contrato e exemplos estão em [docs/API_PYTHON.md](docs/API_PYTHON.md).

Se WatchFiles falhar com `Too many open files`, use:

```sh
WATCHFILES_FORCE_POLLING=true make dev-backend
```

## Testar

```sh
make test
```

Os alvos `make test-prolog`, `make test-backend` e `make test-frontend` também
podem ser usados separadamente. Os testes Elm (`frontend/tests/`, com elm-test)
também rodam com `cd frontend && npm test`. Com o backend iniciado em outro terminal:

```sh
make test-integration
# Outra porta ou quantidade de partidas:
make test-integration API_URL=http://127.0.0.1:8001 PARTIDAS=2
```

O verificador retorna erro se alguma condição falhar. Ele não substitui os
testes de teclado, controles e falha de rede no navegador.

## Executar o sistema completo

```sh
make install
make dev
```

A instalação usa `backend/uv.lock` e `frontend/package-lock.json`. Se o monitor de arquivos atingir o limite do sistema (`EMFILE` ou `Too many open files`), inicie os dois serviços com `WATCHFILES_FORCE_POLLING=true CHOKIDAR_USEPOLLING=true make dev`.

Abra http://localhost:5173. O Vite encaminha `/api` ao backend em
`127.0.0.1:8000`. `Ctrl+C` em `make dev` encerra os dois processos. Para testar
queda da API mantendo a interface aberta, inicie cada serviço em um terminal
separado.

No Windows, o `make dev` não funciona (usa `setpgid`, só de Unix). Rode o
backend no WSL e o frontend no Windows, em dois terminais:

```sh
# Terminal 1 (WSL, na raiz do repositório em /mnt/c/...)
WATCHFILES_FORCE_POLLING=true make dev-backend

# Terminal 2 (PowerShell, em frontend/)
npm ci
npm run dev -- --port 5173
```

Conferências do frontend:

```sh
cd frontend
npm run build
npx --no-install elm-format --validate src/
```

## Estrutura e entrega

- `backend/prolog/`: motor lógico, gerador e testes plunit.
- `backend/app/`: schemas, ponte Janus e rotas FastAPI.
- `backend/tests/`: testes Python e fixture temporário identificado.
- `backend/scripts/`: verificação por HTTP real.
- `frontend/src/`: aplicação Elm. `Kakuro.elm` é o domínio puro, `Api.elm`
  a fronteira HTTP/JSON, `View/` as telas e `Main.elm` o estado e os eventos.
- `docs/`: contrato da API e documentação de integração.
- `RELATORIO.md`: relatório coletivo, ainda com seções pendentes.

`make validar` executa o validador oficial em `scripts/validar_entrega.py` (issue #9).
Ele lista os campos e problemas de formato ainda pendentes nos documentos.
A origem do script está registrada na seção 11 do relatório.
