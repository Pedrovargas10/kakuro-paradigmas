module View.Controls exposing
    ( Config
    , Status
    , Tone(..)
    , view
    , viewStatus
    )

import Html exposing (Attribute, Html, button, div, p, span, text)
import Html.Attributes exposing (attribute, class, disabled, type_)
import Html.Events exposing (onClick)
import Kakuro exposing (Digit)


type alias Config msg =
    { onDigit : Maybe (Digit -> msg)
    , onErase : Maybe msg
    , onCheck : Maybe msg
    , onHint : Maybe msg
    , onSolve : Maybe msg
    , onReset : Maybe msg
    , onNewGame : Maybe msg
    }


view : Config msg -> Html msg
view config =
    div [ class "controls" ]
        [ div [ class "digits", attribute "aria-label" "Dígitos" ]
            (List.map (digitButton config.onDigit) Kakuro.allDigits
                ++ [ actionButton "digit digit--erase" "Apagar" config.onErase ]
            )
        , div [ class "actions" ]
            [ actionButton "action action--primary" "Verificar" config.onCheck
            , actionButton "action" "Dica" config.onHint
            , actionButton "action" "Resolver" config.onSolve
            , actionButton "action" "Reiniciar" config.onReset
            , actionButton "action" "Novo jogo" config.onNewGame
            ]
        ]


digitButton : Maybe (Digit -> msg) -> Digit -> Html msg
digitButton onDigit digit =
    actionButton "digit"
        (String.fromInt (Kakuro.digitToInt digit))
        (Maybe.map (\toMsg -> toMsg digit) onDigit)


actionButton : String -> String -> Maybe msg -> Html msg
actionButton className label maybeMsg =
    button (type_ "button" :: class className :: clickOrDisabled maybeMsg)
        [ text label ]


clickOrDisabled : Maybe msg -> List (Attribute msg)
clickOrDisabled maybeMsg =
    case maybeMsg of
        Just msg ->
            [ onClick msg ]

        Nothing ->
            [ disabled True ]


type Tone
    = Neutral
    | Success
    | Warning
    | Danger


type alias Status msg =
    { tone : Tone
    , text : String
    , action : Maybe ( String, msg )
    }


viewStatus : Maybe (Status msg) -> Html msg
viewStatus maybeStatus =
    div [ class "status-area", attribute "aria-live" "polite" ]
        [ case maybeStatus of
            Just status ->
                p [ class ("status status--" ++ toneName status.tone) ]
                    [ span [] [ text status.text ]
                    , viewAction status.action
                    ]

            Nothing ->
                text ""
        ]


viewAction : Maybe ( String, msg ) -> Html msg
viewAction action =
    case action of
        Just ( label, msg ) ->
            button [ type_ "button", class "status__action", onClick msg ] [ text label ]

        Nothing ->
            text ""


toneName : Tone -> String
toneName tone =
    case tone of
        Neutral ->
            "neutral"

        Success ->
            "success"

        Warning ->
            "warning"

        Danger ->
            "danger"
