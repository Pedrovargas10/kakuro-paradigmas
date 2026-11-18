module Puzzle02 exposing (json, rows, solution, solved, withBoard)

import Expect exposing (Expectation)
import Kakuro exposing (Board, Cell(..), Entry)


rows : List (List Cell)
rows =
    let
        b =
            Block

        w =
            Playable Nothing

        clue across down =
            case Kakuro.sums across down of
                Just clueSums ->
                    Clue clueSums

                Nothing ->
                    Block
    in
    [ [ b, clue Nothing (Just 17), clue Nothing (Just 18), b, clue Nothing (Just 7), clue Nothing (Just 4) ]
    , [ clue (Just 16) Nothing, w, w, clue (Just 8) (Just 7), w, w ]
    , [ clue (Just 21) Nothing, w, w, w, w, w ]
    , [ b, clue (Just 8) Nothing, w, w, b, b ]
    , List.repeat 6 b
    , List.repeat 6 b
    ]


solution : List Entry
solution =
    [ ( ( 1, 1 ), 9 )
    , ( ( 1, 2 ), 7 )
    , ( ( 1, 4 ), 5 )
    , ( ( 1, 5 ), 3 )
    , ( ( 2, 1 ), 8 )
    , ( ( 2, 2 ), 6 )
    , ( ( 2, 3 ), 4 )
    , ( ( 2, 4 ), 2 )
    , ( ( 2, 5 ), 1 )
    , ( ( 3, 2 ), 5 )
    , ( ( 3, 3 ), 3 )
    ]
        |> List.filterMap
            (\( position, value ) -> Maybe.map (Entry position) (Kakuro.digitFromInt value))


withBoard : (Board -> Expectation) -> Expectation
withBoard check =
    case Kakuro.fromRows rows of
        Ok board ->
            check board

        Err message ->
            Expect.fail message


solved : Board -> Board
solved =
    Kakuro.fillEmptyCells solution


json : String
json =
    """
    [[{"kind":"block"},{"kind":"clue","across":null,"down":17},{"kind":"clue","across":null,"down":18},{"kind":"block"},{"kind":"clue","across":null,"down":7},{"kind":"clue","across":null,"down":4}],
     [{"kind":"clue","across":16,"down":null},{"kind":"playable"},{"kind":"playable"},{"kind":"clue","across":8,"down":7},{"kind":"playable"},{"kind":"playable"}],
     [{"kind":"clue","across":21,"down":null},{"kind":"playable"},{"kind":"playable"},{"kind":"playable"},{"kind":"playable"},{"kind":"playable"}],
     [{"kind":"block"},{"kind":"clue","across":8,"down":null},{"kind":"playable"},{"kind":"playable"},{"kind":"block"},{"kind":"block"}],
     [{"kind":"block"},{"kind":"block"},{"kind":"block"},{"kind":"block"},{"kind":"block"},{"kind":"block"}],
     [{"kind":"block"},{"kind":"block"},{"kind":"block"},{"kind":"block"},{"kind":"block"},{"kind":"block"}]]
    """
