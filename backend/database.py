import os
import asyncpg
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.environ["DATABASE_URL"]


async def get_connection() -> asyncpg.Connection:
    return await asyncpg.connect(DATABASE_URL)
