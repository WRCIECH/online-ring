from contextlib import asynccontextmanager
import json
from datetime import datetime, timezone

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from database import close_pool, get_conn, init_pool


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_pool()
    # Create table on every cold start — idempotent, safe to repeat.
    from database import _pool
    async with _pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS saves (
                player_id  TEXT        PRIMARY KEY,
                data       JSONB       NOT NULL,
                saved_at   TIMESTAMPTZ NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
    yield
    await close_pool()


app = FastAPI(title="Online Ring API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
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
async def save_game(data: SaveData, conn=Depends(get_conn)):
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


@app.get("/save/{player_id}")
async def load_save(player_id: str, conn=Depends(get_conn)):
    row = await conn.fetchrow(
        "SELECT data FROM saves WHERE player_id = $1",
        player_id,
    )
    if not row:
        raise HTTPException(status_code=404, detail="Save not found")
    return json.loads(row["data"])
