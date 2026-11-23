# Conferência do fluxo completo do Kakuro

Conferência realizada em 23/11/2026 sobre a main `4e65ea46691be5f144cedcdc226d4b491c670e67`, com frontend e backend locais. As chamadas da página passaram pelo proxy Vite para o FastAPI e o Prolog real. O acompanhamento das requisições registrou os corpos e respostas HTTP reais.

## Resultados

| Caso | Resultado observado |
|---|---|
| Dez gerações consecutivas pelo botão Novo jogo | Todas retornaram HTTP 200 e mostraram puzzles 6×6 |
| Teclado | Dígitos 1 a 9, quatro setas, Backspace e Delete funcionaram |
| Reiniciar | Limpou as entradas e preservou pistas e bloqueios |
| Casas de pista e bloqueio | Cliques não selecionaram essas casas para edição nem alteraram suas pistas |
| Requisição pendente | Controles de edição, verificação, dica, solução, reinício e novo jogo ficaram bloqueados |
| Fluxo da partida | Preencher um valor correto, verificar, obter dica e resolver preservou os valores existentes |
| Conclusão | Resolver mostrou a solução completa e mensagem de conclusão; preenchimento completo seguido de Verificar retornou solved e mostrou a confirmação |
| Backend desligado | A mensagem orientou conferir o servidor, preservou o preenchimento e apresentou Tentar de novo |
| Backend religado | Tentar de novo retornou HTTP 200 com incomplete, mantendo o mesmo puzzle e as entradas, sem recarregar a página |

## Gerações na interface

| Geração | Status HTTP | Tempo em segundos |
|---|---|---|
| 1 | 200 | 0.116 |
| 2 | 200 | 1.605 |
| 3 | 200 | 0.302 |
| 4 | 200 | 1.131 |
| 5 | 200 | 0.839 |
| 6 | 200 | 0.200 |
| 7 | 200 | 1.549 |
| 8 | 200 | 1.203 |
| 9 | 200 | 2.599 |
| 10 | 200 | 4.034 |

Média de 1.358 s e máximo de 4.034 s nesta amostra.

## Como repetir a conferência

1. Iniciar o backend na porta 8000 e o frontend na porta 5173 usando os comandos documentados no README.
2. Abrir a interface e acionar Novo jogo dez vezes, aguardando a conclusão de cada geração. Conferir as respostas na aba de rede do navegador.
3. Em uma casa jogável, testar os dígitos, as setas e as teclas de apagar. Clicar também em pistas e bloqueios, verificando que não permitem preenchimento.
4. Reiniciar e conferir que somente os números digitados foram apagados.
5. Pedir uma dica, redigitar o valor correto com o teclado, verificar o preenchimento parcial, pedir outra dica e resolver. Conferir que os valores existentes foram preservados.
6. Preencher um tabuleiro completo corretamente e usar Verificar para conferir a mensagem de conclusão.
7. Com uma casa preenchida e a página aberta, encerrar o processo do backend. Usar Verificar, conferir a mensagem de erro e comparar o puzzle e as entradas.
8. Religar o backend e usar Tentar de novo, sem recarregar a página. Conferir a resposta e a preservação do preenchimento.

O bloqueio dos controles foi conferido com um atraso controlado de três segundos no envio de uma requisição pelo navegador, mantendo o servidor e sua resposta reais. Durante a espera, uma tecla de edição não alterou o tabuleiro. Esse atraso foi removido antes dos demais testes. A interrupção do backend foi real, encerrando e reiniciando o processo. Com o servidor desligado, o proxy respondeu 502 e a interface exibiu uma mensagem de falha de comunicação.

Todos os critérios da issue #29 passaram nesta conferência. Não foi identificado novo defeito da aplicação durante estes cenários. Os tempos registrados correspondem à amostra executada.
