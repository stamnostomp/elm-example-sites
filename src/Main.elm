port module Main exposing (main)

-- Direct import with alias

import Browser
import Browser.Navigation as Nav
import Calculator
import Chat.Client as Chat
import Counter
import Form
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode
import MemoryGame
import PortFunnel as Funnel
import PortFunnel.WebSocket as WebSocket
import Process
import Random
import Task
import Todo
import Url



-- PORTS
-- These ports allow communication with JavaScript


port cmdPort : Encode.Value -> Cmd msg


port subPort : (Encode.Value -> msg) -> Sub msg



-- MODEL


type alias Module =
    { id : String
    , name : String
    , description : String
    }


type alias Model =
    { currentModule : Maybe String
    , isNavOpen : Bool
    , modules : List Module
    , counterModel : Counter.Model
    , todoModel : Todo.Model
    , calculatorModel : Calculator.Model
    , formModel : Form.Model
    , memoryGameModel : MemoryGame.Model
    , chatModel : Chat.Model
    }


initialModel : Model
initialModel =
    { currentModule = Nothing
    , isNavOpen = True
    , modules =
        [ { id = "counter"
          , name = "Counter"
          , description = "A simple counter application demonstrating basic Elm architecture"
          }
        , { id = "todo"
          , name = "Todo List"
          , description = "A todo list application for managing tasks"
          }
        , { id = "calculator"
          , name = "Calculator"
          , description = "A simple calculator for basic arithmetic operations"
          }
        , { id = "form"
          , name = "Registration Form"
          , description = " A form with validation demonstrating more complex state managment"
          }
        , { id = "memory-game"
          , name = "Memory Game"
          , description = " A Fun memory Game with side effects and use of tasks"
          }
        , { id = "chat"
          , name = "WebSocket Chat"
          , description = "A real-time chat application using WebSockets with Haskell backend"
          }
        ]
    , counterModel = Counter.init
    , todoModel = Todo.init
    , calculatorModel = Calculator.init
    , formModel = Form.init
    , memoryGameModel = MemoryGame.init
    , chatModel = Chat.init
    }



-- UPDATE


type Msg
    = SelectModule String
    | ToggleNav
    | GoHome
    | CounterMsg Counter.Msg
    | TodoMsg Todo.Msg
    | CalculatorMsg Calculator.Msg
    | FormMsg Form.Msg
    | MemoryGameMsg MemoryGame.Msg
    | ChatMsg Chat.Msg
    | ProcessPortMessage Encode.Value
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SelectModule id ->
            ( { model | currentModule = Just id }, Cmd.none )

        ToggleNav ->
            ( { model | isNavOpen = not model.isNavOpen }, Cmd.none )

        GoHome ->
            ( { model | currentModule = Nothing }, Cmd.none )

        CounterMsg counterMsg ->
            ( { model | counterModel = Counter.update counterMsg model.counterModel }, Cmd.none )

        TodoMsg todoMsg ->
            ( { model | todoModel = Todo.update todoMsg model.todoModel }, Cmd.none )

        CalculatorMsg calculatorMsg ->
            ( { model | calculatorModel = Calculator.update calculatorMsg model.calculatorModel }, Cmd.none )

        FormMsg formMsg ->
            ( { model | formModel = Form.update formMsg model.formModel }, Cmd.none )

        MemoryGameMsg memoryGameMsg ->
            let
                ( updatedGameModel, gameCmd ) =
                    MemoryGame.update memoryGameMsg model.memoryGameModel
            in
            ( { model | memoryGameModel = updatedGameModel }
            , Cmd.map MemoryGameMsg gameCmd
            )

        ChatMsg chatMsg ->
            let
                ( updatedChatModel, chatCmd, outMsg ) =
                    Chat.update chatMsg model.chatModel

                -- Process any outgoing WebSocket messages
                cmdFromOutMsg =
                    case outMsg of
                        Chat.NoOutMsg ->
                            Cmd.none

                        Chat.SendWSMessage funnelMsg ->
                            Funnel.sendToApp cmdPort funnelMsg
            in
            ( { model | chatModel = updatedChatModel }
            , Cmd.batch [ Cmd.map ChatMsg chatCmd, cmdFromOutMsg ]
            )

        ProcessPortMessage value ->
            -- Handle incoming port messages
            if model.currentModule == Just "chat" then
                case WebSocket.decodeResponse value of
                    Ok wsResponse ->
                        update (ChatMsg (Chat.ReceiveWSMessage wsResponse)) model

                    Err _ ->
                        ( model, Cmd.none )

            else
                ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model.currentModule of
            Just "memory-game" ->
                Sub.map MemoryGameMsg (MemoryGame.subscriptions model.memoryGameModel)

            _ ->
                Sub.none

        -- Listen for incoming port messages (WebSocket responses)
        , subPort ProcessPortMessage
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "app-container" ]
        [ viewHeader model
        , div [ class "main-content" ]
            [ viewNav model
            , viewContent model
            ]
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    header []
        [ div [ class "header-container" ]
            [ button [ class "menu-toggle", onClick ToggleNav ]
                [ text
                    (if model.isNavOpen then
                        "≡"

                     else
                        "≡"
                    )
                ]
            , h1 [ class "site-title", onClick GoHome ] [ text "Elm Examples Hub" ]
            ]
        ]


viewNav : Model -> Html Msg
viewNav model =
    nav
        [ class
            (if model.isNavOpen then
                "nav-open"

             else
                "nav-closed"
            )
        ]
        [ div [ class "nav-header" ] [ text "Modules" ]
        , ul [ class "module-list" ]
            (List.map (viewModuleItem model.currentModule) model.modules)
        ]


viewModuleItem : Maybe String -> Module -> Html Msg
viewModuleItem currentModule module_ =
    li
        [ class
            (if currentModule == Just module_.id then
                "module-item selected"

             else
                "module-item"
            )
        , onClick (SelectModule module_.id)
        ]
        [ div [ class "module-name" ] [ text module_.name ]
        , div [ class "module-description" ] [ text module_.description ]
        ]


viewContent : Model -> Html Msg
viewContent model =
    div [ class "content" ]
        (case model.currentModule of
            Nothing ->
                [ div [ class "welcome" ]
                    [ h2 [] [ text "Welcome to Elm Examples Hub" ]
                    , p [] [ text "Select a module from the navigation panel to explore different Elm applications." ]
                    , div [ class "featured-modules" ]
                        (List.map viewFeaturedModule model.modules)
                    ]
                ]

            Just id ->
                [ viewModuleContent id model ]
        )


viewFeaturedModule : Module -> Html Msg
viewFeaturedModule module_ =
    div [ class "featured-module", onClick (SelectModule module_.id) ]
        [ h3 [] [ text module_.name ]
        , p [] [ text module_.description ]
        , button [ class "view-button" ] [ text "View Module" ]
        ]


viewModuleContent : String -> Model -> Html Msg
viewModuleContent id model =
    let
        maybeModule =
            List.filter (\m -> m.id == id) model.modules |> List.head
    in
    case maybeModule of
        Just module_ ->
            div [ class "module-content" ]
                [ h2 [] [ text module_.name ]
                , p [] [ text module_.description ]
                , if id == "counter" then
                    Html.map CounterMsg (Counter.view model.counterModel)

                  else if id == "todo" then
                    Html.map TodoMsg (Todo.view model.todoModel)

                  else if id == "calculator" then
                    Html.map CalculatorMsg (Calculator.view model.calculatorModel)

                  else if id == "form" then
                    Html.map FormMsg (Form.view model.formModel)

                  else if id == "memory-game" then
                    Html.map MemoryGameMsg (MemoryGame.view model.memoryGameModel)

                  else if id == "chat" then
                    Html.map ChatMsg (Chat.view model.chatModel)

                  else
                    div [ class "module-placeholder" ]
                        [ p [] [ text "Module content will be loaded here." ]
                        , p [] [ text ("ID: " ++ id) ]
                        ]
                ]

        Nothing ->
            div [ class "error" ]
                [ text "Module not found." ]



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( initialModel, Cmd.none )
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
