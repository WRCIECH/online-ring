from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json
from datetime import datetime, timezone

from database import get_connection

app = FastAPI(title="Online Ring API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["Content-Type"],
)


class SaveData(BaseModel):
    player_id: str
    saved_at: float
    model_config = {"extra": "allow"}


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/save")
async def save_game(data: SaveData):
    conn = await get_connection()
    try:
        saved_at = datetime.fromtimestamp(data.saved_at, tz=timezone.utc)
        await conn.execute(
            """
            INSERT INTO saves (player_id, data, saved_at)
            VALUES ($1, $2, $3)
            ON CONFLICT (player_id)
            DO UPDATE SET data = $2, saved_at = $3
            """,
            data.player_id,
            json.dumps(data.model_dump()),
            saved_at,
        )
        return {"status": "ok"}
    finally:
        await conn.close()


@app.get("/save/{player_id}")
async def load_game(player_id: str):
    conn = await get_connection()
    try:
        row = await conn.fetchrow(
            "SELECT data FROM saves WHERE player_id = $1",
            player_id,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Save not found")
        return json.loads(row["data"])
    finally:
        await conn.close()
