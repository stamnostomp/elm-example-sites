module Todo exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy, lazy2)
import Json.Decode exposing (Decoder, andThen, fail, succeed)
import Json.Encode
import Html.Events exposing (keyCode, on, onBlur)

-- MODEL
type alias Todo =
    { id : Int
    , text : String
    , completed : Bool
    , editing : Bool
    }

type alias Model =
    { todos : List Todo
    , nextId : Int
    , newTodoInput : String
    , filter : Filter
    }

type Filter
    = All
    | Active
    | Completed

init : Model
init =
    { todos =
        [ { id = 1, text = "Learn Elm", completed = False, editing = False }
        , { id = 2, text = "Build a Todo app", completed = False, editing = False }
        ]
    , nextId = 3
    , newTodoInput = ""
    , filter = All
    }


-- UPDATE

type Msg
    = AddTodo
    | UpdateNewTodo String
    | DeleteTodo Int
    | ToggleCompleted Int
    | ClearCompleted
    | ChangeFilter Filter
    | EditTodo Int
    | UpdateEditingTodo Int String
    | FinishEditing Int


update : Msg -> Model -> Model
update msg model =
    case msg of
        AddTodo ->
            if String.trim model.newTodoInput == "" then
                -- Dont't add empty todos
                model
            else
                { model
                    | todos = model.todos ++ [ { id = model.nextId, text = String.trim model.newTodoInput, completed = False, editing = False } ]
                    , nextId = model.nextId + 1
                    , newTodoInput = ""
                }

        UpdateNewTodo text ->
            { model | newTodoInput = text }

        DeleteTodo id ->
            { model | todos = List.filter (\todo -> todo.id /= id) model.todos }

        ToggleCompleted id ->
            { model
                | todos = List.map
                                (\todo ->
                                     if todo.id == id then
                                         { todo | completed = not todo.completed }
                                     else
                                         todo
                                )
                                model.todos
            }

        ClearCompleted ->
            { model | todos = List.filter (\todo -> not todo.completed) model.todos }

        ChangeFilter filter ->
            { model | filter = filter }

        EditTodo id ->
            { model
                | todos =
                    List.map
                        (\todo ->
                            if todo.id == id then
                                { todo | editing = True }
                             else
                                 { todo | editing = False }
                        )
                        model.todos

            }

        UpdateEditingTodo id text ->
            { model
                | todos =
                    List.map
                        (\todo ->
                            if todo.id == id then
                                { todo | text = text }
                            else
                                todo
                        )
                        model.todos

            }

        FinishEditing id ->
            { model
                | todos =
                    List.map
                        (\todo ->
                             if todo.id == id then
                                 { todo | editing = False, text = String.trim todo.text }
                             else
                                 todo
                        )
                        model.todos

            }


view : Model -> Html Msg
view model =
    div [ class "todo-module" ]
        [ div [ class "todo-header"]
              [ h2 [] [ text "Todo List"]
              , p [ class "todo-description" ]
                  [ text "A more complex Elm app demonstrating filting, editing, and state managment." ]
              ]
        , viewInput model.newTodoInput
        , viewTodos model
        , viewControls model
        , viewExplanation
        ]

viewInput : String -> Html Msg
viewInput newTodo =
    div [ class "todo-input-container" ]
        [ input
            [ class "todo-input"
            , placeholder "What needs to be don?"
            , value newTodo
            , onInput UpdateNewTodo
            , onEnter AddTodo
            ]
            []
        , button [ class "add-todo-button", onClick AddTodo ] [ text "add" ]
        ]

viewTodos : Model -> Html Msg
viewTodos model =
    let
        filteredTodos =
            case model.filter of
                All ->
                    model.todos

                Active ->
                    List.filter (\todo -> not todo.completed) model.todos

                Completed ->
                    List.filter (\todo -> todo.completed) model.todos

        todoItems =
            List.map (viewTodoItem model) filteredTodos
    in
    if List.isEmpty model.todos then
        div [ class "empty-todos" ] [ text "No todos yet. Add one above!" ]
    else if List.isEmpty filteredTodos then
        div [ class "empty-todos" ] [ text "No todos match your filter." ]
    else
        div [ class "todos-container" ] todoItems


viewTodoItem : Model -> Todo -> Html Msg
viewTodoItem model todo =
    let
        completedClass =
            if todo.completed then
                "completed"
            else
                ""
    in
    if todo.editing then
        div [ class "todo-item editing" ]
            [ input
                [ class "edit-todo-input"
                , value todo.text
                , onInput (UpdateEditingTodo todo.id)
                , onEnter (FinishEditing todo.id)
                , onBlur (FinishEditing todo.id)
                , id ("todo-edit-" ++ String.fromInt todo.id)
                , autofocus True
                ]
                []
            ]
    else
        div [ class ("todo-item " ++ completedClass) ]
            [ input
                [ class "todo-checkbox"
                , type_ "checkbox"
                , checked todo.completed
                , onClick (ToggleCompleted todo.id)
                ]
                []
            , span
                [ class "todo-text"
                , onDoubleClick (EditTodo todo.id)
                ]
                [ text todo.text ]
            , button
                [ class "delete-todo"
                , onClick (DeleteTodo todo.id)
                ]
                [ text "×" ]
            ]


viewControls : Model -> Html Msg
viewControls model =
    let
        itemsLeft =
            List.length (List.filter (\t -> not t.completed) model.todos)

        itemsText =
            if itemsLeft == 1 then
                "1 item left"
            else
                String.fromInt itemsLeft ++ " items left"
    in
    div [ class "todo-controls" ]
        [ span [ class "items-left" ] [ text itemsText ]
        , div [ class "filters" ]
            [ filterButton All model.filter
            , filterButton Active model.filter
            , filterButton Completed model.filter
            ]
        , if List.any (\t -> t.completed) model.todos then
            button
                [ class "clear-completed"
                , onClick ClearCompleted
                ]
                [ text "Clear completed" ]
          else
            text ""
        ]


filterButton : Filter -> Filter -> Html Msg
filterButton targetFilter currentFilter =
    let
        activeClass =
            if targetFilter == currentFilter then
                "active"
            else
                ""

        label =
            case targetFilter of
                All -> "All"
                Active -> "Active"
                Completed -> "Completed"
    in
    button
        [ class ("filter-button " ++ activeClass)
        , onClick (ChangeFilter targetFilter)
        ]
        [ text label ]


viewExplanation : Html Msg
viewExplanation =
    div [ class "todo-explanation" ]
        [ div [ class "explanation-title" ] [ text "How it works:" ]
        , div [ class "explanation-item" ] [ text "• Model - Stores todos, input state, and filter selection" ]
        , div [ class "explanation-item" ] [ text "• Update - Handles todo creation, deletion, toggling, and editing" ]
        , div [ class "explanation-item" ] [ text "• View - Renders UI based on model state, with filtering" ]
        , div [ class "explanation-item" ] [ text "• Try double-clicking on a todo to edit it" ]
        ]


-- HELPERS

onEnter : Msg -> Attribute Msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                Json.Decode.succeed msg
            else
                Json.Decode.fail "not ENTER"
    in
    on "keydown" (Json.Decode.andThen isEnter keyCode)
