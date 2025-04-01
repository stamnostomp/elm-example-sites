module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


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
        -- Add more modules here as they are created
        ]
    }


-- UPDATE

type Msg
    = SelectModule String
    | ToggleNav
    | GoHome


update : Msg -> Model -> Model
update msg model =
    case msg of
        SelectModule id ->
            { model | currentModule = Just id }

        ToggleNav ->
            { model | isNavOpen = not model.isNavOpen }

        GoHome ->
            { model | currentModule = Nothing }


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
                [ text (if model.isNavOpen then "≡" else "≡") ]
            , h1 [ class "site-title", onClick GoHome ] [ text "Elm Examples Hub" ]
            ]
        ]


viewNav : Model -> Html Msg
viewNav model =
    nav [ class (if model.isNavOpen then "nav-open" else "nav-closed") ]
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
                        (List.map viewFeaturedModule (List.take 3 model.modules))
                    ]
                ]

            Just id ->
                [ viewModuleContent id model.modules ]
        )


viewFeaturedModule : Module -> Html Msg
viewFeaturedModule module_ =
    div [ class "featured-module", onClick (SelectModule module_.id) ]
        [ h3 [] [ text module_.name ]
        , p [] [ text module_.description ]
        , button [ class "view-button" ] [ text "View Module" ]
        ]


viewModuleContent : String -> List Module -> Html Msg
viewModuleContent id modules =
    let
        maybeModule =
            List.filter (\m -> m.id == id) modules |> List.head
    in
    case maybeModule of
        Just module_ ->
            div [ class "module-content" ]
                [ h2 [] [ text module_.name ]
                , p [] [ text module_.description ]
                , div [ class "module-placeholder" ]
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
    Browser.sandbox
        { init = initialModel
        , update = update
        , view = view
        }
