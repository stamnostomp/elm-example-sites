module Calculator exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import String exposing (fromFloat, fromInt)


-- MODEL

type alias Model =
    { display : String
    , firstOperand : Maybe Float
    , operator : Maybe Operation
    , waitingForSecondOperand : Bool
    , hasError : Bool
    }

type Operation
    = Add
    | Subtract
    | Multiply
    | Divide

init : Model
init =
    { display = "0"
    , firstOperand = Nothing
    , operator = Nothing
    , waitingForSecondOperand = False
    , hasError = False
    }



-- UPDATE


type Msg
    = DigitPressed String
    | DecimalPressed
    | OperatorPressed Operation
    | EqualsPressed
    | ClearPressed
    | ClearEntryPressed
    | BackspacePressed
    | PercentagePressed
    | NegatePressed

update : Msg -> Model -> Model
update msg model =
    case msg of
        DigitPressed digit ->
            if model.hasError then
                -- if there is an error reset
                { init | display = digit }

            else if model.waitingForSecondOperand then
                     -- start entering second digit
                     {model | display = digit, waitingForSecondOperand = False }
            else if model.display == "0" then
                     -- replace the first 0
                     { model | display = digit  }
            else
                { model | display = model.display ++ digit  }

        DecimalPressed ->
            if model.hasError then
                { init | display = "0." }
            else if model.waitingForSecondOperand then
                { model | display = "0.", waitingForSecondOperand = False }
            else if not (String.contains "." model.display) then
                { model | display = model.display ++ "." }

            else
                model

        OperatorPressed op ->
            if model.hasError then
                model
            else
                case model.operator of
                    Nothing ->
                        -- First operation: store the current number and operator
                        { model
                            | firstOperand = String.toFloat model.display
                            , operator = Just op
                            , waitingForSecondOperand = True
                        }

                    Just currentOp ->
                        if model.waitingForSecondOperand then
                            -- Change operator if we're waiting for second operand
                            { model | operator = Just op }
                        else
                            -- Chain operations: calculate result and set up for next operation
                            let
                                result = calculateResult model
                            in
                            { model
                                | display = formatFloat result
                                , firstOperand = Just result
                                , operator = Just op
                                , waitingForSecondOperand = True
                                , hasError = isInfiniteOrNaN result
                            }

        EqualsPressed ->
            if model.hasError then
                model
            else if model.operator == Nothing || model.waitingForSecondOperand then
                -- No operation to perform
                model
            else
                let
                    result = calculateResult model
                    hasError = isInfiniteOrNaN result
                in
                { model
                    | display = formatFloat result
                    , firstOperand = Nothing
                    , operator = Nothing
                    , waitingForSecondOperand = True
                    , hasError = hasError
                }

        ClearPressed ->
            init

        ClearEntryPressed ->
            { model | display = "0" }

        BackspacePressed ->
            if model.hasError then
                init
            else if model.waitingForSecondOperand then
                model
            else if String.length model.display <= 1 then
                { model | display = "0" }
            else
                { model | display = String.dropRight 1 model.display }

        PercentagePressed ->
            if model.hasError then
                model
            else
                case String.toFloat model.display of
                    Nothing ->
                        { model | hasError = True, display = "Error" }

                    Just number ->
                        let
                            result =
                                case model.firstOperand of
                                    Nothing ->
                                        number / 100

                                    Just first ->
                                        first * (number / 100)
                        in
                        { model | display = formatFloat result }

        NegatePressed ->
            if model.hasError then
                model
            else
                case String.toFloat model.display of
                    Nothing ->
                        model

                    Just number ->
                        { model | display = formatFloat (-number) }

-- HELPER FUNCTIONS

calculateResult : Model -> Float
calculateResult model =
    case (model.firstOperand, model.operator, String.toFloat model.display) of
        (Just first, Just op, Just second) ->
            case op of
                Add -> first + second
                Subtract -> first - second
                Multiply -> first * second
                Divide -> first / second

        _ ->
            0

formatFloat : Float -> String
formatFloat number =
    -- Convert float to string, removing trailing zeros
    let
        str = String.fromFloat number
    in
    if String.endsWith ".0" str then
        String.dropRight 2 str
    else
        str

isInfiniteOrNaN : Float -> Bool
isInfiniteOrNaN number =
    (number == 1/0) || (number == -1/0) || (number /= number)

-- VIEW

view : Model -> Html Msg
view model =
    div [ class "calculator-module" ]
        [ div [ class "calculator-header" ]
            [ h2 [ class "calculator-title" ] [ text "Calculator" ]
            , p [ class "calculator-description" ] [ text "A simple calculator demonstrating more complex state management in Elm." ]
            ]
        , div [ class "calculator-body" ]
            [ viewDisplay model
            , viewKeypad model
            ]
        , viewExplanation
        ]

viewDisplay : Model -> Html Msg
viewDisplay model =
    div [ class "calculator-display-container" ]
        [ div
            [ class "calculator-display" ]
            [ text model.display ]
        ]

viewKeypad : Model -> Html Msg
viewKeypad model =
    div [ class "calculator-keypad" ]
        [ div [ class "keypad-row" ]
            [ button [ class "calculator-key function-key", onClick ClearPressed ] [ text "AC" ]
            , button [ class "calculator-key function-key", onClick NegatePressed ] [ text "+/-" ]
            , button [ class "calculator-key function-key", onClick PercentagePressed ] [ text "%" ]
            , button [ class "calculator-key operator-key", onClick (OperatorPressed Divide) ] [ text "÷" ]
            ]
        , div [ class "keypad-row" ]
            [ button [ class "calculator-key number-key", onClick (DigitPressed "7") ] [ text "7" ]
            , button [ class "calculator-key number-key", onClick (DigitPressed "8") ] [ text "8" ]
            , button [ class "calculator-key number-key", onClick (DigitPressed "9") ] [ text "9" ]
            , button [ class "calculator-key operator-key", onClick (OperatorPressed Multiply) ] [ text "×" ]
            ]
        , div [ class "keypad-row" ]
            [ button [ class "calculator-key number-key", onClick (DigitPressed "4") ] [ text "4" ]
            , button [ class "calculator-key number-key", onClick (DigitPressed "5") ] [ text "5" ]
            , button [ class "calculator-key number-key", onClick (DigitPressed "6") ] [ text "6" ]
            , button [ class "calculator-key operator-key", onClick (OperatorPressed Subtract) ] [ text "-" ]
            ]
        , div [ class "keypad-row" ]
            [ button [ class "calculator-key number-key", onClick (DigitPressed "1") ] [ text "1" ]
            , button [ class "calculator-key number-key", onClick (DigitPressed "2") ] [ text "2" ]
            , button [ class "calculator-key number-key", onClick (DigitPressed "3") ] [ text "3" ]
            , button [ class "calculator-key operator-key", onClick (OperatorPressed Add) ] [ text "+" ]
            ]
        , div [ class "keypad-row" ]
            [ button [ class "calculator-key number-key", onClick (DigitPressed "0") ] [ text "0" ]
            , button [ class "calculator-key number-key", onClick DecimalPressed ] [ text "." ]
            , button [ class "calculator-key equals-key", onClick EqualsPressed ] [ text "=" ]
            ]
        ]

viewExplanation : Html Msg
viewExplanation =
    div [ class "calculator-explanation" ]
        [ div [ class "explanation-title" ] [ text "How it works:" ]
        , div [ class "explanation-item" ]
            [ text "• Model - Stores the display value, operands, current operation, and calculator state" ]
        , div [ class "explanation-item" ]
            [ text "• Update - Handles numeric input, operations, and calculation logic" ]
        , div [ class "explanation-item" ]
            [ text "• View - Renders the calculator display and interactive keypad" ]
        , div [ class "explanation-item" ]
            [ text "• The calculator uses a more complex state machine pattern to handle input sequences" ]
        ]
