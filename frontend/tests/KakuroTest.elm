module KakuroTest exposing (suite)

import Expect
import Kakuro exposing (Board, Cell(..), Direction(..), Position)
import Puzzle02 exposing (withBoard)
import Set
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Kakuro"
        [ digits
        , clueSums
        , boardShape
        , selection
        , navigation
        , editing
        , localConflicts
        ]


digits : Test
digits =
    describe "dígitos"
        [ test "aceita de 1 a 9" <|
            \_ ->
                List.range 1 9
                    |> List.filterMap Kakuro.digitFromInt
                    |> List.map Kakuro.digitToInt
                    |> Expect.equal (List.range 1 9)
        , test "recusa 0 e 10" <|
            \_ ->
                List.filterMap Kakuro.digitFromInt [ 0, 10, -1 ]
                    |> Expect.equal []
        , test "allDigits lista de 1 a 9 em ordem" <|
            \_ ->
                List.map Kakuro.digitToInt Kakuro.allDigits
                    |> Expect.equal (List.range 1 9)
        ]


clueSums : Test
clueSums =
    describe "pistas"
        [ test "precisa de ao menos uma soma" <|
            \_ -> Kakuro.sums Nothing Nothing |> Expect.equal Nothing
        , test "recusa soma zero ou negativa, mesmo junto de uma válida" <|
            \_ ->
                [ Kakuro.sums (Just 0) Nothing, Kakuro.sums (Just 3) (Just -1) ]
                    |> Expect.equal [ Nothing, Nothing ]
        , test "guarda cada soma na sua direção" <|
            \_ ->
                Kakuro.sums (Just 8) (Just 7)
                    |> Maybe.map (\s -> ( Kakuro.across s, Kakuro.down s ))
                    |> Expect.equal (Just ( Just 8, Just 7 ))
        ]


boardShape : Test
boardShape =
    describe "formato do tabuleiro"
        [ test "aceita a fixture 6x6" <|
            \_ -> withBoard (\_ -> Expect.pass)
        , test "recusa 5 linhas" <|
            \_ -> Kakuro.fromRows (List.take 5 Puzzle02.rows) |> Expect.err
        , test "recusa linha com 5 casas" <|
            \_ -> Kakuro.fromRows (List.map (List.take 5) Puzzle02.rows) |> Expect.err
        , test "recusa tabuleiro sem casa jogável" <|
            \_ -> Kakuro.fromRows (List.repeat 6 (List.repeat 6 Block)) |> Expect.err
        ]


selection : Test
selection =
    describe "seleção"
        [ test "só casas jogáveis são editáveis" <|
            \_ ->
                withBoard <|
                    \board ->
                        [ ( 0, 0 ), ( 0, 1 ), ( 1, 1 ), ( 9, 9 ) ]
                            |> List.map (\position -> Kakuro.editableAt position board /= Nothing)
                            |> Expect.equal [ False, False, True, False ]
        , test "a partida começa na primeira casa jogável" <|
            \_ ->
                withBoard <|
                    \board ->
                        Kakuro.firstEditable board
                            |> Maybe.map Kakuro.editablePosition
                            |> Expect.equal (Just ( 1, 1 ))
        ]


navigation : Test
navigation =
    describe "setas"
        [ test "para a direita pula a pista" <|
            \_ -> moveFrom ( 1, 2 ) Right |> Expect.equal (Just ( 1, 4 ))
        , test "para baixo vai à vizinha" <|
            \_ -> moveFrom ( 1, 2 ) Down |> Expect.equal (Just ( 2, 2 ))
        , test "na borda fica onde está" <|
            \_ -> moveFrom ( 1, 1 ) Up |> Expect.equal (Just ( 1, 1 ))
        , test "sem casa jogável adiante fica onde está" <|
            \_ -> moveFrom ( 2, 1 ) Left |> Expect.equal (Just ( 2, 1 ))
        ]


moveFrom : Position -> Direction -> Maybe Position
moveFrom position direction =
    Kakuro.fromRows Puzzle02.rows
        |> Result.toMaybe
        |> Maybe.andThen
            (\board ->
                Kakuro.editableAt position board
                    |> Maybe.map (\cell -> Kakuro.editablePosition (Kakuro.move direction cell board))
            )


editing : Test
editing =
    describe "preenchimento"
        [ test "tabuleiro novo não tem entradas" <|
            \_ -> withBoard (Kakuro.entries >> Expect.equal [])
        , test "place cria a entrada e clear a remove" <|
            \_ ->
                withBoard <|
                    \board ->
                        let
                            placed =
                                put ( 1, 1 ) 9 board
                        in
                        ( values placed, values (erase ( 1, 1 ) placed) )
                            |> Expect.equal ( [ ( ( 1, 1 ), 9 ) ], [] )
        , test "reset limpa o preenchimento e mantém pistas e bloqueios" <|
            \_ -> withBoard (\board -> Kakuro.reset (Puzzle02.solved board) |> Expect.equal board)
        , test "a solução preenche todas as casas" <|
            \_ -> withBoard (Puzzle02.solved >> Kakuro.entries >> List.length >> Expect.equal 11)
        , test "dica e solução não sobrescrevem o jogador" <|
            \_ ->
                withBoard <|
                    \board ->
                        put ( 1, 1 ) 1 board
                            |> Puzzle02.solved
                            |> values
                            |> List.member ( ( 1, 1 ), 1 )
                            |> Expect.equal True
        ]


localConflicts : Test
localConflicts =
    describe "conflitos locais"
        [ test "solução correta não tem conflito" <|
            \_ -> withBoard (Puzzle02.solved >> Kakuro.conflicts >> Expect.equal Set.empty)
        , test "dígito repetido marca as duas casas" <|
            \_ -> conflictsAfter [ ( ( 1, 1 ), 9 ), ( ( 1, 2 ), 9 ) ] |> Expect.equal [ ( 1, 1 ), ( 1, 2 ) ]
        , test "soma parcial acima da pista" <|
            \_ -> conflictsAfter [ ( ( 1, 1 ), 9 ), ( ( 1, 2 ), 8 ) ] |> Expect.equal [ ( 1, 1 ), ( 1, 2 ) ]
        , test "sequência cheia com soma errada" <|
            \_ -> conflictsAfter [ ( ( 1, 1 ), 7 ), ( ( 1, 2 ), 8 ) ] |> Expect.equal [ ( 1, 1 ), ( 1, 2 ) ]
        , test "par que fecha a soma não é conflito" <|
            \_ -> conflictsAfter [ ( ( 1, 1 ), 9 ), ( ( 1, 2 ), 7 ) ] |> Expect.equal []
        , test "casa vazia não conta para a soma completa" <|
            \_ -> conflictsAfter [ ( ( 2, 1 ), 8 ) ] |> Expect.equal []
        ]


conflictsAfter : List ( Position, Int ) -> List Position
conflictsAfter moves =
    Kakuro.fromRows Puzzle02.rows
        |> Result.map (\board -> List.foldl (\( position, value ) -> put position value) board moves)
        |> Result.map (Kakuro.conflicts >> Set.toList)
        |> Result.withDefault []


put : Position -> Int -> Board -> Board
put position value board =
    case ( Kakuro.editableAt position board, Kakuro.digitFromInt value ) of
        ( Just cell, Just digit ) ->
            Kakuro.place cell digit board

        _ ->
            board


erase : Position -> Board -> Board
erase position board =
    case Kakuro.editableAt position board of
        Just cell ->
            Kakuro.clear cell board

        Nothing ->
            board


values : Board -> List ( Position, Int )
values board =
    List.map (\entry -> ( entry.position, Kakuro.digitToInt entry.digit )) (Kakuro.entries board)
