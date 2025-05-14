# FastAPI + Next.js Project

## Project Overview

This project combines a FastAPI backend with a Next.js frontend to create a modern web application. The backend provides a RESTful API with Python, while the frontend delivers a responsive React-based user interface.

## Features

- **FastAPI Backend**:
  - High-performance Python API
  - Automatic OpenAPI/Swagger documentation
  - Async support
  - JWT authentication
  - Database integration

- **Next.js Frontend**:
  - Server-side rendering (SSR)
  - Static site generation (SSG)
  - API routes
  - Modern React framework
  - Responsive design

## Prerequisites

Before you begin, ensure you have the following installed:

- Python 3.8+
- Node.js 16+
- npm or yarn
- Docker (optional, for containerized deployment)
- PostgreSQL (or your preferred database)

## Project Structure

```
fastapi-nextjs/
├── backend/               # FastAPI application
│   ├── app/               # Main application code
│   │   ├── api/           # API endpoints
│   │   ├── core/          # Core configurations
│   │   ├── db/            # Database models and migrations
│   │   ├── models/        # Pydantic models
│   │   ├── services/      # Business logic
│   │   └── main.py        # FastAPI app entry point
│   ├── requirements.txt   # Python dependencies
│   └── Dockerfile         # Backend Docker configuration
│
├── frontend/              # Next.js application
│   ├── components/        # React components
│   ├── pages/             # Next.js pages and API routes
│   ├── public/            # Static files
│   ├── styles/            # CSS modules
│   ├── next.config.js     # Next.js configuration
│   └── package.json       # Frontend dependencies
│
├── docker-compose.yml     # Docker orchestration
└── README.md              # This file
```

## Setup Instructions

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Set up environment variables:
   Create a `.env` file based on `.env.example`:
   ```bash
   cp .env.example .env
   ```

5. Run the FastAPI server:
   ```bash
   uvicorn app.main:app --reload
   ```

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   # or
   yarn install
   ```

3. Set up environment variables:
   Create a `.env.local` file based on `.env.local.example`:
   ```bash
   cp .env.local.example .env.local
   ```

4. Run the Next.js development server:
   ```bash
   npm run dev
   # or
   yarn dev
   ```

## Development Workflow

### Running Both Servers

For development, you'll need to run both servers simultaneously:

1. In one terminal:
   ```bash
   cd backend && uvicorn app.main:app --reload
   ```

2. In another terminal:
   ```bash
   cd frontend && npm run dev
   ```

### API Documentation

The FastAPI backend automatically generates OpenAPI documentation:

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Deployment

### Docker Deployment

1. Build and run using Docker Compose:
   ```bash
   docker-compose up --build
   ```

2. Access the application at http://localhost:3000

### Production Deployment

For production deployment, consider:

1. **Backend**:
   - Use Gunicorn with Uvicorn workers
   - Set up proper SSL/TLS
   - Configure production database

2. **Frontend**:
   - Build optimized version:
     ```bash
     npm run build
     ```
   - Use a production server like Nginx to serve the Next.js app

## Environment Variables

### Backend (.env)

```
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
SECRET_KEY=your-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
```

### Frontend (.env.local)

```
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_ENVIRONMENT=development
```

## Testing

### Backend Tests

Run pytest:
```bash
cd backend
pytest
```

### Frontend Tests

Run Jest/React Testing Library:
```bash
cd frontend
npm test
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.