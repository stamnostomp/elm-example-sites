module Chat.Client exposing (Model, Msg(..), OutMsg(..), init, subscriptions, update, view)

-- PortFunnel imports

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode
import PortFunnel as Funnel
import PortFunnel.WebSocket as WebSocket
import Process
import Task
import Time



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
    }


init : Model
init =
    { messages = []
    , currentMessage = ""
    , username = "Guest"
    , connectionStatus = Disconnected
    , users = []
    , serverUrl = "ws://localhost:9160/chat"
    }



-- UPDATE
-- Outgoing messages that Main.elm will process


type OutMsg
    = NoOutMsg
    | SendWSMessage Funnel.GenericMessage



-- Incoming WebSocket messages and user actions


type Msg
    = Connect
    | ReceiveWSMessage WebSocket.Response
    | UpdateMessage String
    | UpdateUsername String
    | SendMessage
    | NoOp



-- Update returns a tuple of (Model, Cmd Msg, OutMsg)
-- The OutMsg tells Main.elm if we need to send a WebSocket message


update : Msg -> Model -> ( Model, Cmd Msg, OutMsg )
update msg model =
    case msg of
        Connect ->
            -- Create a WebSocket open message
            let
                message =
                    WebSocket.makeOpen model.serverUrl
            in
            ( { model | connectionStatus = Connecting }
            , Cmd.none
            , SendWSMessage message
              -- Return the message to be sent through the port
            )

        ReceiveWSMessage response ->
            -- Handle incoming WebSocket messages
            let
                ( newModel, cmd ) =
                    handleWebSocketResponse response model
            in
            ( newModel, cmd, NoOutMsg )

        UpdateMessage message ->
            ( { model | currentMessage = message }
            , Cmd.none
            , NoOutMsg
            )

        UpdateUsername username ->
            let
                outMsg =
                    if model.connectionStatus == Connected then
                        let
                            nameChangeMessage =
                                Encode.object
                                    [ ( "type", Encode.string "rename" )
                                    , ( "oldName", Encode.string model.username )
                                    , ( "newName", Encode.string username )
                                    ]
                                    |> Encode.encode 0

                            sendMessage =
                                WebSocket.makeSend model.serverUrl nameChangeMessage
                        in
                        SendWSMessage sendMessage

                    else
                        NoOutMsg
            in
            ( { model | username = username }
            , Cmd.none
            , outMsg
            )

        SendMessage ->
            if String.trim model.currentMessage == "" then
                ( model, Cmd.none, NoOutMsg )

            else if model.connectionStatus /= Connected then
                ( model, Cmd.none, NoOutMsg )

            else
                let
                    chatMessage =
                        Encode.object
                            [ ( "type", Encode.string "message" )
                            , ( "sender", Encode.string model.username )
                            , ( "content", Encode.string model.currentMessage )
                            ]
                            |> Encode.encode 0

                    sendMessage =
                        WebSocket.makeSend model.serverUrl chatMessage
                in
                ( { model | currentMessage = "" }
                , Cmd.none
                , SendWSMessage sendMessage
                )

        NoOp ->
            ( model, Cmd.none, NoOutMsg )



-- Helper function to handle WebSocket responses


handleWebSocketResponse : WebSocket.Response -> Model -> ( Model, Cmd Msg )
handleWebSocketResponse response model =
    case response of
        WebSocket.OpenResponse { url } ->
            -- Connection established, send join message
            let
                joinMessage =
                    Encode.object
                        [ ( "type", Encode.string "join" )
                        , ( "username", Encode.string model.username )
                        ]
                        |> Encode.encode 0

                -- We can't send the message directly from here,
                -- so we'll delay it slightly to let the Main module handle it
                delayedSend =
                    Process.sleep 100
                        |> Task.perform (\_ -> SendMessage)
            in
            ( { model | connectionStatus = Connected }
            , Cmd.none
            )

        WebSocket.MessageResponse { message } ->
            -- Process received message
            if String.startsWith "{\"users\":" message then
                -- Users list message
                case Decode.decodeString usersDecoder message of
                    Ok userList ->
                        ( { model | users = userList }
                        , Cmd.none
                        )

                    Err _ ->
                        ( model, Cmd.none )

            else
                -- Chat message
                case Decode.decodeString messageDecoder message of
                    Ok msg ->
                        ( { model | messages = model.messages ++ [ msg ] }
                        , Cmd.none
                        )

                    Err _ ->
                        ( model, Cmd.none )

        WebSocket.ClosedResponse { code, wasClean, expected } ->
            ( { model | connectionStatus = Disconnected }
            , Cmd.none
            )

        WebSocket.ErrorResponse { error } ->
            ( { model | connectionStatus = Failed error }
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    -- In our architecture, Main.elm forwards WebSocket messages to us
    Sub.none



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
