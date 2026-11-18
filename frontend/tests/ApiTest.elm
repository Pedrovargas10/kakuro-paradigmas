module ApiTest exposing (suite)

import Api exposing (CheckState(..), HintResult(..))
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Kakuro
import Puzzle02 exposing (withBoard)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Api"
        [ puzzleDecoding
        , responseDecoding
        , requestEncoding
        ]


puzzleDecoding : Test
puzzleDecoding =
    describe "decoder do puzzle"
        [ test "lê a fixture puzzle_02" <|
            \_ ->
                withBoard
                    (\board ->
                        Decode.decodeString Api.boardDecoder Puzzle02.json
                            |> Expect.equal (Ok board)
                    )
        , test "lê o puzzle dentro da resposta de generate" <|
            \_ ->
                Decode.decodeString Api.generateDecoder ("{\"puzzle\":{\"cells\":" ++ Puzzle02.json ++ "}}")
                    |> Expect.ok
        , test "recusa tipo de casa desconhecido" <|
            \_ -> decodeWithFirstCell """{"kind":"white"}""" |> Expect.err
        , test "recusa pista sem soma" <|
            \_ -> decodeWithFirstCell """{"kind":"clue","across":null,"down":null}""" |> Expect.err
        , test "recusa pista com soma zero" <|
            \_ -> decodeWithFirstCell """{"kind":"clue","across":0,"down":null}""" |> Expect.err
        , test "recusa grade que não é 6x6" <|
            \_ ->
                Decode.decodeString Api.boardDecoder "[[{\"kind\":\"playable\"}]]"
                    |> Expect.err
        ]


decodeWithFirstCell : String -> Result Decode.Error Kakuro.Board
decodeWithFirstCell cell =
    Decode.decodeString Api.boardDecoder
        (String.replace "[[{\"kind\":\"block\"}" ("[[" ++ cell) Puzzle02.json)


responseDecoding : Test
responseDecoding =
    describe "respostas"
        [ test "os três estados de check" <|
            \_ ->
                [ "incomplete", "inconsistent", "solved" ]
                    |> List.map (\state -> Decode.decodeString Api.checkDecoder ("{\"state\":\"" ++ state ++ "\"}"))
                    |> Expect.equal [ Ok Incomplete, Ok Inconsistent, Ok Solved ]
        , test "check com estado desconhecido falha" <|
            \_ -> Decode.decodeString Api.checkDecoder "{\"state\":\"maybe\"}" |> Expect.err
        , test "dica com casa e valor" <|
            \_ ->
                Decode.decodeString Api.hintDecoder "{\"kind\":\"hint\",\"row\":1,\"col\":4,\"value\":5}"
                    |> Result.map hintPosition
                    |> Expect.equal (Ok (Just ( ( 1, 4 ), 5 )))
        , test "os três motivos de não haver dica" <|
            \_ ->
                [ "complete", "inconsistent", "no_forced_hint" ]
                    |> List.map (\kind -> Decode.decodeString Api.hintDecoder ("{\"kind\":\"" ++ kind ++ "\"}"))
                    |> Expect.equal [ Ok AlreadyComplete, Ok HintInconsistent, Ok NoForcedHint ]
        , test "dica com valor fora de 1 a 9 falha" <|
            \_ ->
                Decode.decodeString Api.hintDecoder "{\"kind\":\"hint\",\"row\":1,\"col\":4,\"value\":10}"
                    |> Expect.err
        , test "solução vira a lista de entradas" <|
            \_ ->
                Decode.decodeString Api.solveDecoder "{\"solution\":[{\"row\":1,\"col\":1,\"value\":9},{\"row\":1,\"col\":2,\"value\":7}]}"
                    |> Result.map List.length
                    |> Expect.equal (Ok 2)
        ]


hintPosition : HintResult -> Maybe ( ( Int, Int ), Int )
hintPosition result =
    case result of
        HintAt entry ->
            Just ( entry.position, Kakuro.digitToInt entry.digit )

        _ ->
            Nothing


requestEncoding : Test
requestEncoding =
    describe "corpo de check, solve e hint"
        [ test "o puzzle enviado decodifica de volta sem os dígitos" <|
            \_ ->
                withBoard <|
                    \board ->
                        Api.encodeGame (Puzzle02.solved board)
                            |> Decode.decodeValue (Decode.at [ "puzzle", "cells" ] Api.boardDecoder)
                            |> Expect.equal (Ok board)
        , test "casa jogável vai só com kind" <|
            \_ ->
                withBoard <|
                    \board ->
                        Api.encodeGame (Puzzle02.solved board)
                            |> Decode.decodeValue (Decode.at [ "puzzle", "cells" ] (Decode.index 1 (Decode.index 1 (Decode.keyValuePairs Decode.value))))
                            |> Result.map (List.map Tuple.first)
                            |> Expect.equal (Ok [ "kind" ])
        , test "pista sem soma numa direção vai como null" <|
            \_ ->
                withBoard <|
                    \board ->
                        Api.encodeGame board
                            |> Encode.encode 0
                            |> String.contains "{\"kind\":\"clue\",\"across\":null,\"down\":17}"
                            |> Expect.equal True
        , test "entries leva só as casas preenchidas" <|
            \_ ->
                withBoard <|
                    \board ->
                        Api.encodeGame (Kakuro.fillEmptyCells (List.take 1 Puzzle02.solution) board)
                            |> Encode.encode 0
                            |> String.contains "\"entries\":[{\"row\":1,\"col\":1,\"value\":9}]"
                            |> Expect.equal True
        ]
