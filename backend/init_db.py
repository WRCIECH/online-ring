"""Run once to initialize the database schema."""
import asyncio
from database import get_connection


async def main() -> None:
    conn = await get_connection()
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS saves (
            player_id  TEXT PRIMARY KEY,
            data       JSONB        NOT NULL,
            saved_at   TIMESTAMPTZ  NOT NULL,
            created_at TIMESTAMPTZ  DEFAULT NOW()
        )
    """)
    await conn.close()
    print("Database initialized.")


if __name__ == "__main__":
    asyncio.run(main())
