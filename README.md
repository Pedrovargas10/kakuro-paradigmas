# Kakuro — Prolog, Python e Elm

Jogo de Kakuro 6×6: o Prolog gera, verifica e resolve puzzles; o Python expõe
uma API FastAPI; o Elm é responsável pela interface no navegador.

## Estado desta entrega

A API Python pode ser executada e testada separadamente. A interface Elm ainda
aguarda implementação e integração; os comandos completos abaixo dependem dela.
A preparação da integração está no PR #42. Consulte as issues #28/#29 para o
aceite no navegador e [o plano da Fase 3](PLANO_FASE3.md) para as dependências.

## Pré-requisitos

- Python 3.12 ou superior e uv.
- SWI-Prolog 9.2 ou superior, disponível como `swipl` no PATH.
- Compilador C e cabeçalhos de desenvolvimento Python/SWI-Prolog para o Janus.
- Node 20 ou superior e npm para o frontend; GNU Make para os comandos da raiz.

Verifique `python3 --version`, `uv --version`, `swipl --version`,
`node --version` e `npm --version`. O compilador Elm será instalado pelo npm
quando a infraestrutura do frontend estiver pronta.

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

Os alvos `make test-prolog` e `make test-backend` também podem ser usados
separadamente. Com o backend iniciado em outro terminal:

```sh
make test-integration
# Outra porta ou quantidade de partidas:
make test-integration API_URL=http://127.0.0.1:8001 PARTIDAS=2
```

O verificador retorna erro se alguma condição falhar. Ele não substitui os
testes de teclado, controles e falha de rede no navegador.

## Executar o sistema completo (após entrega do frontend)

```sh
make install
make dev
```

O frontend usa http://localhost:5173 e deve encaminhar `/api` ao backend na
porta 8000. `Ctrl+C` em `make dev` encerra os dois processos. Para testar queda
da API mantendo a interface aberta, inicie cada serviço em um terminal separado.

```sh
cd frontend
npm run build
npx --no-install elm-format --validate src/
```

Esses comandos frontend ainda não são critérios validados nesta entrega.

## Estrutura e entrega

- `backend/prolog/`: motor lógico, gerador e testes plunit.
- `backend/app/`: schemas, ponte Janus e rotas FastAPI.
- `backend/tests/`: testes Python e fixture temporário identificado.
- `backend/scripts/`: verificação por HTTP real.
- `frontend/`: aplicação Elm, pendente da equipe responsável.
- `docs/`: contrato da API e documentação de integração.
- `RELATORIO.md`: relatório coletivo, ainda com seções pendentes.

`make validar` depende do arquivo oficial do professor na issue #9. O arquivo
atual está vazio; a entrega documental não pode ser considerada validada.
