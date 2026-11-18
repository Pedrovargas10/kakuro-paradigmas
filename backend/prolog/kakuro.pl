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
    sequences(Puzzle, HSeqs, VSeqs),
    append(HSeqs, VSeqs, Seqs).

sequences(Puzzle, HSeqs, VSeqs) :-
    h_seqs(Puzzle, 0, HSeqs),
    transp(Puzzle, TPuzzle),
    v_seqs(TPuzzle, 0, VSeqs).

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
    length(Cells, Len),
    (   between(2, 5, Len)
    ->  Seqs = [seq(A, Cells)|More]
    ;   throw(error(domain_error(kakuro_sequence, seq(horizontal, R, C, A, Cells)),
                    context(row_seqs/4, 'sequência horizontal deve ter entre 2 e 5 casas')))
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
    length(Cells, Len),
    (   between(2, 5, Len)
    ->  Seqs = [seq(D, Cells)|More]
    ;   throw(error(domain_error(kakuro_sequence, seq(vertical, R, C, D, Cells)),
                    context(col_seqs/4, 'sequência vertical deve ter entre 2 e 5 casas')))
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
    sequences(NPuzzle, HSeqs, VSeqs),
    validate_white_coverage(Positions, HSeqs, VSeqs),
    append(HSeqs, VSeqs, Seqs),
    make_varmap(Positions, VarMap, AllVars),
    AllVars ins 1..9,
    apply_entries(Entradas, VarMap),
    post_constraints(Seqs, VarMap).

validate_white_coverage(Positions, HSeqs, VSeqs) :-
    seq_positions(HSeqs, HPos),
    seq_positions(VSeqs, VPos),
    forall(member(Pos, Positions),
           (   memberchk(Pos, HPos),
               memberchk(Pos, VPos)
           ->  true
           ;   throw(error(domain_error(kakuro_white_cell, Pos),
                           context(validate_white_coverage/3,
                                   'casa branca deve pertencer a uma sequência horizontal e uma vertical')))
           )).

seq_positions(Seqs, Positions) :-
    findall(Pos, (member(seq(_, Cells), Seqs), member(Pos, Cells)), Positions).

make_varmap([], [], []).
make_varmap([P|Ps], [P-V|Map], [V|Vs]) :-
    make_varmap(Ps, Map, Vs).

lookup(Pos, [Pos-V|_], V) :- !.
lookup(Pos, [_|Rest], V)  :- lookup(Pos, Rest, V).

apply_entries(Entradas, Map) :-
    (   is_list(Entradas)
    ->  apply_entries(Entradas, Map, [])
    ;   throw(error(domain_error(kakuro_entries, Entradas),
                    context(apply_entries/2, 'entradas devem ser uma lista')))
    ).

apply_entries([], _, _).
apply_entries([Entry|Es], Map, Seen) :-
    (   Entry = [L, C, Val],
        integer(L), integer(C), integer(Val),
        between(1, 9, Val),
        lookup(pos(L, C), Map, Var)
    ->  (   memberchk(pos(L, C), Seen)
        ->  throw(error(domain_error(kakuro_duplicate_entry, Entry),
                        context(apply_entries/3, 'posição duplicada nas entradas')))
        ;   Var #= Val,
            apply_entries(Es, Map, [pos(L, C)|Seen])
        )
    ;   throw(error(domain_error(kakuro_entry, Entry),
                    context(apply_entries/3, 'entrada inválida ou fora de casa branca')))
    ).

post_constraints([], _).
post_constraints([seq(Clue, Cells)|Seqs], Map) :-
    maplist(lookup_in(Map), Cells, Vars),
    all_distinct(Vars),
    sum(Vars, #=, Clue),
    post_constraints(Seqs, Map).

lookup_in(Map, Pos, Var) :- lookup(Pos, Map, Var).


%  6. solution_count(+Puzzle, +Entradas, -N)
%     N ∈ {0, 1, 2}.  findnsols/4 para a busca assim que acha 2 soluções,
%     então o gerador não precisa enumerar todas para checar unicidade.
%     Erros de formato lançados por setup/4 sobem normalmente.
solution_count(Puzzle, Entradas, N) :-
    once(findnsols(2, Sol, solve(Puzzle, Entradas, Sol), Sols)),
    length(Sols, N).


%  7. solve(+Puzzle, +Entradas, -Solucao)
%     Falha se não houver solução.
solve(Puzzle, Entradas, Solucao) :-
    setup(Puzzle, Entradas, VarMap, AllVars),
    labeling([ff], AllVars),
    maplist(pair_to_entry, VarMap, Solucao).

pair_to_entry(pos(R,C)-V, [R,C,V]).

all_filled(VarMap, Entradas) :-
    filled_set(Entradas, Filled),
    forall(member(Pos-_, VarMap), memberchk(Pos, Filled)).

filled_set([], []).
filled_set([[L,C,_]|Es], [pos(L,C)|Rest]) :-
    filled_set(Es, Rest).


%  8. check(+Puzzle, +Entradas, -Estado)
%     Estado = "solved" | "incomplete" | "inconsistent"

check(Puzzle, Entradas, Estado) :-
    (   setup(Puzzle, Entradas, VarMap, Vars)
    ->  (   all_filled(VarMap, Entradas)
        ->  Estado = "solved"
        ;   once(labeling([ff], Vars))
        ->  Estado = "incomplete"
        ;   Estado = "inconsistent"
        )
    ;   Estado = "inconsistent"
    ).


%  9. hint(+Puzzle, +Entradas, -Resultado)

hint(Puzzle, Entradas, Resultado) :-
    (   setup(Puzzle, Entradas, VarMap, _)
    ->  (   all_filled(VarMap, Entradas)
        ->  Resultado = "complete"
        ;   once(solve(Puzzle, Entradas, Candidata))
        ->  filled_set(Entradas, Filled),
            first_forced(Puzzle, Entradas, Filled, Candidata, Resultado)
        ;   Resultado = "inconsistent"
        )
    ;   Resultado = "inconsistent"
    ).

%  Percorre a solução candidata e devolve a primeira casa vazia forçada.
first_forced(_, _, _, [], "no_forced_hint").
first_forced(Puzzle, Entradas, Filled, [[R,C,V]|Rest], Resultado) :-
    (   \+ memberchk(pos(R,C), Filled),
        \+ alternative_exists(Puzzle, Entradas, R, C, V)
    ->  Resultado = ["hint", R, C, V]
    ;   first_forced(Puzzle, Entradas, Filled, Rest, Resultado)
    ).

%  Existe solução em que a casa (R,C) tem valor diferente de V?
alternative_exists(Puzzle, Entradas, R, C, V) :-
    setup(Puzzle, Entradas, VarMap, Vars),
    lookup(pos(R,C), VarMap, X),
    X #\= V,
    once(labeling([ff], Vars)).
