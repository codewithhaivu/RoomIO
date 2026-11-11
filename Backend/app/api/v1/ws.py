from fastapi import WebSocket, WebSocketDisconnect, APIRouter

from app.api.deps import  security
from app.websocket.user import websocket_user
from core.security import verify_token

router = APIRouter(
    tags=["Websocket"]
)


@router.websocket("/ws/user/notifications")
async def notification_websocket(
        websocket: WebSocket
):
    print("WS HANDLER ENTERED")
    credentials = await security(websocket)
    print("SECURITY PASSED")
    account_id = verify_token(
        credentials.credentials
    )
    print("TOKEN VERIFIED:", account_id)
    await websocket.accept()

    websocket_user.connections[account_id] = websocket

    try:
        while True:
            await websocket.receive_text()

    except WebSocketDisconnect:
        websocket_user.disconnect(account_id)
