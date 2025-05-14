import asyncpg
import os
from dotenv import load_dotenv

load_dotenv()

async def connect_db():
    try:
        return await asyncpg.connect(
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME"),
            host=os.getenv("DB_HOST"),
            port=os.getenv("DB_PORT"),
            ssl=False  # Set to True in production with proper certs
        )
    except Exception as e:
        print(f"Error connecting to the database: {e}")
        raise