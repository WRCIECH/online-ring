import os
from typing import AsyncGenerator

import asyncpg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL: str = os.environ["DATABASE_URL"]
_pool: asyncpg.Pool | None = None


async def init_pool() -> None:
    global _pool
    _pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=5)


async def close_pool() -> None:
    if _pool is not None:
        await _pool.close()


async def get_conn() -> AsyncGenerator[asyncpg.Connection, None]:
    """FastAPI dependency — yields a checked-out pool connection."""
    async with _pool.acquire() as conn:
        yield conn
