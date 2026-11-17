
%  Rodar:   swipl -g "load_test_files([]), run_tests" -t halt test_kakuro.pl
%           ou:  swipl -g run_tests -t halt test_kakuro.pl


:- use_module(kakuro).
:- use_module(generator).
:- use_module(library(plunit)).
:- use_module(library(lists)).


% Puzzle "mini" 4×4 embutido num grid 6×6
% (as bordas são blocos, interior é um mini kakuro)
%
%  B      [0,4]  [0,3]  B     B     B
%  [7,0]  W      W      B     B     B
%  [3,0]  W      W      B     B     B
%  B      B      B      B     B     B
%  B      B      B      B     B     B
%  B      B      B      B     B     B
%
%  Horizontal: Seq1: soma=7, casas (1,1)(1,2)
%              Seq2: soma=3, casas (2,1)(2,2)
%  Vertical:   Seq3: soma=4, casas (1,1)(2,1)
%              Seq4: soma=3, casas (1,2)(2,2)
%
%  Solução: (1,1)=3, (1,2)=4

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

% Puzzle com duas soluções: mudar a pista vertical para permitir ambiguidade
% h1: a+b=7, h2: c+d=3
% Sem restrições verticais fortes (coluna-somas altas permitem várias combinações)
% Usar [0,10] e [0,10] → v1: a+c=10? Impossível com small numbers. 
% Mais simples: pista vertical que aceite 2 combinações.
% a+c = 5:  (3,2) ou (4,1) → se h dá a+b=7, c+d=3:
%   a=3,c=2: b=4,d=1. v2: b+d=5 → [0,5]
%   a=4,c=1: b=3,d=2. v2: b+d=5 → [0,5] também!
% Ambas funcionam → 2 soluções! ✓

puzzle_two_solutions(Puzzle) :-
    Puzzle = [
        ["block", [0,5],   [0,5],   "block", "block", "block"],
        [[7,0],  "white", "white", "block", "block", "block"],
        [[3,0],  "white", "white", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ].

% Puzzle sem solução: somas impossíveis
% h1: a+b=3, a≠b, a,b∈1..9  → (1,2)
% h2: c+d=3                  → (1,2)
% v1: a+c=3 → (1,2): a=1,c=2 ou a=2,c=1
% v2: b+d=5 → mas se a=1,b=2,c=2,d=1: b+d=3≠5. Se a=2,b=1,c=1,d=2: b+d=3≠5.
% → nenhuma solução!

puzzle_no_solution(Puzzle) :-
    Puzzle = [
        ["block", [0,3],   [0,5],   "block", "block", "block"],
        [[3,0],  "white", "white", "block", "block", "block"],
        [[3,0],  "white", "white", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ].

% Puzzle 6×6 completo 
%
%  B      [0,17] [0,21]  B     [0,8]  [0,11]
%  [16,0]  W      W     [11,0]  W      W
%  [23,0]  W      W      W      W      W
%  [6,0]   W      W      B      B      B
%  B       B     [13,0]  W      W      W
%  B       B      B      B      B      B


puzzle_full(Puzzle) :-
    Puzzle = [
        ["block", [0,18],  [0,18],  "block", [0,7],   [0,4]],
        [[16,0], "white", "white", [8,0],   "white", "white"],
        [[21,0], "white", "white", "white", "white", "white"],
        [[6,0],  "white", "white", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"],
        ["block", "block", "block", "block", "block", "block"]
    ].

%  Testes:

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
    % Forçar (1,1)=9, que não é compatível
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
    % Deve retornar uma solução: todas as casas preenchidas
    length(Sol, Len),
    assertion(Len > 0),
    % Cada valor entre 1 e 9
    forall(member([_,_,V], Sol), (V >= 1, V =< 9)).

:- end_tests(solve).

:- begin_tests(check).

test(check_solved) :-
    puzzle_mini(P),
    puzzle_mini_solution(Entries),
    check(P, Entries, Estado),
    assertion(Estado == "solved").

test(check_incomplete) :-
    puzzle_mini(P),
    check(P, [[1,1,3]], Estado),
    assertion(Estado == "incomplete").

test(check_empty_is_incomplete) :-
    puzzle_mini(P),
    check(P, [], Estado),
    assertion(Estado == "incomplete").

test(check_inconsistent_wrong_value) :-
    puzzle_mini(P),
    % Colocar valores que violam restrições: (1,1)=1, (1,2)=2 → soma=3≠7
    check(P, [[1,1,1],[1,2,2],[2,1,3],[2,2,2]], Estado),
    assertion(Estado == "inconsistent").

test(check_inconsistent_no_possible_solution) :-
    puzzle_no_solution(P),
    check(P, [], Estado),
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

test(hint_returns_valid_cell) :-
    puzzle_mini(P),
    % Com 3 das 4 casas preenchidas, a 4ª deve ser forçada
    hint(P, [[1,1,3],[1,2,4],[2,1,1]], Resultado),
    assertion(Resultado == ["hint", 2, 2, 2]).

test(hint_from_empty_unique, [true(is_hint_or_no_forced(R))]) :-
    puzzle_mini(P),
    hint(P, [], R).

is_hint_or_no_forced(["hint",_,_,_]).
is_hint_or_no_forced("no_forced_hint").

:- end_tests(hint).

%  Testes de cruzamento e restrições

:- begin_tests(constraints).

test(distinct_within_sequence) :-
    % Num kakuro, dígitos na mesma sequência devem ser distintos.
    % Se forçamos dois iguais numa sequência, não podd ter solução.
    puzzle_mini(P),
    % (1,1) e (1,2) estão na mesma sequência horizontal (soma=7)
    % Forçar ambos a 3 → soma=6≠7, e/ou violação de distinct
    solution_count(P, [[1,1,3],[1,2,3]], N),
    assertion(N == 0).

test(cross_constraint, [nondet]) :-
    % (1,1) participa de h1 e v1. Verificar que o valor é consistente com ambos.
    puzzle_mini(P),
    % (1,1)=3 deve funcionar
    solve(P, [[1,1,3]], Sol),
    member([1,1,3], Sol).

test(sum_constraint, [nondet]) :-
    % verificar que a soma está correta na solução
    puzzle_mini(P),
    solve(P, [], Sol),
    member([1,1,A], Sol),
    member([1,2,B], Sol),
    Sum is A + B,
    assertion(Sum == 7).

:- end_tests(constraints).

% Executar automaticamente com run_tests
:- initialization((
    run_tests,
    halt
), main).


% Testes do gerador (issue #22)
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
