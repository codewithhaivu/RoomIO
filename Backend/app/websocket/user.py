from fastapi import WebSocket


class ConnectionUser:

    def __init__(self):
        self.connections = {}

    async def connect(self, account_id, websocket: WebSocket):
        await websocket.accept()
        self.connections[account_id] = websocket

    def disconnect(self, account_id):
        if account_id in self.connections:
            del self.connections[account_id]

    async def send_to_user(self, account_id, message):
        websocket = self.connections.get(account_id)

        if websocket:
            await websocket.send_json(message)


websocket_user = ConnectionUser()