# Preparação da entrega Python — Fase 4

Este checklist prepara a parte Python de Caio (#11) e a documentação de execução
(#5). O congelamento coletivo depende do aceite da Fase 3 (#28/#29).

## Evidências disponíveis

| Conferência | Evidência | Limite |
|---|---|---|
| Dependências | `make install-backend` com lockfile | Ambiente local, não instalação limpa |
| Testes | 83 pytest e 21 plunit passaram | plunit executa duas vezes (#13) |
| HTTP | Dez partidas; média 1,861 s, máximo 8,659 s | Amostra local, não garantia de desempenho |
| Erros e preservação | Verificador ampliado no commit `b07cd4d` do PR #42 | Não testa o estado do navegador |
| Execução | `/docs` respondeu 200 com polling | Monitor nativo atingiu limite de arquivos |

Ambiente das evidências: Python 3.12.3, SWI-Prolog 9.2.9, Node 24.21.0,
uv 0.13.9 e Janus 1.5.3. Repetir as verificações no commit final.

## Antes de congelar

- [ ] Integrar os PRs #30 e #42 e revisar a documentação contra a main final.
- [ ] Usar os fixtures compartilhados quando #14 estiver concluída.
- [ ] Revalidar Python após as correções Prolog #12/#13/#21.
- [ ] Concluir o teste visual #29 com a equipe Elm.
- [ ] Conferir contribuições, fontes e uso de IA com o grupo no relatório.
- [ ] Obter o validador oficial (#9), sem reimplementá-lo ou modificar seu conteúdo.
- [ ] Executar `make validar` com o arquivo oficial e corrigir os erros documentais.

## Revisão e entrega (Fase 5)

- [ ] Testar instalação em máquina limpa seguindo apenas o README.
- [ ] Executar testes, build e formatação Elm e verificador documental.
- [ ] Registrar o commit/tag final e capturas reais no relatório.
- [ ] Preencher a avaliação 360 individual com dados do próprio integrante.

Nenhum item pendente deve ser marcado apenas porque os testes Python passaram.
