module Main exposing (main)

import Api
import Browser
import Browser.Events
import Html exposing (Html, div, h1, header, main_, p, text)
import Html.Attributes exposing (class)
import Json.Decode as Decode exposing (Decoder)
import Kakuro exposing (Board, Digit, Direction(..), Editable, Entry, Position)
import View.Board as Board
import View.Controls as Controls exposing (Tone(..))


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( Loading, Api.generate GotPuzzle )
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type Model
    = Loading
    | LoadFailed Api.Error
    | InGame Game


type alias Game =
    { board : Board
    , selection : Maybe Editable
    , phase : Phase
    , notice : Notice
    }


type Phase
    = Ready Stage
    | Waiting Request Stage


type Stage
    = Playing
    | Finished


type Request
    = Generating
    | Checking
    | Hinting
    | Solving


type Notice
    = Quiet
    | Checked Api.CheckState
    | Hinted Api.HintResult
    | SolutionRevealed
    | Failed Request Api.Error


type Msg
    = NewGame
    | GotPuzzle (Result Api.Error Board)
    | SelectCell Position
    | PressDigit Digit
    | Erase
    | Move Direction
    | Reset
    | Check
    | GotCheck (Result Api.Error Api.CheckState)
    | AskHint
    | GotHint (Result Api.Error Api.HintResult)
    | Solve
    | GotSolution (Result Api.Error (List Entry))
    | Retry Request


newGame : Board -> Game
newGame board =
    { board = board
    , selection = Kakuro.firstEditable board
    , phase = Ready Playing
    , notice = Quiet
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case model of
        InGame game ->
            Tuple.mapFirst InGame (updateGame msg game)

        _ ->
            updateLoading msg model


updateLoading : Msg -> Model -> ( Model, Cmd Msg )
updateLoading msg model =
    case msg of
        GotPuzzle (Ok board) ->
            ( InGame (newGame board), Cmd.none )

        GotPuzzle (Err error) ->
            ( LoadFailed error, Cmd.none )

        Retry Generating ->
            ( Loading, Api.generate GotPuzzle )

        _ ->
            ( model, Cmd.none )


updateGame : Msg -> Game -> ( Game, Cmd Msg )
updateGame msg game =
    case msg of
        SelectCell position ->
            ( select position game, Cmd.none )

        PressDigit digit ->
            ( edit (\cell -> Kakuro.place cell digit) game, Cmd.none )

        Erase ->
            ( edit Kakuro.clear game, Cmd.none )

        Move direction ->
            ( moveSelection direction game, Cmd.none )

        Reset ->
            ( reset game, Cmd.none )

        NewGame ->
            start Generating game

        Check ->
            start Checking game

        AskHint ->
            start Hinting game

        Solve ->
            start Solving game

        Retry request ->
            start request game

        GotPuzzle result ->
            ( receive Generating (applyPuzzle result) game, Cmd.none )

        GotCheck result ->
            ( receive Checking (applyCheck result) game, Cmd.none )

        GotHint result ->
            ( receive Hinting (applyHint result) game, Cmd.none )

        GotSolution result ->
            ( receive Solving (applySolution result) game, Cmd.none )


select : Position -> Game -> Game
select position game =
    case Kakuro.editableAt position game.board of
        Just cell ->
            { game | selection = Just cell }

        Nothing ->
            game


moveSelection : Direction -> Game -> Game
moveSelection direction game =
    { game | selection = Maybe.map (\cell -> Kakuro.move direction cell game.board) game.selection }


edit : (Editable -> Board -> Board) -> Game -> Game
edit change game =
    case ( game.phase, game.selection ) of
        ( Ready Playing, Just cell ) ->
            { game | board = change cell game.board, notice = Quiet }

        _ ->
            game


reset : Game -> Game
reset game =
    if isReady game.phase then
        { game | board = Kakuro.reset game.board, phase = Ready Playing, notice = Quiet }

    else
        game


isReady : Phase -> Bool
isReady phase =
    case phase of
        Ready _ ->
            True

        Waiting _ _ ->
            False


canStart : Request -> Phase -> Bool
canStart request phase =
    case request of
        Generating ->
            isReady phase

        _ ->
            phase == Ready Playing


start : Request -> Game -> ( Game, Cmd Msg )
start request game =
    case game.phase of
        Ready stage ->
            if canStart request game.phase then
                ( { game | phase = Waiting request stage }, send request game.board )

            else
                ( game, Cmd.none )

        Waiting _ _ ->
            ( game, Cmd.none )


send : Request -> Board -> Cmd Msg
send request board =
    case request of
        Generating ->
            Api.generate GotPuzzle

        Checking ->
            Api.check GotCheck board

        Hinting ->
            Api.hint GotHint board

        Solving ->
            Api.solve GotSolution board


receive : Request -> (Game -> Game) -> Game -> Game
receive expected apply game =
    case game.phase of
        Waiting pending stage ->
            if pending == expected then
                apply { game | phase = Ready stage }

            else
                game

        Ready _ ->
            game


applyPuzzle : Result Api.Error Board -> Game -> Game
applyPuzzle result game =
    case result of
        Ok board ->
            newGame board

        Err error ->
            fail Generating error game


applyCheck : Result Api.Error Api.CheckState -> Game -> Game
applyCheck result game =
    case result of
        Ok Api.Solved ->
            finish (Checked Api.Solved) game

        Ok state ->
            { game | notice = Checked state }

        Err error ->
            fail Checking error game


applyHint : Result Api.Error Api.HintResult -> Game -> Game
applyHint result game =
    case result of
        Ok (Api.HintAt entry) ->
            revealHint entry game

        Ok other ->
            { game | notice = Hinted other }

        Err error ->
            fail Hinting error game


revealHint : Entry -> Game -> Game
revealHint entry game =
    { game
        | board = Kakuro.fillIfEmpty entry game.board
        , selection = Kakuro.editableAt entry.position game.board
        , notice = Hinted (Api.HintAt entry)
    }


applySolution : Result Api.Error (List Entry) -> Game -> Game
applySolution result game =
    case result of
        Ok solution ->
            finish SolutionRevealed { game | board = Kakuro.fillEmptyCells solution game.board }

        Err error ->
            fail Solving error game


finish : Notice -> Game -> Game
finish notice game =
    { game | phase = Ready Finished, notice = notice }


fail : Request -> Api.Error -> Game -> Game
fail request error game =
    { game | notice = Failed request error }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        InGame _ ->
            Browser.Events.onKeyDown keyDecoder

        _ ->
            Sub.none


keyDecoder : Decoder Msg
keyDecoder =
    Decode.map4 keyPress
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "altKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        |> Decode.andThen
            (\maybeMsg ->
                case maybeMsg of
                    Just msg ->
                        Decode.succeed msg

                    Nothing ->
                        Decode.fail "tecla sem ação"
            )


keyPress : String -> Bool -> Bool -> Bool -> Maybe Msg
keyPress key ctrl alt meta =
    if ctrl || alt || meta then
        Nothing

    else
        keyToMsg key


keyToMsg : String -> Maybe Msg
keyToMsg key =
    case key of
        "ArrowUp" ->
            Just (Move Up)

        "ArrowDown" ->
            Just (Move Down)

        "ArrowLeft" ->
            Just (Move Left)

        "ArrowRight" ->
            Just (Move Right)

        "Backspace" ->
            Just Erase

        "Delete" ->
            Just Erase

        _ ->
            String.toInt key
                |> Maybe.andThen Kakuro.digitFromInt
                |> Maybe.map PressDigit


view : Model -> Html Msg
view model =
    main_ [ class "app" ]
        [ viewHeader
        , viewBody model
        ]


viewHeader : Html msg
viewHeader =
    header []
        [ h1 [] [ text "Kakuro" ]
        , p [ class "rules" ]
            [ text "Preencha as casas brancas com dígitos de 1 a 9. Cada pista é a soma da sequência à direita (acima da diagonal) ou abaixo (abaixo da diagonal), sem repetir dígitos na sequência." ]
        ]


viewBody : Model -> Html Msg
viewBody model =
    case model of
        Loading ->
            Controls.viewStatus (Just (status Neutral "Gerando um puzzle 6×6…"))

        LoadFailed error ->
            Controls.viewStatus (Just (withRetry Generating (status Danger (Api.describeError error))))

        InGame game ->
            viewGame game


viewGame : Game -> Html Msg
viewGame game =
    div [ class "layout" ]
        [ Board.view
            { selected = Maybe.map Kakuro.editablePosition game.selection
            , conflicts = Kakuro.conflicts game.board
            , onSelect = SelectCell
            }
            game.board
        , div [ class "side" ]
            [ Controls.view (controlsFor game)
            , Controls.viewStatus (statusFor game)
            ]
        ]


controlsFor : Game -> Controls.Config Msg
controlsFor game =
    let
        canEdit =
            game.phase == Ready Playing && game.selection /= Nothing

        enabledIf condition msg =
            if condition then
                Just msg

            else
                Nothing

        ifCanStart request msg =
            enabledIf (canStart request game.phase) msg
    in
    { onDigit = enabledIf canEdit PressDigit
    , onErase = enabledIf canEdit Erase
    , onCheck = ifCanStart Checking Check
    , onHint = ifCanStart Hinting AskHint
    , onSolve = ifCanStart Solving Solve
    , onReset = enabledIf (isReady game.phase) Reset
    , onNewGame = ifCanStart Generating NewGame
    }


statusFor : Game -> Maybe (Controls.Status Msg)
statusFor game =
    case game.phase of
        Waiting request _ ->
            Just (status Neutral (waitingText request))

        Ready _ ->
            noticeStatus game.notice


waitingText : Request -> String
waitingText request =
    case request of
        Generating ->
            "Gerando um puzzle novo…"

        Checking ->
            "Verificando…"

        Hinting ->
            "Procurando uma casa com valor forçado…"

        Solving ->
            "Resolvendo…"


noticeStatus : Notice -> Maybe (Controls.Status Msg)
noticeStatus notice =
    case notice of
        Quiet ->
            Nothing

        Checked state ->
            Just (checkStatus state)

        Hinted result ->
            Just (hintStatus result)

        SolutionRevealed ->
            Just (status Success "Solução exibida. Os números que você digitou foram mantidos.")

        Failed request error ->
            Just (failureStatus request error)


checkStatus : Api.CheckState -> Controls.Status msg
checkStatus state =
    case state of
        Api.Incomplete ->
            status Neutral "Até aqui está certo, mas ainda há casas vazias."

        Api.Inconsistent ->
            status Warning "Há um erro: nenhuma solução é compatível com o preenchimento."

        Api.Solved ->
            status Success "Resolvido! Todas as somas conferem."


hintStatus : Api.HintResult -> Controls.Status msg
hintStatus result =
    case result of
        Api.HintAt entry ->
            status Success (hintText entry)

        Api.AlreadyComplete ->
            status Neutral "Todas as casas já estão preenchidas. Use Verificar."

        Api.HintInconsistent ->
            status Warning "Há um erro no preenchimento: nenhuma solução é compatível, então não há dica."

        Api.NoForcedHint ->
            status Neutral "Nenhuma casa vazia tem valor forçado agora."


hintText : Entry -> String
hintText { position, digit } =
    let
        ( row, col ) =
            position
    in
    "Dica: a casa da linha "
        ++ String.fromInt (row + 1)
        ++ ", coluna "
        ++ String.fromInt (col + 1)
        ++ " só pode ser "
        ++ String.fromInt (Kakuro.digitToInt digit)
        ++ "."


failureStatus : Request -> Api.Error -> Controls.Status Msg
failureStatus request error =
    if Api.isTransient error then
        withRetry request (status Danger (Api.describeError error))

    else
        status Warning (Api.describeError error)


status : Tone -> String -> Controls.Status msg
status tone message =
    { tone = tone, text = message, action = Nothing }


withRetry : Request -> Controls.Status Msg -> Controls.Status Msg
withRetry request base =
    { base | action = Just ( "Tentar de novo", Retry request ) }
