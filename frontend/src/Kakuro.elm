module Kakuro exposing
    ( Board
    , Cell(..)
    , Digit
    , Direction(..)
    , Editable
    , Entry
    , Position
    , Sums
    , across
    , allDigits
    , clear
    , conflicts
    , digitFromInt
    , digitToInt
    , down
    , editableAt
    , editablePosition
    , entries
    , fillEmptyCells
    , fillIfEmpty
    , firstEditable
    , fromRows
    , indexedRows
    , move
    , place
    , reset
    , rows
    , sums
    )

import Array exposing (Array)
import Set exposing (Set)


type Digit
    = Digit Int


digitFromInt : Int -> Maybe Digit
digitFromInt n =
    if 1 <= n && n <= 9 then
        Just (Digit n)

    else
        Nothing


digitToInt : Digit -> Int
digitToInt (Digit n) =
    n


allDigits : List Digit
allDigits =
    List.map Digit (List.range 1 9)


type Sums
    = AcrossOnly Int
    | DownOnly Int
    | AcrossAndDown Int Int


sums : Maybe Int -> Maybe Int -> Maybe Sums
sums maybeAcross maybeDown =
    case ( maybeAcross, maybeDown ) of
        ( Just a, Just d ) ->
            Maybe.map2 AcrossAndDown (positive a) (positive d)

        ( Just a, Nothing ) ->
            Maybe.map AcrossOnly (positive a)

        ( Nothing, Just d ) ->
            Maybe.map DownOnly (positive d)

        ( Nothing, Nothing ) ->
            Nothing


positive : Int -> Maybe Int
positive n =
    if n > 0 then
        Just n

    else
        Nothing


across : Sums -> Maybe Int
across clueSums =
    case clueSums of
        AcrossOnly a ->
            Just a

        DownOnly _ ->
            Nothing

        AcrossAndDown a _ ->
            Just a


down : Sums -> Maybe Int
down clueSums =
    case clueSums of
        AcrossOnly _ ->
            Nothing

        DownOnly d ->
            Just d

        AcrossAndDown _ d ->
            Just d


type alias Position =
    ( Int, Int )


type Cell
    = Block
    | Clue Sums
    | Playable (Maybe Digit)


type Board
    = Board (Array (Array Cell))


gridSize : Int
gridSize =
    6


fromRows : List (List Cell) -> Result String Board
fromRows cellRows =
    if List.length cellRows /= gridSize then
        Err "O tabuleiro deve ter 6 linhas."

    else if List.any (\row -> List.length row /= gridSize) cellRows then
        Err "Cada linha do tabuleiro deve ter 6 casas."

    else if not (List.any (List.any isPlayable) cellRows) then
        Err "O tabuleiro deve ter ao menos uma casa jogável."

    else
        Ok (Board (Array.fromList (List.map Array.fromList cellRows)))


rows : Board -> List (List Cell)
rows (Board grid) =
    Array.toList (Array.map Array.toList grid)


indexedRows : Board -> List (List ( Position, Cell ))
indexedRows board =
    List.indexedMap
        (\r row -> List.indexedMap (\c cell -> ( ( r, c ), cell )) row)
        (rows board)


cellAt : Position -> Board -> Maybe Cell
cellAt ( r, c ) (Board grid) =
    Array.get r grid |> Maybe.andThen (Array.get c)


isPlayable : Cell -> Bool
isPlayable cell =
    case cell of
        Playable _ ->
            True

        _ ->
            False


digitAt : Position -> Board -> Maybe Digit
digitAt position board =
    case cellAt position board of
        Just (Playable digit) ->
            digit

        _ ->
            Nothing


playablePositions : Board -> List Position
playablePositions board =
    indexedRows board
        |> List.concat
        |> List.filter (Tuple.second >> isPlayable)
        |> List.map Tuple.first


type Editable
    = Editable Position


editableAt : Position -> Board -> Maybe Editable
editableAt position board =
    case cellAt position board of
        Just (Playable _) ->
            Just (Editable position)

        _ ->
            Nothing


editablePosition : Editable -> Position
editablePosition (Editable position) =
    position


firstEditable : Board -> Maybe Editable
firstEditable board =
    playablePositions board
        |> List.head
        |> Maybe.map Editable


type Direction
    = Up
    | Down
    | Left
    | Right


neighbor : Direction -> Position -> Position
neighbor direction ( r, c ) =
    case direction of
        Up ->
            ( r - 1, c )

        Down ->
            ( r + 1, c )

        Left ->
            ( r, c - 1 )

        Right ->
            ( r, c + 1 )


move : Direction -> Editable -> Board -> Editable
move direction (Editable start) board =
    case nextPlayable direction start board of
        Just position ->
            Editable position

        Nothing ->
            Editable start


nextPlayable : Direction -> Position -> Board -> Maybe Position
nextPlayable direction from board =
    let
        next =
            neighbor direction from
    in
    case cellAt next board of
        Just (Playable _) ->
            Just next

        Just _ ->
            nextPlayable direction next board

        Nothing ->
            Nothing


type alias Entry =
    { position : Position
    , digit : Digit
    }


entries : Board -> List Entry
entries board =
    filledIn (playablePositions board) board


filledIn : List Position -> Board -> List Entry
filledIn positions board =
    List.filterMap
        (\position -> Maybe.map (Entry position) (digitAt position board))
        positions


place : Editable -> Digit -> Board -> Board
place (Editable position) digit =
    setDigit position (Just digit)


clear : Editable -> Board -> Board
clear (Editable position) =
    setDigit position Nothing


reset : Board -> Board
reset board =
    List.foldl (\position -> setDigit position Nothing) board (playablePositions board)


fillIfEmpty : Entry -> Board -> Board
fillIfEmpty entry board =
    if digitAt entry.position board == Nothing then
        setDigit entry.position (Just entry.digit) board

    else
        board


fillEmptyCells : List Entry -> Board -> Board
fillEmptyCells solution board =
    List.foldl fillIfEmpty board solution


setDigit : Position -> Maybe Digit -> Board -> Board
setDigit ( r, c ) digit (Board grid) =
    let
        write cell =
            case cell of
                Playable _ ->
                    Playable digit

                other ->
                    other
    in
    Board (updateAt r (updateAt c write) grid)


updateAt : Int -> (a -> a) -> Array a -> Array a
updateAt index change array =
    case Array.get index array of
        Just value ->
            Array.set index (change value) array

        Nothing ->
            array


type alias Run =
    { sum : Int
    , cells : List Position
    }


runs : Board -> List Run
runs board =
    indexedRows board
        |> List.concat
        |> List.concatMap (runsFromClue board)


runsFromClue : Board -> ( Position, Cell ) -> List Run
runsFromClue board ( position, cell ) =
    case cell of
        Clue clueSums ->
            List.filterMap identity
                [ Maybe.map (\sum -> Run sum (playableRun Right position board)) (across clueSums)
                , Maybe.map (\sum -> Run sum (playableRun Down position board)) (down clueSums)
                ]

        _ ->
            []


playableRun : Direction -> Position -> Board -> List Position
playableRun direction from board =
    let
        next =
            neighbor direction from
    in
    case cellAt next board of
        Just (Playable _) ->
            next :: playableRun direction next board

        _ ->
            []


conflicts : Board -> Set Position
conflicts board =
    runs board
        |> List.concatMap (conflictsInRun board)
        |> Set.fromList


conflictsInRun : Board -> Run -> List Position
conflictsInRun board run =
    let
        filled =
            filledIn run.cells board

        values =
            List.map (.digit >> digitToInt) filled

        total =
            List.sum values

        isComplete =
            List.length filled == List.length run.cells

        sumIsWrong =
            total > run.sum || (isComplete && total /= run.sum)

        isRepeated entry =
            List.length (List.filter ((==) (digitToInt entry.digit)) values) > 1
    in
    if sumIsWrong then
        List.map .position filled

    else
        filled
            |> List.filter isRepeated
            |> List.map .position
