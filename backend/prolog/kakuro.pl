:- module(kakuro, [solution_count/3, solve/3, check/3, hint/3]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).  % maplist, include



%    Puzzle  = lista de 6 listas, cada uma com 6 células.
%    Célula  = "block" | "white" | [AcrossClue, DownClue]
%              (0 = sem pista nessa direção)
%    Entradas = lista de [Linha, Coluna, Valor]  (0-based, valor 1..9)
%    Solução  = lista de [Linha, Coluna, Valor]


%  1. Normalização de células (strings Python → átomos Prolog)
normalize_cell(Raw, block) :-
    (Raw == block ; Raw == "block"), !.
normalize_cell(Raw, white) :-
    (Raw == white ; Raw == "white"), !.
normalize_cell([A, D], clue(A, D)) :-
    integer(A), integer(D), !.


normalize_puzzle(RawPuzzle, Puzzle) :-
    maplist(maplist(normalize_cell), RawPuzzle, Puzzle).



%  2. Transposição de uma grade (lista de listas)
transp([], []).
transp([[]|_], []) :- !.
transp(Rows, [Col|Cols]) :-
    maplist(head_tail, Rows, Col, Tails),
    transp(Tails, Cols).

head_tail([H|T], H, T).



%  3. Extração de sequências nas duas direções
%  Uma sequência = seq(Pista, [pos(L,C), ...])
%  Horizontal: pista = A de clue(A,_) com A > 0, seguida de whites
%  Vertical:   pista = D de clue(_,D) com D > 0, seguida de whites na coluna
sequences(Puzzle, Seqs) :-
    h_seqs(Puzzle, 0, HSeqs),
    transp(Puzzle, TPuzzle),
    v_seqs(TPuzzle, 0, VSeqs),
    append(HSeqs, VSeqs, Seqs).

%horizontais:
h_seqs([], _, []).
h_seqs([Row|Rows], R, Seqs) :-
    row_seqs(Row, R, 0, S1),
    R1 is R + 1,
    h_seqs(Rows, R1, S2),
    append(S1, S2, Seqs).

row_seqs([], _, _, []).
row_seqs([clue(A,_)|Rest], R, C, Seqs) :-
    A > 0, !,
    C1 is C + 1,
    collect_whites_h(Rest, R, C1, Cells, Remaining, NextC),
    (   Cells = [_,_|_]                     % ≥ 2 casas
    ->  Seqs = [seq(A, Cells)|More]
    ;   Seqs = More                          % sequência degenerada: ignora
    ),
    row_seqs(Remaining, R, NextC, More).
row_seqs([_|Rest], R, C, Seqs) :-
    C1 is C + 1,
    row_seqs(Rest, R, C1, Seqs).

collect_whites_h([], _, C, [], [], C).
collect_whites_h([white|Rest], R, C, [pos(R,C)|Cells], Rem, NC) :-
    !,
    C1 is C + 1,
    collect_whites_h(Rest, R, C1, Cells, Rem, NC).
collect_whites_h(Other, _, C, [], Other, C).

% verticais:
v_seqs([], _, []).
v_seqs([Col|Cols], C, Seqs) :-
    col_seqs(Col, C, 0, S1),
    C1 is C + 1,
    v_seqs(Cols, C1, S2),
    append(S1, S2, Seqs).

col_seqs([], _, _, []).
col_seqs([clue(_,D)|Rest], C, R, Seqs) :-
    D > 0, !,
    R1 is R + 1,
    collect_whites_v(Rest, C, R1, Cells, Remaining, NextR),
    (   Cells = [_,_|_]
    ->  Seqs = [seq(D, Cells)|More]
    ;   Seqs = More
    ),
    col_seqs(Remaining, C, NextR, More).
col_seqs([_|Rest], C, R, Seqs) :-
    R1 is R + 1,
    col_seqs(Rest, C, R1, Seqs).

collect_whites_v([], _, R, [], [], R).
collect_whites_v([white|Rest], C, R, [pos(R,C)|Cells], Rem, NR) :-
    !,
    R1 is R + 1,
    collect_whites_v(Rest, C, R1, Cells, Rem, NR).
collect_whites_v(Other, _, R, [], Other, R).


%  4. Coleta das posições em bramco 
white_positions(Puzzle, Positions) :-
    white_pos_(Puzzle, 0, Positions).

white_pos_([], _, []).
white_pos_([Row|Rows], R, Pos) :-
    white_pos_row(Row, R, 0, P1),
    R1 is R + 1,
    white_pos_(Rows, R1, P2),
    append(P1, P2, Pos).

white_pos_row([], _, _, []).
white_pos_row([white|Rest], R, C, [pos(R,C)|More]) :-
    !, C1 is C + 1,
    white_pos_row(Rest, R, C1, More).
white_pos_row([_|Rest], R, C, More) :-
    C1 is C + 1,
    white_pos_row(Rest, R, C1, More).




%  5. Mapa posição → variável CLP(FD) e montagem das restrições
setup(Puzzle, Entradas, VarMap, AllVars) :-
    normalize_puzzle(Puzzle, NPuzzle),
    white_positions(NPuzzle, Positions),
    make_varmap(Positions, VarMap, AllVars),
    AllVars ins 1..9,
    apply_entries(Entradas, VarMap),
    sequences(NPuzzle, Seqs),
    post_constraints(Seqs, VarMap).

make_varmap([], [], []).
make_varmap([P|Ps], [P-V|Map], [V|Vs]) :-
    make_varmap(Ps, Map, Vs).

lookup(Pos, [Pos-V|_], V) :- !.
lookup(Pos, [_|Rest], V)  :- lookup(Pos, Rest, V).

apply_entries([], _).
apply_entries([[L,C,Val]|Es], Map) :-
    lookup(pos(L,C), Map, Var),
    Var #= Val,
    apply_entries(Es, Map).

post_constraints([], _).
post_constraints([seq(Clue, Cells)|Seqs], Map) :-
    maplist(lookup_in(Map), Cells, Vars),
    all_distinct(Vars),
    sum(Vars, #=, Clue),
    post_constraints(Seqs, Map).

lookup_in(Map, Pos, Var) :- lookup(Pos, Map, Var).

%  6. solution_count(+Puzzle, +Entradas, -N)
%     N ∈ {0, 1, 2}  –  para de contar ao atingir 2.

solution_count(Puzzle, Entradas, N) :-
    (   catch(
            setup(Puzzle, Entradas, _Map, Vars),
            _, fail)
    ->  count_up_to_2(Vars, N)
    ;   N = 0
    ).

%  conta soluções (via labeling) até no máximo 2.
%  usa findall com um limite manual para não explorar todas as soluções.
count_up_to_2(Vars, N) :-
    State = count(0),
    (   labeling([ff], Vars),
        arg(1, State, K),
        K1 is K + 1,
        nb_setarg(1, State, K1),
        K1 >= 2, !       % Para ao atingir 2
    ;   true
    ),
    arg(1, State, N).


%  7. solve  +Puzzle, +Entradas, -Solucao
solve(Puzzle, Entradas, Solucao) :-
    setup(Puzzle, Entradas, VarMap, AllVars),
    labeling([ff], AllVars),
    maplist(pair_to_entry, VarMap, Solucao).

pair_to_entry(pos(R,C)-V, [R,C,V]).



%  8. check Estado = "solved" | "incomplete" | "inconsistent"
check(Puzzle, Entradas, Estado) :-
    normalize_puzzle(Puzzle, NPuzzle),
    white_positions(NPuzzle, Positions),
    length(Positions, Total),
    length(Entradas, Given),
    (   Given < Total
    ->  % Parcial: ver se ainda há pelo menos uma solução
        (   catch(
                ( setup(Puzzle, Entradas, _M, Vs),
                  copy_term(Vs, Vs2),
                  labeling([ff], Vs2) ),
                _, fail)
        ->  Estado = "incomplete"
        ;   Estado = "inconsistent"
        )
    ;   % Completo: verificar validade
        (   catch(
                ( setup(Puzzle, Entradas, _M2, Vs3),
                  ground(Vs3) ),
                _, fail)
        ->  Estado = "solved"
        ;   Estado = "inconsistent"
        )
    ).





%  9. hint
%     Resultado = ["hint", L, C, V]
%               | "complete"
%               | "inconsistent"
%               | "no_forced_hint"

hint(Puzzle, Entradas, Resultado) :-
    normalize_puzzle(Puzzle, NPuzzle),
    white_positions(NPuzzle, Positions),
    length(Positions, Total),
    length(Entradas, Given),
    (   Given >= Total
    ->  Resultado = "complete"
    ;   (   catch(
                setup(Puzzle, Entradas, VarMap, Vars),
                _, fail)
        ->  copy_term(Vars, TestVars),
            (   labeling([ff], TestVars)
            ->  % Consistente – procurar célula forçada
                filled_set(Entradas, Filled),
                find_forced(VarMap, Filled, Resultado)
            ;   Resultado = "inconsistent"
            )
        ;   Resultado = "inconsistent"
        )
    ).

filled_set([], []).
filled_set([[L,C,_]|Es], [pos(L,C)|Rest]) :-
    filled_set(Es, Rest).

find_forced([], _, "no_forced_hint").
find_forced([pos(R,C)-Var|Rest], Filled, Resultado) :-
    (   member(pos(R,C), Filled)
    ->  find_forced(Rest, Filled, Resultado)       % já preenchida
    ;   fd_size(Var, Size),
        (   Size == 1
        ->  fd_dom(Var, Val..Val),
            Resultado = ["hint", R, C, Val]
        ;   find_forced(Rest, Filled, Resultado)
        )
    ).
