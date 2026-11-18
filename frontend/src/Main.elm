module Main exposing (main)

import Browser
import Html exposing (Html, h1, text)


type alias Model =
    ()


type Msg
    = NoOp


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( (), Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        , view = view
        }


view : Model -> Html Msg
view _ =
    h1 [] [ text "Kakuro" ]
