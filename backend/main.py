import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import asyncpg
import asyncio
import ssl
# Load environment variables
load_dotenv()

# Connect to the database
async def connect_db():
    try:
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        conn = await asyncpg.connect(
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME"),
            host=os.getenv("DB_HOST"),
            port=int(os.getenv("DB_PORT")),
            ssl=ssl_context
        )           
        return conn
    except Exception as e:
        print(f"Error connecting to the database: {e}")
        return None

# Create FastAPI app
app = FastAPI()

# CORS setup
origins = [
    os.getenv("FRONTEND_DOMAIN")
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,  # Allow requests from the frontend domain
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],  # Allow specific HTTP methods
    allow_headers=["Content-Type", "Authorization"],  # Allow specific headers
)

@app.get("/api")
async def api():
    return {"message": "Hello from the backend!"}

@app.get("/health")
async def health():
    return {"status": "OK"}

@app.get("/")
async def root():
    return {
        "message": "🚀 Deployment Successful again and again!",
        "status": "running",
        "timestamp": asyncio.get_event_loop().time(),  # Use directly without await
        "origin": os.getenv("FRONTEND_DOMAIN")
    }

@app.get("/data")
async def get_data():
    try:
        conn = await connect_db()
        if conn is None:
            return {"error": "Database connection failed"}
        row = await conn.fetchrow("SELECT NOW() as current_time")
        await conn.close()
        return {"Date": row["current_time"], "message": "Hello from the database!"}
    except Exception as e:
        print(f"Error while querying database: {e}")
        return {"error": "Server error"}
