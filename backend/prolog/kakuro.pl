:- module(kakuro, [solution_count/3, solve/3, check/3, hint/3]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(library(apply)).  % maplist, include

%    Puzzle  = lista de 6 listas, cada uma com 6 células.
%    Célula  = "block" | "white" | [AcrossClue, DownClue]
%              (0 = sem pista nessa direção)
%    Entradas = lista de [Linha, Coluna, Valor]  (0-based, valor 1..9)
%    Solução  = lista de [Linha, Coluna, Valor]


%  1. Normalização de células e validação de formato (strings Python → átomos Prolog)
normalize_cell(Raw, block) :-
    (Raw == block ; Raw == "block"), !.
normalize_cell(Raw, white) :-
    (Raw == white ; Raw == "white"), !.
normalize_cell([A, D], clue(A, D)) :-
    integer(A), A >= 0,
    integer(D), D >= 0, !.
normalize_cell(Raw, _) :-
    throw(error(domain_error(kakuro_cell, Raw), context(normalize_cell/2, 'célula inválida'))).

normalize_puzzle(RawPuzzle, Puzzle) :-
    (   is_list(RawPuzzle),
        length(RawPuzzle, 6),
        forall(member(Row, RawPuzzle), (is_list(Row), length(Row, 6)))
    ->  maplist(maplist(normalize_cell), RawPuzzle, Puzzle)
    ;   throw(error(domain_error(kakuro_grid_6x6, RawPuzzle), context(normalize_puzzle/2, 'grade deve ser 6x6')))
    ).



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
collect_whites_h([Cell|Rest], _, C, [], [Cell|Rest], C) :-
    Cell \= white.

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
collect_whites_v([Cell|Rest], _, R, [], [Cell|Rest], R) :-
    Cell \= white.


%  4. Coleta das posições brancas
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
apply_entries([Entry|Es], Map) :-
    (   Entry = [L, C, Val],
        integer(L), integer(C), integer(Val),
        between(1, 9, Val),
        lookup(pos(L, C), Map, Var)
    ->  Var #= Val,
        apply_entries(Es, Map)
    ;   throw(error(domain_error(kakuro_entry, Entry), context(apply_entries/2, 'entrada inválida ou fora de casa branca')))
    ).

post_constraints([], _).
post_constraints([seq(Clue, Cells)|Seqs], Map) :-
    maplist(lookup_in(Map), Cells, Vars),
    all_distinct(Vars),
    sum(Vars, #=, Clue),
    post_constraints(Seqs, Map).

lookup_in(Map, Pos, Var) :- lookup(Pos, Map, Var).

%  6. solution_count(+Puzzle, +Entradas, -N)
%     N ∈ {0, 1, 2}  –  para de contar ao atingir 2.
%     Usa findall + solve para coletar soluções; limita a 2.

solution_count(Puzzle, Entradas, N) :-
    findall(_, solve(Puzzle, Entradas, _), Sols),
    length(Sols, Total),
    (   Total >= 2
    ->  N = 2
    ;   N = Total
    ).


%  7. solve(+Puzzle, +Entradas, -Solucao)
%     Falha se não houver solução.
solve(Puzzle, Entradas, Solucao) :-
    setup(Puzzle, Entradas, VarMap, AllVars),
    labeling([ff], AllVars),
    maplist(pair_to_entry, VarMap, Solucao).

pair_to_entry(pos(R,C)-V, [R,C,V]).



%  8. check(+Puzzle, +Entradas, -Estado)
%     Estado = "solved" | "incomplete" | "inconsistent"
%
%     Monta as restrições via setup.  Se setup falha (entradas contradizem
%     as pistas), devolve "inconsistent".  Se as variáveis ficaram todas
%     ground, devolve "solved".  Senão, tenta labeling: se encontra
%     solução, devolve "incomplete"; se não, "inconsistent".

check(Puzzle, Entradas, Estado) :-
    (   setup(Puzzle, Entradas, _Map, Vs)
    ->  (   ground(Vs)
        ->  Estado = "solved"
        ;   copy_term(Vs, Vs2),
            (   labeling([ff], Vs2)
            ->  Estado = "incomplete"
            ;   Estado = "inconsistent"
            )
        )
    ;   Estado = "inconsistent"
    ).


%  9. hint(+Puzzle, +Entradas, -Resultado)
%     Resultado = ["hint", L, C, V]
%               | "complete"
%               | "inconsistent"
%               | "no_forced_hint"
%
%     Se tudo preenchido e correto → "complete".
%     Se tudo preenchido e errado  → "inconsistent".
%     Se setup falha               → "inconsistent".

hint(Puzzle, Entradas, Resultado) :-
    (   setup(Puzzle, Entradas, VarMap, Vars)
    ->  (   ground(Vars)
        ->  % Tudo preenchido.  Se setup não falhou e está ground,
            % as restrições CLP(FD) estão satisfeitas.
            Resultado = "complete"
        ;   copy_term(Vars, TestVars),
            (   labeling([ff], TestVars)
            ->  filled_set(Entradas, Filled),
                find_forced(VarMap, Filled, Resultado)
            ;   Resultado = "inconsistent"
            )
        )
    ;   Resultado = "inconsistent"
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
