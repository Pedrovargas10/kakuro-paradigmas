:- module(generator, [generate/1, generate/2, generate_with_solution/2,
                      print_puzzle/1]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(random)).
:- use_module(library(time)).
:- use_module(kakuro, [solution_count/3]).



%    Puzzle  = lista de 6 listas, cada uma com 6 células.
%    Célula  = block | white | [AcrossClue, DownClue]
%              (0 = sem pista nessa direção)
%    Solução = lista de [Linha, Coluna, Valor]  (0-based)


%  1. generate(-Puzzle) e generate(+Semente, -Puzzle)
%     Falha se não conseguir gerar em 10 segundos.
generate(Puzzle) :-
    generate_with_solution(Puzzle, _).

generate(Seed, Puzzle) :-
    set_random(seed(Seed)),
    generate(Puzzle).

generate_with_solution(Puzzle, Solution) :-
    catch(call_with_time_limit(10, try_generate(Puzzle, Solution)),
          time_limit_exceeded,
          fail).

%  sem solução única: tenta outros dígitos (até 20) e depois outra máscara
try_generate(Puzzle, Solution) :-
    repeat,
    random_mask(Mask),
    between(1, 20, _),
    random_fill(Mask, Values),
    make_puzzle(Mask, Values, Puzzle, Solution),
    solution_count(Puzzle, [], 1),
    !.



%  2. Máscara aleatória (1 = casa branca, 0 = casa preta)
%     Primeira linha e primeira coluna pretas, de 8 a 12 casas brancas e
%     nenhuma casa branca sozinha na linha ou na coluna.
random_mask(Mask) :-
    Mask = [[0, 0, 0, 0, 0, 0],
            [0, _, _, _, _, _],
            [0, _, _, _, _, _],
            [0, _, _, _, _, _],
            [0, _, _, _, _, _],
            [0, _, _, _, _, _]],
    append(Mask, Cells),
    Cells ins 0..1,
    sum(Cells, #>=, 8),
    sum(Cells, #=<, 12),
    maplist(no_lonely_white, Mask),
    transpose(Mask, Columns),
    maplist(no_lonely_white, Columns),
    random_permutation(Cells, Shuffled),
    once(random_bits(Shuffled)).

%  casa branca precisa de vizinho branco à esquerda ou à direita
no_lonely_white(Line) :-
    append(Line, [0], Padded),
    triples_rule(Padded).

triples_rule([Left, Cell, Right | Rest]) :-
    !,
    Cell #==> (Left #= 1 #\/ Right #= 1),
    triples_rule([Cell, Right | Rest]).
triples_rule(_).

random_bits([]).
random_bits([Cell | Cells]) :-
    random_permutation([0, 1], Order),
    member(Cell, Order),
    random_bits(Cells).



%  3. Grade com variáveis e sequências
%     Casa preta = b, casa branca = variável nova. A casa no cruzamento é a
%     mesma variável na sequência horizontal e na vertical.
mask_grid(Mask, Grid) :-
    maplist(maplist(mask_cell), Mask, Grid).

mask_cell(0, b).
mask_cell(1, _).

grid_runs(Grid, Runs) :-
    transpose(Grid, Columns),
    append(Grid, Columns, Lines),
    maplist(line_runs, Lines, RunsPerLine),
    append(RunsPerLine, Runs).

%  usa == porque uma casa branca ainda é variável (Cell = b unificaria)
line_runs([], []).
line_runs([Cell | Cells], Runs) :-
    Cell == b,
    !,
    line_runs(Cells, Runs).
line_runs([Cell | Cells], [Run | Runs]) :-
    take_whites([Cell | Cells], Run, Rest),
    line_runs(Rest, Runs).

take_whites([Cell | Cells], [Cell | Whites], Rest) :-
    Cell \== b,
    !,
    take_whites(Cells, Whites, Rest).
take_whites(Rest, [], Rest).

run_rule(Run) :-
    Run ins 1..9,
    all_distinct(Run).



%  4. Preenchimento aleatório (dígitos das casas brancas, em ordem de leitura)
random_fill(Mask, Values) :-
    mask_grid(Mask, Grid),
    grid_runs(Grid, Runs),
    maplist(run_rule, Runs),
    term_variables(Grid, Values),
    once(random_labeling(Values)).

random_labeling([]).
random_labeling([Var | Vars]) :-
    numlist(1, 9, Digits),
    random_permutation(Digits, Shuffled),
    member(Var, Shuffled),
    random_labeling(Vars).



%  5. Pistas e solução
make_puzzle(Mask, Values, Puzzle, Solution) :-
    mask_grid(Mask, Grid),
    term_variables(Grid, Values),
    grid_clues(Grid, Puzzle),
    grid_solution(Grid, Solution).

%  somas abaixo = somas à direita das colunas (transpõe e transpõe de volta)
grid_clues(Grid, Puzzle) :-
    maplist(line_sums, Grid, AcrossRows),
    transpose(Grid, Columns),
    maplist(line_sums, Columns, DownColumns),
    transpose(DownColumns, DownRows),
    maplist(maplist(puzzle_cell), Grid, AcrossRows, DownRows, Puzzle).

line_sums([], []).
line_sums([b | Cells], [Sum | Sums]) :-
    !,
    take_whites(Cells, Digits, _),
    sum_list(Digits, Sum),
    line_sums(Cells, Sums).
line_sums([_ | Cells], [0 | Sums]) :-
    line_sums(Cells, Sums).

puzzle_cell(b, 0, 0, block) :- !.
puzzle_cell(b, Across, Down, [Across, Down]) :- !.
puzzle_cell(_, _, _, white).

grid_solution(Grid, Solution) :-
    findall([R, C, V],
            ( nth0(R, Grid, Row),
              nth0(C, Row, V),
              integer(V) ),
            Solution).



%  6. Mostrar no terminal
print_puzzle(Puzzle) :-
    forall(member(Row, Puzzle), (print(Row), nl)).
