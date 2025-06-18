from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os
from dotenv import load_dotenv
import asyncpg
import asyncio
import ssl
import boto3
from botocore.exceptions import ClientError
from datetime import datetime
import uuid
s3 = boto3.client('s3')
# Load environment variables
load_dotenv()

# Initialize S3 client
s3_client = boto3.client(
    's3',
    aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
    aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
    region_name=os.getenv("AWS_REGION")
)
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")

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

# CORS setup - Fixed and more specific
origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    # Add your production domain here when needed
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,  # Changed from ["*"] to specific origins
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],  # Explicit methods
    allow_headers=["*"],
)

print("CORS middleware added")

@app.get("/")
async def root():
    return {
        "message": "🚀 Deployment Successful again and again!",
        "status": "running",
        "timestamp": asyncio.get_event_loop().time(),
        "origin": os.getenv("FRONTEND_DOMAIN")
    }

@app.get("/health")
async def health():
    return {"status": "OK"}

# Changed from /api to /api/hello to avoid conflicts
@app.get("/api/hello")
async def api_hello():
    print("API endpoint hit")
    return {"message": "Hello from the backend!"}

# Changed from /data to /api/data for consistency
@app.get("/api/data")
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

@app.get("/api/debug-env")
async def debug_env():
    return {
        "AWS_ACCESS_KEY_ID": os.getenv("AWS_ACCESS_KEY_ID"),
        "AWS_SECRET_ACCESS_KEY": os.getenv("AWS_SECRET_ACCESS_KEY"),  # don't leak actual key
        "AWS_REGION": os.getenv("AWS_REGION"),
        "S3_BUCKET_NAME": os.getenv("S3_BUCKET_NAME"),
        "DB_USER": os.getenv("DB_USER"),
        "DB_PASSWORD": os.getenv("DB_PASSWORD"),  # hide actual value
        "DB_NAME": os.getenv("DB_NAME"),
        "DB_HOST": os.getenv("DB_HOST"),
        "DB_PORT": os.getenv("DB_PORT"),
        "FRONTEND_DOMAIN": os.getenv("FRONTEND_DOMAIN"),
    }


@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...)):
    try:
        # Generate a unique filename
        file_extension = file.filename.split(".")[-1]
        folder_name = "images"
        unique_filename = f"{folder_name}/{uuid.uuid4()}.{file_extension}"
        print(f"Uploading file: {file.filename} as {unique_filename}")
        # Upload file to S3
        s3_client.upload_fileobj(
            file.file,
            S3_BUCKET_NAME,
            unique_filename,
            ExtraArgs={
                "ContentType": file.content_type,
            }
        )
        
        # Generate the public URL
        file_url = f"https://{S3_BUCKET_NAME}.s3.amazonaws.com/{unique_filename}"
        
        return {
            "message": "File uploaded successfully",
            "filename": unique_filename,
            "file_url": file_url,
            "content_type": file.content_type,
            "size": file.size
        }
    except ClientError as e:
        print(f"S3 Client Error: {e}")
        raise HTTPException(status_code=500, detail="S3 upload failed")
    except Exception as e:
        print(f"Error uploading file: {e}")
        raise HTTPException(status_code=500, detail="File upload failed")
    
    
@app.get("/api/list-images")
async def list_images():
    s3 = boto3.client(
            's3',
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
            region_name=os.getenv("AWS_REGION")
        
        )
    response = s3.list_objects_v2(Bucket=S3_BUCKET_NAME)
    images = [obj['Key'] for obj in response.get('Contents', [])]
    print(f"Found {len(images)} images in S3 bucket.", images)
    return {"images": images}

    
@app.get("/generate-presigned-url")
async def get_presigned_url(filename: str):
    url = s3_client.generate_presigned_url(
        'get_object',
        Params={
            'Bucket': S3_BUCKET_NAME,
            'Key': filename
        },
        ExpiresIn=3600  # URL expires in 1 hour
    )
    return {"url": url}
