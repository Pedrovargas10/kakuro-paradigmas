module Api exposing
    ( CheckState(..)
    , Error(..)
    , HintResult(..)
    , boardDecoder
    , check
    , checkDecoder
    , describeError
    , encodeGame
    , generate
    , generateDecoder
    , hint
    , hintDecoder
    , isTransient
    , solve
    , solveDecoder
    )

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Kakuro exposing (Board, Cell(..), Entry)


type Error
    = Unreachable
    | TimedOut
    | Rejected String
    | Unavailable String
    | ServerFailure String
    | UnexpectedResponse String


type CheckState
    = Incomplete
    | Inconsistent
    | Solved


type HintResult
    = HintAt Entry
    | AlreadyComplete
    | HintInconsistent
    | NoForcedHint


describeError : Error -> String
describeError error =
    case error of
        Unreachable ->
            "Não foi possível falar com o servidor. Confira se o backend está rodando e tente de novo."

        TimedOut ->
            "O servidor demorou demais para responder. Tente de novo."

        Rejected detail ->
            detail

        Unavailable detail ->
            detail

        ServerFailure detail ->
            detail

        UnexpectedResponse detail ->
            "Resposta inesperada do servidor: " ++ detail


isTransient : Error -> Bool
isTransient error =
    case error of
        Unreachable ->
            True

        TimedOut ->
            True

        Unavailable _ ->
            True

        ServerFailure _ ->
            True

        Rejected _ ->
            False

        UnexpectedResponse _ ->
            False


generate : (Result Error Board -> msg) -> Cmd msg
generate toMsg =
    post "/api/generate" (Encode.object []) generateDecoder toMsg


check : (Result Error CheckState -> msg) -> Board -> Cmd msg
check toMsg board =
    post "/api/check" (encodeGame board) checkDecoder toMsg


solve : (Result Error (List Entry) -> msg) -> Board -> Cmd msg
solve toMsg board =
    post "/api/solve" (encodeGame board) solveDecoder toMsg


hint : (Result Error HintResult -> msg) -> Board -> Cmd msg
hint toMsg board =
    post "/api/hint" (encodeGame board) hintDecoder toMsg


post : String -> Encode.Value -> Decoder a -> (Result Error a -> msg) -> Cmd msg
post url body decoder toMsg =
    Http.request
        { method = "POST"
        , headers = []
        , url = url
        , body = Http.jsonBody body
        , expect = Http.expectStringResponse toMsg (readResponse decoder)
        , timeout = Just 30000
        , tracker = Nothing
        }


readResponse : Decoder a -> Http.Response String -> Result Error a
readResponse decoder response =
    case response of
        Http.GoodStatus_ _ body ->
            Decode.decodeString decoder body
                |> Result.mapError (Decode.errorToString >> UnexpectedResponse)

        Http.BadStatus_ { statusCode } body ->
            Err (errorFromStatus statusCode body)

        Http.Timeout_ ->
            Err TimedOut

        Http.NetworkError_ ->
            Err Unreachable

        Http.BadUrl_ url ->
            Err (UnexpectedResponse ("endereço inválido: " ++ url))


errorFromStatus : Int -> String -> Error
errorFromStatus status body =
    case ( status, Decode.decodeString (Decode.field "detail" Decode.string) body ) of
        ( 422, Ok detail ) ->
            Rejected detail

        ( 503, Ok detail ) ->
            Unavailable detail

        ( _, Ok detail ) ->
            ServerFailure detail

        ( _, Err _ ) ->
            Unreachable


encodeGame : Board -> Encode.Value
encodeGame board =
    Encode.object
        [ ( "puzzle", encodePuzzle board )
        , ( "entries", Encode.list encodeEntry (Kakuro.entries board) )
        ]


encodePuzzle : Board -> Encode.Value
encodePuzzle board =
    Encode.object
        [ ( "cells", Encode.list (Encode.list encodeCell) (Kakuro.rows board) ) ]


encodeCell : Cell -> Encode.Value
encodeCell cell =
    case cell of
        Block ->
            Encode.object [ kind "block" ]

        Playable _ ->
            Encode.object [ kind "playable" ]

        Clue clueSums ->
            Encode.object
                [ kind "clue"
                , ( "across", encodeSum (Kakuro.across clueSums) )
                , ( "down", encodeSum (Kakuro.down clueSums) )
                ]


kind : String -> ( String, Encode.Value )
kind name =
    ( "kind", Encode.string name )


encodeSum : Maybe Int -> Encode.Value
encodeSum sum =
    case sum of
        Just n ->
            Encode.int n

        Nothing ->
            Encode.null


encodeEntry : Entry -> Encode.Value
encodeEntry { position, digit } =
    let
        ( row, col ) =
            position
    in
    Encode.object
        [ ( "row", Encode.int row )
        , ( "col", Encode.int col )
        , ( "value", Encode.int (Kakuro.digitToInt digit) )
        ]


generateDecoder : Decoder Board
generateDecoder =
    Decode.at [ "puzzle", "cells" ] boardDecoder


checkDecoder : Decoder CheckState
checkDecoder =
    Decode.field "state" Decode.string
        |> Decode.andThen checkStateFromString


solveDecoder : Decoder (List Entry)
solveDecoder =
    Decode.field "solution" (Decode.list entryDecoder)


hintDecoder : Decoder HintResult
hintDecoder =
    Decode.field "kind" Decode.string
        |> Decode.andThen hintFromKind


boardDecoder : Decoder Board
boardDecoder =
    Decode.list (Decode.list cellDecoder)
        |> Decode.andThen (Kakuro.fromRows >> fromResult)


cellDecoder : Decoder Cell
cellDecoder =
    Decode.field "kind" Decode.string
        |> Decode.andThen cellFromKind


cellFromKind : String -> Decoder Cell
cellFromKind name =
    case name of
        "block" ->
            Decode.succeed Block

        "playable" ->
            Decode.succeed (Playable Nothing)

        "clue" ->
            Decode.map Clue sumsDecoder

        _ ->
            Decode.fail ("Tipo de casa desconhecido: " ++ name)


sumsDecoder : Decoder Kakuro.Sums
sumsDecoder =
    Decode.map2 Kakuro.sums
        (Decode.field "across" (Decode.nullable Decode.int))
        (Decode.field "down" (Decode.nullable Decode.int))
        |> Decode.andThen (fromMaybe "Casa de pista precisa de ao menos uma soma maior que zero.")


entryDecoder : Decoder Entry
entryDecoder =
    Decode.map3 toEntry
        (Decode.field "row" Decode.int)
        (Decode.field "col" Decode.int)
        (Decode.field "value" Decode.int)
        |> Decode.andThen (fromMaybe "Valor fora de 1 a 9.")


toEntry : Int -> Int -> Int -> Maybe Entry
toEntry row col value =
    Kakuro.digitFromInt value
        |> Maybe.map (Entry ( row, col ))


checkStateFromString : String -> Decoder CheckState
checkStateFromString state =
    case state of
        "incomplete" ->
            Decode.succeed Incomplete

        "inconsistent" ->
            Decode.succeed Inconsistent

        "solved" ->
            Decode.succeed Solved

        _ ->
            Decode.fail ("Estado desconhecido: " ++ state)


hintFromKind : String -> Decoder HintResult
hintFromKind name =
    case name of
        "hint" ->
            Decode.map HintAt entryDecoder

        "complete" ->
            Decode.succeed AlreadyComplete

        "inconsistent" ->
            Decode.succeed HintInconsistent

        "no_forced_hint" ->
            Decode.succeed NoForcedHint

        _ ->
            Decode.fail ("Resultado de dica desconhecido: " ++ name)


fromResult : Result String a -> Decoder a
fromResult result =
    case result of
        Ok value ->
            Decode.succeed value

        Err message ->
            Decode.fail message


fromMaybe : String -> Maybe a -> Decoder a
fromMaybe message maybe =
    case maybe of
        Just value ->
            Decode.succeed value

        Nothing ->
            Decode.fail message
