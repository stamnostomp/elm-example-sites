module Counter exposing (Model, Msg, init, update, view)

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)

-- MODEL

type alias Model =
    { count : Int
    }

-- Initialize our model with a default value
init : Model
init =
    { count = 0
    }

-- UPDATE

type Msg
    = Increment
    | Decrement
    | Reset

-- The update function takes the current action (Msg) and the current state (Model)
-- and returns the new state
update : Msg -> Model -> Model
update msg model =
    case msg of
        Increment ->
            { model | count = model.count + 1 }

        Decrement ->
            { model | count = model.count - 1 }

        Reset ->
            { model | count = 0 }

-- VIEW

view : Model -> Html Msg
view model =
    div [ class "counter-module" ]
        [ div [ class "counter-title" ] [ text "Counter Example" ]
        , div [ class "counter-description" ]
            [ text "This counter demonstrates the basic Elm Architecture with state management." ]
        , div [ class "counter-container" ]
            [ button
                [ class "counter-button"
                , onClick Decrement
                ]
                [ text "-" ]
            , div [ class "counter-value" ] [ text (String.fromInt model.count) ]
            , button
                [ class "counter-button"
                , onClick Increment
                ]
                [ text "+" ]
            ]
        , button
            [ class "reset-button"
            , onClick Reset
            ]
            [ text "Reset" ]
        , div [ class "counter-explanation" ]
            [ div [ class "explanation-title" ] [ text "How it works:" ]
            , div [ class "explanation-item" ]
                [ text "1. The Model defines our state: { count: Int }" ]
            , div [ class "explanation-item" ]
                [ text "2. The Msg type defines possible actions: Increment | Decrement | Reset" ]
            , div [ class "explanation-item" ]
                [ text "3. The update function changes state based on actions" ]
            , div [ class "explanation-item" ]
                [ text "4. The view function renders HTML based on the current state" ]
            ]
        ]
