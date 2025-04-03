{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Main where

import Control.Concurrent (MVar, newMVar, modifyMVar_, modifyMVar, readMVar)
import Control.Exception (finally)
import Control.Monad (forM_, forever)
import Data.Aeson (FromJSON, ToJSON, decode, encode, Value(..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TL
import qualified Network.WebSockets as WS
import Data.Map (Map)
import qualified Data.Map as Map
import GHC.Generics (Generic)
import Data.Time.Clock.POSIX (getPOSIXTime)
import System.Environment (getArgs)
import System.IO (stdout, hSetBuffering, BufferMode(LineBuffering))
import qualified Data.ByteString.Lazy as BL

-- Types for our chat messages
data Client = Client
  { clientId :: Int
  , clientName :: Text
  , clientConn :: WS.Connection
  }

data ServerState = ServerState
  { nextId :: Int
  , clients :: Map Int Client
  }

data ChatMessage = ChatMessage
  { msgType :: Text
  , sender :: Text
  , content :: Text
  , timestamp :: Int
  } deriving (Generic, Show)

data JoinMessage = JoinMessage
  { joinType :: Text
  , username :: Text
  } deriving (Generic, Show)

data RenameMessage = RenameMessage
  { renameType :: Text
  , oldName :: Text
  , newName :: Text
  } deriving (Generic, Show)

data UsersListMessage = UsersListMessage
  { users :: [Text]
  } deriving (Generic, Show)

instance ToJSON ChatMessage
instance FromJSON ChatMessage

instance ToJSON JoinMessage
instance FromJSON JoinMessage

instance ToJSON RenameMessage
instance FromJSON RenameMessage

instance ToJSON UsersListMessage
instance FromJSON UsersListMessage

-- Helper function to convert ByteString to Text
encodeLazyByteStringToText :: ToJSON a => a -> Text
encodeLazyByteStringToText = TL.toStrict . TL.decodeUtf8 . encode

-- Initialize an empty server state
newServerState :: ServerState
newServerState = ServerState 0 Map.empty

-- Get the number of active clients
numClients :: ServerState -> Int
numClients = Map.size . clients

-- Add a client to the server state
addClient :: Client -> ServerState -> ServerState
addClient client state = state {
    nextId = nextId state + 1,
    clients = Map.insert (clientId client) client (clients state)
  }

-- Remove a client from the server state
removeClient :: Int -> ServerState -> ServerState
removeClient clientId state = state { clients = Map.delete clientId (clients state) }

-- Update a client's username
updateClientName :: Int -> Text -> ServerState -> ServerState
updateClientName cId newName state =
  state { clients = Map.adjust (\c -> c { clientName = newName }) cId (clients state) }

-- Broadcast a message to all clients
broadcast :: Text -> MVar ServerState -> IO ()
broadcast message stateRef = do
  state <- readMVar stateRef
  forM_ (Map.elems (clients state)) $ \client ->
    WS.sendTextData (clientConn client) message

-- Send a message to a specific client
sendMessage :: Client -> Text -> IO ()
sendMessage client message = WS.sendTextData (clientConn client) message

-- Send the current users list to all clients
broadcastUsers :: MVar ServerState -> IO ()
broadcastUsers stateRef = do
  state <- readMVar stateRef
  let usernames = map clientName (Map.elems (clients state))
      usersMsg = encodeLazyByteStringToText $ UsersListMessage usernames
  broadcast usersMsg stateRef

-- Main application
main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  args <- getArgs
  let port = if null args then 9160 else read (head args)

  -- Create shared state
  state <- newMVar newServerState

  T.putStrLn $ "Chat server starting on port " <> T.pack (show port)

  -- Run the WebSocket server
  WS.runServer "0.0.0.0" port (chatApp state)

-- Chat application with shared state
chatApp :: MVar ServerState -> WS.ServerApp
chatApp stateRef pending = do
  conn <- WS.acceptRequest pending
  WS.withPingThread conn 30 (return ()) $ do

    -- Wait for the join message with the username
    msg <- WS.receiveData conn
    case decode msg of
      Just (JoinMessage "join" name) -> do
        -- Create a new client and add it to the server state
        userId <- modifyMVar stateRef $ \state -> do
          let newId = nextId state
              newClient = Client newId name conn
              newState = addClient newClient state

          T.putStrLn $ "New client connected: " <> name <> " (ID: " <> T.pack (show newId) <> ")"

          -- Create and send welcome message
          currTime <- round <$> getPOSIXTime
          let welcomeMsg = ChatMessage "message" "Server" ("Welcome, " <> name <> "!") currTime
          sendMessage newClient (encodeLazyByteStringToText welcomeMsg)

          -- Broadcast user join notification
          let joinNotification = ChatMessage "message" "Server" (name <> " has joined the chat") currTime
          broadcast (encodeLazyByteStringToText joinNotification) stateRef

          -- Send updated users list to all clients
          broadcastUsers stateRef

          return (newState, newId)

        -- Set up handler for when client disconnects
        flip finally (disconnect userId stateRef) $ forever $ do
          -- Process incoming messages
          msg <- WS.receiveData conn
          handleMessage msg userId stateRef conn

      _ -> do
        -- Invalid first message, disconnect
        T.putStrLn "Client sent invalid join message, disconnecting"
        WS.sendTextData conn ("Invalid join message" :: Text)
        return ()

-- Handle client disconnect
disconnect :: Int -> MVar ServerState -> IO ()
disconnect clientId stateRef = do
  modifyMVar_ stateRef $ \state -> do
    case Map.lookup clientId (clients state) of
      Nothing -> return state
      Just client -> do
        T.putStrLn $ "Client disconnected: " <> clientName client <> " (ID: " <> T.pack (show clientId) <> ")"

        -- Broadcast disconnect notification
        currTime <- round <$> getPOSIXTime
        let disconnectMsg = ChatMessage "message" "Server" (clientName client <> " has left the chat") currTime
        broadcast (encodeLazyByteStringToText disconnectMsg) stateRef

        -- Return updated state
        let newState = removeClient clientId state

        -- Send updated users list
        broadcastUsers stateRef

        return newState

-- Handle different message types without complex JSON parsing
handleMessage :: Text -> Int -> MVar ServerState -> WS.Connection -> IO ()
handleMessage msgText clientId stateRef conn = do
  -- Get client from state
  state <- readMVar stateRef
  case Map.lookup clientId (clients state) of
    Nothing -> T.putStrLn $ "Unknown client ID: " <> T.pack (show clientId)
    Just client -> do
      -- Try to decode as different message types directly
      let bs = WS.toLazyByteString msgText

      -- Try as a chat message first
      case decode bs of
        Just (ChatMessage "message" senderName content _) -> do
          currTime <- round <$> getPOSIXTime
          let fullMsg = ChatMessage "message" senderName content currTime
          broadcast (encodeLazyByteStringToText fullMsg) stateRef
          T.putStrLn $ "[Chat] " <> senderName <> ": " <> content

        -- If not a chat message, try as a rename message
        _ -> case decode bs of
               Just (RenameMessage "rename" oldName newName) -> do
                 modifyMVar_ stateRef $ \s -> do
                   T.putStrLn $ "User rename: " <> oldName <> " -> " <> newName

                   -- Update the client name
                   let newState = updateClientName clientId newName s

                   -- Broadcast rename notification
                   currTime <- round <$> getPOSIXTime
                   let renameMsg = ChatMessage "message" "Server" (oldName <> " is now known as " <> newName) currTime
                   broadcast (encodeLazyByteStringToText renameMsg) stateRef

                   -- Send updated users list
                   broadcastUsers stateRef

                   return newState

               -- Unknown message format
               _ -> T.putStrLn $ "Unknown or invalid message: " <> msgText
