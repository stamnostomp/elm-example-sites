module MemoryGame exposing (Model, Msg, init, subscriptions, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Process
import Random
import Task
import Time



-- MODEL


type CardState
    = Hidden
    | Revealed
    | Matched


type alias Card =
    { id : Int
    , symbol : String
    , state : CardState
    }


type GameState
    = Ready
    | Playing
    | Paused
    | Completed


type alias Model =
    { cards : List Card
    , firstSelection : Maybe Card
    , secondSelection : Maybe Card
    , gameState : GameState
    , moves : Int
    , matchedPairs : Int
    , totalPairs : Int
    , elapsedTime : Int -- Time in seconds
    , timerSubscription : Bool -- Whether the timer is active
    }


init : Model
init =
    { cards = []
    , firstSelection = Nothing
    , secondSelection = Nothing
    , gameState = Ready
    , moves = 0
    , matchedPairs = 0
    , totalPairs = 8 -- 8 pairs, 16 cards total
    , elapsedTime = 0
    , timerSubscription = False
    }



-- Symbols for the cards


symbols : List String
symbols =
    [ "🌟", "🌈", "🌴", "🌻", "🌍", "🌮", "🎸", "🎮" ]



-- You can customize these symbols as desired
-- Create a deck of cards with pairs of symbols


createDeck : List Card
createDeck =
    let
        -- Create each pair of cards
        createCardPair : Int -> String -> List Card
        createCardPair index symbol =
            [ { id = index * 2, symbol = symbol, state = Hidden }
            , { id = index * 2 + 1, symbol = symbol, state = Hidden }
            ]
    in
    symbols
        |> List.indexedMap createCardPair
        |> List.concat



-- Helper function to convert a list of generators into a generator of a list


sequence : List (Random.Generator a) -> Random.Generator (List a)
sequence generators =
    List.foldr
        (\generator accumulator ->
            Random.map2 (::) generator accumulator
        )
        (Random.constant [])
        generators



-- Custom shuffle function using core Random


shuffle : List a -> Random.Generator (List a)
shuffle list =
    let
        -- Helper to create a generator for a tuple (random number, item)
        helper : a -> Random.Generator ( Float, a )
        helper item =
            Random.map (\r -> ( r, item )) (Random.float 0 1)

        -- Generate a list of tuples with random first elements
        randomPairs : Random.Generator (List ( Float, a ))
        randomPairs =
            List.map helper list
                |> sequence
    in
    -- Sort by the random values and extract the original items
    Random.map (List.sortBy Tuple.first >> List.map Tuple.second) randomPairs



-- UPDATE


type Msg
    = StartGame
    | ShuffleDeck (List Card)
    | SelectCard Card
    | CheckMatch
    | HideUnmatched
    | ResetGame
    | Tick Time.Posix -- New message for timer ticks


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StartGame ->
            ( { model
                | gameState = Playing
                , elapsedTime = 0
                , timerSubscription = True
              }
            , Random.generate ShuffleDeck (shuffle createDeck)
            )

        ShuffleDeck shuffledCards ->
            ( { model | cards = shuffledCards }
            , Cmd.none
            )

        SelectCard card ->
            if card.state /= Hidden || model.gameState /= Playing then
                -- Can't select cards that are already revealed or matched
                -- or if the game is not actively being played
                ( model, Cmd.none )

            else
                case model.firstSelection of
                    Nothing ->
                        -- First card selection
                        let
                            updatedCards =
                                updateCardState card.id Revealed model.cards
                        in
                        ( { model
                            | cards = updatedCards
                            , firstSelection = Just card
                          }
                        , Cmd.none
                        )

                    Just firstCard ->
                        if firstCard.id == card.id then
                            -- Same card clicked twice, ignore
                            ( model, Cmd.none )

                        else
                            -- Second card selection
                            let
                                updatedCards =
                                    updateCardState card.id Revealed model.cards
                            in
                            ( { model
                                | cards = updatedCards
                                , secondSelection = Just card
                                , gameState = Paused
                                , moves = model.moves + 1
                              }
                            , Process.sleep 1000
                                |> Task.perform (\_ -> CheckMatch)
                            )

        CheckMatch ->
            case ( model.firstSelection, model.secondSelection ) of
                ( Just first, Just second ) ->
                    if first.symbol == second.symbol then
                        -- Cards match
                        let
                            updatedCards =
                                model.cards
                                    |> updateCardState first.id Matched
                                    |> updateCardState second.id Matched

                            newMatchedPairs =
                                model.matchedPairs + 1

                            -- Check if all pairs are matched to determine if game is complete
                            newGameState =
                                if newMatchedPairs >= model.totalPairs then
                                    Completed

                                else
                                    Playing

                            -- Stop the timer if game is completed
                            timerSubscription =
                                if newGameState == Completed then
                                    False

                                else
                                    model.timerSubscription
                        in
                        ( { model
                            | cards = updatedCards
                            , firstSelection = Nothing
                            , secondSelection = Nothing
                            , matchedPairs = newMatchedPairs
                            , gameState = newGameState
                            , timerSubscription = timerSubscription
                          }
                        , Cmd.none
                        )

                    else
                        -- Cards don't match, hide them after delay
                        ( model
                        , Process.sleep 500
                            |> Task.perform (\_ -> HideUnmatched)
                        )

                _ ->
                    -- Should never happen, but handle gracefully
                    ( { model | gameState = Playing }, Cmd.none )

        HideUnmatched ->
            case ( model.firstSelection, model.secondSelection ) of
                ( Just first, Just second ) ->
                    let
                        updatedCards =
                            model.cards
                                |> updateCardState first.id Hidden
                                |> updateCardState second.id Hidden
                    in
                    ( { model
                        | cards = updatedCards
                        , firstSelection = Nothing
                        , secondSelection = Nothing
                        , gameState = Playing
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ResetGame ->
            ( { init | timerSubscription = True, gameState = Playing }
            , Random.generate ShuffleDeck (shuffle createDeck)
            )

        Tick _ ->
            -- Only increment time if game is in Playing state
            if model.gameState == Playing then
                ( { model | elapsedTime = model.elapsedTime + 1 }
                , Cmd.none
                )

            else
                ( model, Cmd.none )



-- Helper function to update a card's state


updateCardState : Int -> CardState -> List Card -> List Card
updateCardState id newState cards =
    List.map
        (\card ->
            if card.id == id then
                { card | state = newState }

            else
                card
        )
        cards



-- Format time from seconds to MM:SS


formatTime : Int -> String
formatTime totalSeconds =
    let
        minutes =
            totalSeconds // 60

        seconds =
            modBy 60 totalSeconds

        padWithZero num =
            if num < 10 then
                "0" ++ String.fromInt num

            else
                String.fromInt num
    in
    padWithZero minutes ++ ":" ++ padWithZero seconds



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.timerSubscription then
        Time.every 1000 Tick

    else
        Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "memory-game-module" ]
        [ div [ class "memory-game-header" ]
            [ h2 [ class "memory-game-title" ] [ text "Memory Card Game" ]
            , p [ class "memory-game-description" ]
                [ text "Find matching pairs of symbols by flipping cards. A game demonstrating state management in Elm." ]
            ]
        , viewGameContent model
        , viewExplanation
        ]


viewGameContent : Model -> Html Msg
viewGameContent model =
    div [ class "memory-game-content" ]
        [ viewGameStats model
        , viewGameBoard model
        , viewGameControls model
        ]


viewGameStats : Model -> Html Msg
viewGameStats model =
    div [ class "memory-game-stats" ]
        [ div [ class "stat-item" ]
            [ span [ class "stat-label" ] [ text "Moves: " ]
            , span [ class "stat-value" ] [ text (String.fromInt model.moves) ]
            ]
        , div [ class "stat-item" ]
            [ span [ class "stat-label" ] [ text "Pairs Found: " ]
            , span [ class "stat-value" ]
                [ text (String.fromInt model.matchedPairs ++ " / " ++ String.fromInt model.totalPairs) ]
            ]
        , div [ class "stat-item time" ]
            [ span [ class "stat-label" ] [ text "Time: " ]
            , span [ class "stat-value" ] [ text (formatTime model.elapsedTime) ]
            ]
        ]


viewGameBoard : Model -> Html Msg
viewGameBoard model =
    if model.gameState == Ready then
        div [ class "memory-game-welcome" ]
            [ p [] [ text "Welcome to the Memory Card Game!" ]
            , p [] [ text "Find all the matching pairs of symbols to win." ]
            , button
                [ class "start-game-button"
                , onClick StartGame
                ]
                [ text "Start Game" ]
            ]

    else if model.gameState == Completed then
        div [ class "memory-game-completed" ]
            [ h3 [] [ text "Congratulations!" ]
            , p [] [ text ("You completed the game in " ++ String.fromInt model.moves ++ " moves!") ]
            , p [] [ text ("Your time: " ++ formatTime model.elapsedTime) ]
            , button
                [ class "play-again-button"
                , onClick ResetGame
                ]
                [ text "Play Again" ]
            ]

    else
        div [ class "memory-game-board" ]
            (List.map (viewCard model) model.cards)


viewCard : Model -> Card -> Html Msg
viewCard model card =
    let
        cardContent =
            case card.state of
                Hidden ->
                    div [ class "card-back" ] [ text "?" ]

                Revealed ->
                    div [ class "card-front" ] [ text card.symbol ]

                Matched ->
                    div [ class "card-front matched" ] [ text card.symbol ]

        isDisabled =
            model.gameState == Paused || card.state /= Hidden
    in
    div
        [ class "memory-card"
        , classList
            [ ( "revealed", card.state == Revealed )
            , ( "matched", card.state == Matched )
            ]
        , onClick
            (if isDisabled then
                -- Disabled click
                ResetGame |> always (SelectCard card)

             else
                SelectCard card
            )
        ]
        [ cardContent ]


viewGameControls : Model -> Html Msg
viewGameControls model =
    if model.gameState == Playing || model.gameState == Paused then
        div [ class "memory-game-controls" ]
            [ button
                [ class "reset-game-button"
                , onClick ResetGame
                ]
                [ text "Reset Game" ]
            ]

    else
        div [] []


viewExplanation : Html Msg
viewExplanation =
    div [ class "memory-game-explanation" ]
        [ div [ class "explanation-title" ] [ text "How it works:" ]
        , div [ class "explanation-item" ] [ text "• Model - Stores card deck, selections, game state, and statistics" ]
        , div [ class "explanation-item" ] [ text "• Update - Handles card selections, matching logic, and game progression" ]
        , div [ class "explanation-item" ] [ text "• View - Renders game board, cards, and interactive elements" ]
        , div [ class "explanation-item" ] [ text "• The game uses Task.perform and Process.sleep for timing card reveals" ]
        , div [ class "explanation-item" ] [ text "• Time.every subscription tracks elapsed time during gameplay" ]
        ]
