%  test_kakuro.pl – Testes plunit para o módulo kakuro (Pessoa A)
%
%  Rodar:   swipl -g run_tests -t halt test_kakuro.pl

:- use_module(kakuro).
:- use_module(generator).
:- use_module('../../docs/fixtures/fixtures').
:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(time)).


% Puzzle "mini" 4 casas brancas num grid 6×6, solução única
%
%  B      [0,4]  [0,6]  B     B     B
%  [7,0]  W      W      B     B     B
%  [3,0]  W      W      B     B     B
%  B      B      B      B     B     B
%  B      B      B      B     B     B
%  B      B      B      B     B     B
%
%  h1: a+b=7   h2: c+d=3
%  v1: a+c=4   v2: b+d=6
%  Solução única: a=3 b=4 c=1 d=2

puzzle_mini(Puzzle) :-
    Puzzle = [
        ["block", [0,4],   [0,6],   "block", "block", "block"],
        [[7,0],  "white", "white", "block", "block", "block"],
        [[3,0],  "white", "white", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ].

puzzle_mini_solution([[1,1,3],[1,2,4],[2,1,1],[2,2,2]]).

% Puzzle com duas soluções
%  v1: a+c=5  v2: b+d=5  (aceita (3,2)/(4,1) e (4,1)/(3,2))
puzzle_two_solutions(Puzzle) :-
    Puzzle = [
        ["block", [0,5],   [0,5],   "block", "block", "block"],
        [[7,0],  "white", "white", "block", "block", "block"],
        [[3,0],  "white", "white", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ].

% Puzzle sem solução (pistas incompatíveis)
puzzle_no_solution(Puzzle) :-
    Puzzle = [
        ["block", [0,3],   [0,5],   "block", "block", "block"],
        [[3,0],  "white", "white", "block", "block", "block"],
        [[3,0],  "white", "white", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ].

% Puzzle 6×6 com mais casas brancas
puzzle_full(Puzzle) :-
    Puzzle = [
        ["block", [0,17],  [0,18],  "block", [0,7],   [0,4]],
        [[16,0], "white", "white", [8,7],   "white", "white"],
        [[21,0], "white", "white", "white", "white", "white"],
        ["block", [8,0],  "white", "white", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ].



:- begin_tests(solution_count).

test(unique_puzzle_has_one_solution) :-
    puzzle_mini(P),
    solution_count(P, [], N),
    assertion(N == 1).

test(two_solution_puzzle) :-
    puzzle_two_solutions(P),
    solution_count(P, [], N),
    assertion(N == 2).

test(no_solution_puzzle) :-
    puzzle_no_solution(P),
    solution_count(P, [], N),
    assertion(N == 0).

test(partial_entry_still_unique) :-
    puzzle_mini(P),
    solution_count(P, [[1,1,3]], N),
    assertion(N == 1).

test(wrong_entry_no_solution) :-
    puzzle_mini(P),
    solution_count(P, [[1,1,9]], N),
    assertion(N == 0).

:- end_tests(solution_count).



:- begin_tests(solve).

test(solve_mini_empty) :-
    puzzle_mini(P),
    solve(P, [], Sol),
    msort(Sol, Sorted),
    puzzle_mini_solution(Expected),
    msort(Expected, SortedExp),
    assertion(Sorted == SortedExp).

test(solve_mini_partial, [nondet]) :-
    puzzle_mini(P),
    solve(P, [[1,1,3]], Sol),
    member([1,1,3], Sol),
    member([1,2,4], Sol),
    member([2,1,1], Sol),
    member([2,2,2], Sol).

test(solve_no_solution, [fail]) :-
    puzzle_no_solution(P),
    solve(P, [], _).

test(solve_full_puzzle, [nondet]) :-
    puzzle_full(P),
    solve(P, [], Sol),
    length(Sol, Len),
    assertion(Len > 0),
    forall(member([_,_,V], Sol), (V >= 1, V =< 9)).

:- end_tests(solve).



:- begin_tests(check).

test(check_solved) :-
    puzzle_mini(P),
    puzzle_mini_solution(Entries),
    check(P, Entries, Estado),
    assertion(Estado == "solved").

% Revisão PR #49: 1 de 4 casas preenchida é "incomplete", mesmo que o
% CLP(FD) consiga deduzir as outras 3 por propagação.
test(check_incomplete) :-
    puzzle_mini(P),
    check(P, [[1,1,3]], Estado),
    assertion(Estado == "incomplete").

test(check_incomplete_fixture) :-
    fixture_puzzle(1, P),
    check(P, [[1,1,3]], Estado),
    assertion(Estado == "incomplete").

test(check_incomplete_larger) :-
    puzzle_full(P),
    check(P, [[1,1,9]], Estado),
    assertion(Estado == "incomplete").

test(check_empty_is_incomplete) :-
    puzzle_mini(P),
    check(P, [], Estado),
    assertion(Estado == "incomplete").

test(check_inconsistent_wrong_value) :-
    puzzle_mini(P),
    % (1,1)=1 (1,2)=2 → soma=3≠7
    check(P, [[1,1,1],[1,2,2],[2,1,3],[2,2,2]], Estado),
    assertion(Estado == "inconsistent").

test(check_inconsistent_no_possible_solution) :-
    puzzle_no_solution(P),
    check(P, [], Estado),
    assertion(Estado == "inconsistent").

% Issue 1: tabuleiro completo mas errado NÃO deve ser "solved"
test(check_full_but_wrong_is_inconsistent) :-
    puzzle_mini(P),
    check(P, [[1,1,1],[1,2,2],[2,1,3],[2,2,1]], Estado),
    assertion(Estado == "inconsistent").

:- end_tests(check).


:- begin_tests(hint).

test(hint_complete) :-
    puzzle_mini(P),
    puzzle_mini_solution(Entries),
    hint(P, Entries, Resultado),
    assertion(Resultado == "complete").

test(hint_inconsistent) :-
    puzzle_no_solution(P),
    hint(P, [], Resultado),
    assertion(Resultado == "inconsistent").

% Revisão PR #49: com 3 de 4 casas, a dica é a casa (2,2) que falta.
test(hint_returns_last_cell) :-
    puzzle_mini(P),
    hint(P, [[1,1,3],[1,2,4],[2,1,1]], Resultado),
    assertion(Resultado == ["hint", 2, 2, 2]).

% Issue #21: em puzzle com solução única, tabuleiro vazio sempre dá dica,
% e o valor revelado é o da solução.
test(hint_from_empty_unique) :-
    puzzle_mini(P),
    hint(P, [], R),
    assertion(R = ["hint", _, _, _]),
    R = ["hint", L, C, V],
    puzzle_mini_solution(Sol),
    assertion(memberchk([L, C, V], Sol)).

% Issue #21: nunca revela casa que o jogador já preencheu.
test(hint_skips_filled_cells) :-
    puzzle_mini(P),
    hint(P, [[1,1,3]], ["hint", L, C, _]),
    assertion([L, C] \== [1, 1]).


test(hint_no_forced_hint) :-
    puzzle_two_solutions(P),
    hint(P, [], R),
    assertion(R == "no_forced_hint").

test(hint_fixtures_match_solution) :-
    forall(member(Id, [1, 2, 3]),
           ( fixture_puzzle(Id, P),
             fixture_solution(Id, Sol),
             hint(P, [], ["hint", L, C, V]),
             assertion(memberchk([L, C, V], Sol)) )).


test(hint_full_but_wrong_is_inconsistent) :-
    puzzle_mini(P),
    hint(P, [[1,1,1],[1,2,2],[2,1,3],[2,2,1]], Resultado),
    assertion(Resultado == "inconsistent").

:- end_tests(hint).


:- begin_tests(constraints).

test(distinct_within_sequence) :-
    puzzle_mini(P),
    solution_count(P, [[1,1,3],[1,2,3]], N),
    assertion(N == 0).

test(cross_constraint, [nondet]) :-
    puzzle_mini(P),
    solve(P, [[1,1,3]], Sol),
    member([1,1,3], Sol).

test(sum_constraint, [nondet]) :-
    puzzle_mini(P),
    solve(P, [], Sol),
    member([1,1,A], Sol),
    member([1,2,B], Sol),
    Sum is A + B,
    assertion(Sum == 7).

:- end_tests(constraints).

:- begin_tests(format_errors).

test(check_rejects_invalid_cell, [throws(error(domain_error(kakuro_cell, "invalid"), _))]) :-
    P = [
        ["invalid", [0,4],   [0,6],   "block", "block", "block"],
        [[7,0],     "white", "white", "block", "block", "block"],
        [[3,0],     "white", "white", "block", "block", "block"],
        ["block",   "block", "block", "block", "block", "block"],
        ["block",   "block", "block", "block", "block", "block"],
        ["block",   "block", "block", "block", "block", "block"]
    ],
    check(P, [], _).

test(hint_rejects_invalid_grid_size, [throws(error(domain_error(kakuro_grid_6x6, _), _))]) :-
    hint([["block"]], [], _).

test(solution_count_rejects_entry_on_block, [throws(error(domain_error(kakuro_entry, [0,0,5]), _))]) :-
    puzzle_mini(P),
    solution_count(P, [[0,0,5]], _).

test(check_rejects_out_of_range_entry, [throws(error(domain_error(kakuro_entry, [1,1,10]), _))]) :-
    puzzle_mini(P),
    check(P, [[1,1,10]], _).

test(check_rejects_out_of_board_entry, [throws(error(domain_error(kakuro_entry, [6,1,5]), _))]) :-
    puzzle_mini(P),
    check(P, [[6,1,5]], _).

test(check_rejects_duplicate_entry, [throws(error(domain_error(kakuro_duplicate_entry, [1,1,3]), _))]) :-
    puzzle_mini(P),
    check(P, [[1,1,3],[1,1,3]], _).

test(hint_rejects_duplicate_entry_different_values, [throws(error(domain_error(kakuro_duplicate_entry, [1,1,4]), _))]) :-
    puzzle_mini(P),
    hint(P, [[1,1,3],[1,1,4]], _).

test(check_rejects_single_cell_horizontal_sequence, [throws(error(domain_error(kakuro_sequence, _), _))]) :-
    P = [
        ["block", [0,4],   "block", "block", "block", "block"],
        [[4,0],   "white", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ],
    check(P, [], _).

test(check_rejects_single_cell_vertical_sequence, [throws(error(domain_error(kakuro_sequence, _), _))]) :-
    P = [
        ["block", [0,4],   [0,6],   "block", "block", "block"],
        [[7,0],   "white", "white", "block", "block", "block"],
        [[3,0],   "white", "white", "block", "block", "block"],
        ["block", "block", "block", "block", [0,5],   "block"],
        ["block", "block", "block", "block", "white", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ],
    check(P, [], _).

test(check_rejects_white_without_horizontal_and_vertical_sequence, [throws(error(domain_error(kakuro_white_cell, pos(2,3)), _))]) :-
    P = [
        ["block", [0,18],  [0,18],  "block", [0,7],   [0,4]],
        [[16,0], "white", "white", [8,0],   "white", "white"],
        [[21,0], "white", "white", "white", "white", "white"],
        [[6,0],  "white", "white", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ],
    check(P, [], _).

:- end_tests(format_errors).

:- begin_tests(fixtures).

test(all_fixtures_have_unique_solution) :-
    forall(member(Id, [1, 2, 3]), (
        fixture_puzzle(Id, P),
        fixture_solution(Id, Expected),
        solution_count(P, [], N),
        assertion(N == 1),
        solve(P, [], Sol),
        msort(Sol, SortedSol),
        msort(Expected, SortedExp),
        assertion(SortedSol == SortedExp),
        check(P, Expected, Estado),
        assertion(Estado == "solved")
    )).

:- end_tests(fixtures).


:- begin_tests(solution_count_bounded).

test(stops_at_two_solutions) :-
    Row = [[25,0], "white", "white", "white", "white", "white"],
    P = [["block", [0,25], [0,25], [0,25], [0,25], [0,25]],
         Row, Row, Row, Row, Row],
    call_with_time_limit(1, solution_count(P, [], N)),
    assertion(N == 2).

:- end_tests(solution_count_bounded).


:- begin_tests(generator).

celula_valida(block).
celula_valida(white).
celula_valida([A, D]) :-
    integer(A), A >= 0,
    integer(D), D >= 0.

puzzle_6x6(P) :-
    length(P, 6),
    forall(member(Linha, P),
           ( length(Linha, 6),
             forall(member(C, Linha), celula_valida(C)) )).

test(formato_6x6) :-
    generate(1, P),
    assertion(puzzle_6x6(P)).

test(solucao_unica) :-
    generate(2, P),
    solution_count(P, [], 1).

test(solucao_bate_com_solve) :-
    generate_with_solution(P, Sol),
    once(solve(P, [], S2)),
    msort(Sol, A),
    msort(S2, B),
    assertion(A == B).

test(solucao_resolve_o_check) :-
    generate_with_solution(P, Sol),
    check(P, Sol, Estado),
    assertion(Estado == "solved").

test(semente_reproduzivel) :-
    generate(42, P1),
    generate(42, P2),
    assertion(P1 == P2).

test(varias_geracoes) :-
    forall(between(1, 10, S),
           ( generate(S, P),
             puzzle_6x6(P),
             solution_count(P, [], 1) )).

:- end_tests(generator).
