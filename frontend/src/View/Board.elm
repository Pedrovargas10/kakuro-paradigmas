module View.Board exposing (Config, view)

import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (attribute, class, classList, type_)
import Html.Events exposing (onClick)
import Kakuro exposing (Board, Cell(..), Digit, Position, Sums)
import Set exposing (Set)


type alias Config msg =
    { selected : Maybe Position
    , conflicts : Set Position
    , onSelect : Position -> msg
    }


view : Config msg -> Board -> Html msg
view config board =
    div [ class "board", attribute "aria-label" "Tabuleiro do Kakuro" ]
        (List.map (viewCell config) (List.concat (Kakuro.indexedRows board)))


viewCell : Config msg -> ( Position, Cell ) -> Html msg
viewCell config ( position, cell ) =
    case cell of
        Block ->
            div [ class "cell cell--block" ] []

        Clue clueSums ->
            viewClue clueSums

        Playable digit ->
            viewPlayable config position digit


viewClue : Sums -> Html msg
viewClue clueSums =
    div [ class "cell cell--clue" ]
        [ viewSum "clue__across" "soma à direita" (Kakuro.across clueSums)
        , viewSum "clue__down" "soma abaixo" (Kakuro.down clueSums)
        ]


viewSum : String -> String -> Maybe Int -> Html msg
viewSum className label maybeSum =
    case maybeSum of
        Just sum ->
            span [ class className, attribute "aria-label" (label ++ " " ++ String.fromInt sum) ]
                [ text (String.fromInt sum) ]

        Nothing ->
            text ""


viewPlayable : Config msg -> Position -> Maybe Digit -> Html msg
viewPlayable config position digit =
    button
        [ type_ "button"
        , class "cell cell--playable"
        , classList
            [ ( "is-selected", config.selected == Just position )
            , ( "is-conflict", Set.member position config.conflicts )
            ]
        , onClick (config.onSelect position)
        , attribute "aria-label" (describeCell position digit)
        ]
        [ text (digitText digit) ]


digitText : Maybe Digit -> String
digitText digit =
    case digit of
        Just d ->
            String.fromInt (Kakuro.digitToInt d)

        Nothing ->
            ""


describeCell : Position -> Maybe Digit -> String
describeCell ( row, col ) digit =
    "Linha "
        ++ String.fromInt (row + 1)
        ++ ", coluna "
        ++ String.fromInt (col + 1)
        ++ ": "
        ++ (case digit of
                Just d ->
                    String.fromInt (Kakuro.digitToInt d)

                Nothing ->
                    "vazia"
           )
