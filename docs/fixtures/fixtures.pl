

:- module(fixtures, [fixture_puzzle/2, fixture_solution/2]).

% Puzzle 1 (4 casas brancas)
fixture_puzzle(1, [
    ["block", [0,4],   [0,6],   "block", "block", "block"],
    [[7,0],   "white", "white", "block", "block", "block"],
    [[3,0],   "white", "white", "block", "block", "block"],
    ["block", "block", "block", "block", "block", "block"],
    ["block", "block", "block", "block", "block", "block"],
    ["block", "block", "block", "block", "block", "block"]
]).

% Puzzle 2 (11 casas brancas, pista dupla [8,7], sequência de 5 casas)
fixture_puzzle(2, [
    ["block", [0,17],  [0,18],  "block", [0,7],   [0,4]],
    [[16,0],  "white", "white", [8,7],   "white", "white"],
    [[21,0],  "white", "white", "white", "white", "white"],
    ["block", [8,0],   "white", "white", "block", "block"],
    ["block", "block", "block", "block", "block", "block"],
    ["block", "block", "block", "block", "block", "block"]
]).

% Puzzle 3 (12 casas brancas, 3 regiões cruzadas na grade 6×6)
fixture_puzzle(3, [
    ["block", [0,16],  [0,3],   "block", [0,17],  [0,3]],
    [[10,0],  "white", "white", [11,0],  "white", "white"],
    [[9,0],   "white", "white", [9,0],   "white", "white"],
    ["block", "block", [0,3],   [0,7],   "block", "block"],
    ["block", [4,0],   "white", "white", "block", "block"],
    ["block", [6,0],   "white", "white", "block", "block"]
]).

fixture_solution(1, [
    [1,1,3], [1,2,4], [2,1,1], [2,2,2]
]).

fixture_solution(2, [
    [1,1,9], [1,2,7], [1,4,5], [1,5,3],
    [2,1,8], [2,2,6], [2,3,4], [2,4,2], [2,5,1],
    [3,2,5], [3,3,3]
]).

fixture_solution(3, [
    [1,1,9], [1,2,1], [1,4,9], [1,5,2],
    [2,1,7], [2,2,2], [2,4,8], [2,5,1],
    [4,2,1], [4,3,3], [5,2,2], [5,3,4]
]).
