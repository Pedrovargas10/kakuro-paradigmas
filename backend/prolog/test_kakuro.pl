%  test_kakuro.pl – Testes plunit para o módulo kakuro (Pessoa A)
%
%  Rodar:   swipl -g run_tests -t halt test_kakuro.pl

:- use_module(kakuro).
:- use_module('../../docs/fixtures/fixtures').
:- use_module(library(plunit)).
:- use_module(library(lists)).


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
        ["block", [0,18],  [0,18],  "block", [0,7],   [0,4]],
        [[16,0], "white", "white", [8,0],   "white", "white"],
        [[21,0], "white", "white", "white", "white", "white"],
        [[6,0],  "white", "white", "block", "block", "block"],
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

test(check_incomplete) :-
    % puzzle_full tem 11 casas: uma entrada parcial não propaga tudo
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

% No puzzle mini, 3 entradas corretas propagam a 4ª automaticamente.
test(hint_propagation_completes) :-
    puzzle_mini(P),
    hint(P, [[1,1,3],[1,2,4],[2,1,1]], Resultado),
    assertion(Resultado == "complete").

% No puzzle_full, com poucas entradas, hint encontra dica ou diz no_forced.
test(hint_on_larger_puzzle, [true(is_hint_or_no_forced(R))]) :-
    puzzle_full(P),
    hint(P, [[1,1,9]], R).

test(hint_from_empty_unique, [true(is_hint_or_no_forced(R))]) :-
    puzzle_mini(P),
    hint(P, [], R).


test(hint_full_but_wrong_is_inconsistent) :-
    puzzle_mini(P),
    hint(P, [[1,1,1],[1,2,2],[2,1,3],[2,2,1]], Resultado),
    assertion(Resultado == "inconsistent").

is_hint_or_no_forced(["hint",_,_,_]).
is_hint_or_no_forced("no_forced_hint").

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
