// WebSocket handler for Elm chat application

document.addEventListener('DOMContentLoaded', function() {
  // Initialize the Elm application
  const app = Elm.Main.init({
    node: document.getElementById('elm-app')
  });

  // Active WebSocket connections
  const sockets = {};

  // Set up port subscriptions
  if (app.ports) {
    // Handle WebSocket connection requests
    if (app.ports.connectWebSocket) {
      app.ports.connectWebSocket.subscribe(function(url) {
        console.log('Connecting to WebSocket:', url);

        // Close existing connection if there is one
        if (sockets[url]) {
          sockets[url].close();
          delete sockets[url];
        }

        try {
          // Create new WebSocket connection
          const socket = new WebSocket(url);
          sockets[url] = socket;

          // Set up event handlers
          socket.onopen = function(event) {
            console.log('WebSocket connected:', url);
            if (app.ports.webSocketConnected) {
              app.ports.webSocketConnected.send(null);
            }
          };

          socket.onmessage = function(event) {
            console.log('WebSocket message received:', event.data);
            if (app.ports.receiveWebSocketMessage) {
              app.ports.receiveWebSocketMessage.send(event.data);
            }
          };

          socket.onclose = function(event) {
            console.log('WebSocket closed:', url, event.code, event.reason);
            delete sockets[url];
            if (app.ports.webSocketDisconnected) {
              app.ports.webSocketDisconnected.send(event.reason || 'Connection closed');
            }
          };

          socket.onerror = function(event) {
            console.error('WebSocket error:', url, event);
            if (app.ports.webSocketError) {
              app.ports.webSocketError.send('WebSocket connection error');
            }
          };
        } catch (error) {
          console.error('Error creating WebSocket:', error);
          if (app.ports.webSocketError) {
            app.ports.webSocketError.send(error.message);
          }
        }
      });
    }

    // Handle sending messages over WebSocket
    if (app.ports.sendWebSocketMessage) {
      app.ports.sendWebSocketMessage.subscribe(function(data) {
        const { url, message } = data;
        const socket = sockets[url];

        if (socket && socket.readyState === WebSocket.OPEN) {
          console.log('Sending WebSocket message:', message);
          socket.send(message);
        } else {
          console.error('Cannot send message, socket not connected:', url);
          if (app.ports.webSocketError) {
            app.ports.webSocketError.send('WebSocket not connected');
          }
        }
      });
    }
  }

  // Cleanup function for page unload
  window.addEventListener('beforeunload', function() {
    // Close all WebSocket connections
    Object.values(sockets).forEach(socket => {
      if (socket && socket.readyState === WebSocket.OPEN) {
        socket.close();
      }
    });
  });
});
