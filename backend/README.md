# Backend Python

Requer Python 3.12+, uv, SWI-Prolog 9.2+ e um compilador C com os cabeçalhos
de desenvolvimento do Python e do SWI-Prolog disponíveis. O Janus é compilado
contra a instalação local do SWI-Prolog para evitar incompatibilidade de bibliotecas.

Dentro de `backend/`:

```sh
uv sync --locked
uv run python -c "import janus_swi"
uv run fastapi dev app/main.py
```

A documentação interativa fica em <http://127.0.0.1:8000/docs> e o contrato em
<http://127.0.0.1:8000/openapi.json>. A inicialização carrega `kakuro.pl` e
`generator.pl`; arquivos ausentes ou erros de carregamento impedem a inicialização.

Para executar os testes:

```sh
uv run --locked pytest
```

O `uv.lock` deve ser versionado. `.venv/` e caches de execução são ignorados.
Os comandos acima são independentes do Makefile e do frontend.
