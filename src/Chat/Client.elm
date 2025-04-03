module Chat.Client exposing (Model, Msg, init, subscriptions, update, view)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode
import Process
import Task
import Time
import WebSocketClient as WSC
import WebSocketClient.Message as WSM



-- MODEL


type ConnectionStatus
    = Disconnected
    | Connecting
    | Connected
    | Failed String


type alias Message =
    { sender : String
    , content : String
    , timestamp : Int
    }


type alias Model =
    { messages : List Message
    , currentMessage : String
    , username : String
    , connectionStatus : ConnectionStatus
    , users : List String
    , serverUrl : String
    , wsClient : WSC.Model Msg
    , nextId : Int
    }


init : Model
init =
    { messages = []
    , currentMessage = ""
    , username = "Guest"
    , connectionStatus = Disconnected
    , users = []
    , serverUrl = "ws://localhost:9160/chat"
    , wsClient = WSC.init
    , nextId = 0
    }



-- UPDATE


type Msg
    = Connect
    | WsConnect (Result String ())
    | WsConnected
    | WsDisconnected
    | WsError String
    | WsReceived String
    | WsClientMsg (WSC.Message Msg)
    | UpdateMessage String
    | UpdateUsername String
    | SendMessage
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Connect ->
            let
                ( wsClient, cmd ) =
                    WSC.makeOpenWithKey model.serverUrl model.nextId WsClientMsg
            in
            ( { model
                | connectionStatus = Connecting
                , nextId = model.nextId + 1
                , wsClient = wsClient
              }
            , cmd
            )

        WsConnect result ->
            case result of
                Ok _ ->
                    ( model, Cmd.none )

                Err error ->
                    ( { model | connectionStatus = Failed error }
                    , Cmd.none
                    )

        WsConnected ->
            let
                joinMessage =
                    Encode.object
                        [ ( "type", Encode.string "join" )
                        , ( "username", Encode.string model.username )
                        ]
                        |> Encode.encode 0

                ( wsClient, cmd ) =
                    WSC.send joinMessage model.wsClient
            in
            ( { model
                | connectionStatus = Connected
                , wsClient = wsClient
              }
            , cmd
            )

        WsDisconnected ->
            ( { model | connectionStatus = Disconnected }
            , Cmd.none
            )

        WsError errorMsg ->
            ( { model | connectionStatus = Failed errorMsg }
            , Cmd.none
            )

        WsReceived messageText ->
            -- Handle different message types
            if String.startsWith "{\"users\":" messageText then
                -- Users list message
                case Decode.decodeString usersDecoder messageText of
                    Ok userList ->
                        ( { model | users = userList }
                        , Cmd.none
                        )

                    Err _ ->
                        ( model, Cmd.none )

            else
                -- Chat message
                case Decode.decodeString messageDecoder messageText of
                    Ok message ->
                        ( { model | messages = model.messages ++ [ message ] }
                        , Cmd.none
                        )

                    Err _ ->
                        ( model, Cmd.none )

        WsClientMsg wsMsg ->
            case wsMsg of
                WSM.Error error ->
                    update (WsError error) model

                WSM.Opened key ->
                    update WsConnected model

                WSM.Closed key code ->
                    update WsDisconnected model

                WSM.StringMessage key str ->
                    update (WsReceived str) model

                WSM.BytesMessage _ _ ->
                    -- We don't handle binary messages
                    ( model, Cmd.none )

        UpdateMessage message ->
            ( { model | currentMessage = message }
            , Cmd.none
            )

        UpdateUsername username ->
            let
                cmd =
                    if model.connectionStatus == Connected then
                        let
                            nameChangeMessage =
                                Encode.object
                                    [ ( "type", Encode.string "rename" )
                                    , ( "oldName", Encode.string model.username )
                                    , ( "newName", Encode.string username )
                                    ]
                                    |> Encode.encode 0

                            ( wsClient, sendCmd ) =
                                WSC.send nameChangeMessage model.wsClient
                        in
                        Cmd.batch
                            [ sendCmd
                            , Task.perform (\_ -> NoOp) (Task.succeed ())
                            ]

                    else
                        Cmd.none
            in
            ( { model | username = username }
            , cmd
            )

        SendMessage ->
            if String.trim model.currentMessage == "" then
                ( model, Cmd.none )

            else if model.connectionStatus /= Connected then
                ( model, Cmd.none )

            else
                let
                    chatMessage =
                        Encode.object
                            [ ( "type", Encode.string "message" )
                            , ( "sender", Encode.string model.username )
                            , ( "content", Encode.string model.currentMessage )
                            ]
                            |> Encode.encode 0

                    ( wsClient, cmd ) =
                        WSC.send chatMessage model.wsClient
                in
                ( { model
                    | currentMessage = ""
                    , wsClient = wsClient
                  }
                , cmd
                )

        NoOp ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    WSC.listen WsClientMsg model.wsClient



-- JSON DECODERS


messageDecoder : Decode.Decoder Message
messageDecoder =
    Decode.map3 Message
        (Decode.field "sender" Decode.string)
        (Decode.field "content" Decode.string)
        (Decode.field "timestamp" Decode.int)


usersDecoder : Decode.Decoder (List String)
usersDecoder =
    Decode.field "users" (Decode.list Decode.string)



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "chat-module" ]
        [ div [ class "chat-header" ]
            [ h2 [ class "chat-title" ] [ text "WebSocket Chat Room" ]
            , p [ class "chat-description" ]
                [ text "A real-time chat application using WebSockets with an Elm frontend and Haskell backend." ]
            ]
        , viewConnectionStatus model
        , viewChatInterface model
        , viewExplanation
        ]


viewConnectionStatus : Model -> Html Msg
viewConnectionStatus model =
    div [ class "connection-status" ]
        [ div [ class "user-settings" ]
            [ label [ class "username-label" ] [ text "Your name:" ]
            , input
                [ class "username-input"
                , value model.username
                , onInput UpdateUsername
                ]
                []
            ]
        , div [ class "connection-controls" ]
            [ button
                [ class "connect-button"
                , onClick Connect
                , disabled (model.connectionStatus == Connected || model.connectionStatus == Connecting)
                ]
                [ text
                    (case model.connectionStatus of
                        Disconnected ->
                            "Connect to Chat"

                        Connecting ->
                            "Connecting..."

                        Connected ->
                            "Connected"

                        Failed _ ->
                            "Reconnect"
                    )
                ]
            , viewConnectionStatusIndicator model.connectionStatus
            ]
        ]


viewConnectionStatusIndicator : ConnectionStatus -> Html Msg
viewConnectionStatusIndicator status =
    let
        ( statusClass, statusText ) =
            case status of
                Disconnected ->
                    ( "disconnected", "Disconnected" )

                Connecting ->
                    ( "connecting", "Connecting..." )

                Connected ->
                    ( "connected", "Connected" )

                Failed error ->
                    ( "failed", "Connection failed: " ++ error )
    in
    div [ class ("status-indicator " ++ statusClass) ]
        [ text statusText ]


viewChatInterface : Model -> Html Msg
viewChatInterface model =
    div [ class "chat-interface" ]
        [ div [ class "chat-container" ]
            [ viewMessageList model
            , viewUsersList model
            ]
        , viewMessageInput model
        ]


viewMessageList : Model -> Html Msg
viewMessageList model =
    let
        messageElements =
            if List.isEmpty model.messages then
                [ div [ class "empty-chat" ]
                    [ text "No messages yet. Start the conversation!" ]
                ]

            else
                List.map viewMessage model.messages
    in
    div [ class "message-list" ] messageElements


viewMessage : Message -> Html Msg
viewMessage message =
    div [ class "message" ]
        [ div [ class "message-header" ]
            [ span [ class "message-sender" ] [ text message.sender ]
            , span [ class "message-time" ]
                [ text (formatTimestamp message.timestamp) ]
            ]
        , div [ class "message-content" ] [ text message.content ]
        ]


viewUsersList : Model -> Html Msg
viewUsersList model =
    div [ class "users-list" ]
        [ div [ class "users-header" ] [ text "Online Users" ]
        , div [ class "users-container" ]
            (if List.isEmpty model.users then
                [ div [ class "no-users" ] [ text "No users connected" ] ]

             else
                List.map (\user -> div [ class "user-item" ] [ text user ]) model.users
            )
        ]


viewMessageInput : Model -> Html Msg
viewMessageInput model =
    let
        isDisabled =
            model.connectionStatus /= Connected
    in
    div [ class "message-input-container" ]
        [ input
            [ class "message-input"
            , placeholder
                (if isDisabled then
                    "Connect to start chatting"

                 else
                    "Type your message..."
                )
            , value model.currentMessage
            , onInput UpdateMessage
            , disabled isDisabled
            , on "keydown" (ifIsEnter SendMessage)
            ]
            []
        , button
            [ class "send-button"
            , onClick SendMessage
            , disabled isDisabled
            ]
            [ text "Send" ]
        ]


viewExplanation : Html Msg
viewExplanation =
    div [ class "chat-explanation" ]
        [ div [ class "explanation-title" ] [ text "How it works:" ]
        , div [ class "explanation-item" ]
            [ text "• Model - Tracks messages, users, and connection state" ]
        , div [ class "explanation-item" ]
            [ text "• WebSockets - Establishes a persistent connection with the Haskell server" ]
        , div [ class "explanation-item" ]
            [ text "• JSON - Used for structured communication between client and server" ]
        , div [ class "explanation-item" ]
            [ text "• Elm subscriptions - Handles asynchronous WebSocket events" ]
        , div [ class "explanation-item" ]
            [ text "• Haskell backend - Manages connections and broadcasts messages" ]
        ]



-- HELPERS


formatTimestamp : Int -> String
formatTimestamp timestamp =
    -- For simplicity, just show the timestamp directly
    -- In a real app, you'd format this as a readable time
    String.fromInt timestamp


ifIsEnter : msg -> Decode.Decoder msg
ifIsEnter msg =
    Decode.field "key" Decode.string
        |> Decode.andThen
            (\key ->
                if key == "Enter" then
                    Decode.succeed msg

                else
                    Decode.fail "not enter"
            )
