"""
LegalTracking RAG Backend API
Main FastAPI application using OpenRouter for LLM and embeddings
"""

from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import os
import json
import hashlib
from datetime import datetime
import logging
from contextlib import asynccontextmanager

# External libraries
import httpx
from dotenv import load_dotenv
from supabase import create_client, Client
import redis
import numpy as np
from pymilvus import connections, Collection, FieldSchema, CollectionSchema, DataType, utility

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv("LOG_LEVEL", "INFO")),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global clients
supabase_client: Optional[Client] = None
redis_client: Optional[redis.Redis] = None
milvus_connected = False

# OpenRouter configuration
OPENROUTER_API_URL = "https://openrouter.ai/api/v1"
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_EMBEDDING_MODEL = os.getenv("OPENROUTER_EMBEDDING_MODEL", "openai/text-embedding-3-small")
OPENROUTER_CHAT_MODEL = os.getenv("OPENROUTER_CHAT_MODEL", "deepseek/deepseek-chat")
OPENROUTER_SITE_URL = os.getenv("OPENROUTER_SITE_URL", "https://github.com/legal-rag-mexico")
OPENROUTER_APP_NAME = os.getenv("OPENROUTER_APP_NAME", "LegalTracking-RAG")

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    logger.info("Starting up RAG Backend API...")
    await initialize_clients()
    await initialize_milvus_collection()
    yield
    # Shutdown
    logger.info("Shutting down RAG Backend API...")
    if milvus_connected:
        connections.disconnect("default")

# Initialize FastAPI app
app = FastAPI(
    title="LegalTracking RAG API",
    version="1.0.0",
    description="Backend API for Legal Document RAG System using OpenRouter",
    lifespan=lifespan
)

# CORS Configuration
cors_origins = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== Data Models ====================

class ChatRequest(BaseModel):
    message: str = Field(..., description="User's chat message")
    context_id: Optional[str] = Field(None, description="Context ID for conversation continuity")
    user_id: str = Field(..., description="User identifier")
    language: str = Field("es", description="Language code (es/en)")
    model: Optional[str] = Field(None, description="Optional model override")

class ChatResponse(BaseModel):
    response: str
    sources: List[Dict[str, Any]]
    context_id: str
    tokens_used: Optional[int] = None
    model_used: Optional[str] = None

class DocumentUploadResponse(BaseModel):
    success: bool
    document_id: str
    chunks_processed: int
    message: str

class SearchRequest(BaseModel):
    query: str
    limit: int = Field(10, ge=1, le=100)
    filters: Optional[Dict[str, Any]] = None

class SearchResult(BaseModel):
    content: str
    title: str
    source: str
    score: float
    metadata: Optional[Dict[str, Any]] = None

# ==================== Client Initialization ====================

async def initialize_clients():
    """Initialize external service clients"""
    global supabase_client, redis_client
    
    try:
        # Check OpenRouter API key
        if not OPENROUTER_API_KEY:
            logger.error("OpenRouter API key not found!")
            raise ValueError("OPENROUTER_API_KEY is required")
        
        logger.info(f"OpenRouter configured with embedding model: {OPENROUTER_EMBEDDING_MODEL}")
        logger.info(f"OpenRouter configured with chat model: {OPENROUTER_CHAT_MODEL}")
        
        # Initialize Supabase
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
        if supabase_url and supabase_key:
            supabase_client = create_client(supabase_url, supabase_key)
            logger.info("Supabase client initialized")
        else:
            logger.warning("Supabase credentials not found")
        
        # Initialize Redis
        redis_url = os.getenv("REDIS_URL", "redis://redis:6379")
        redis_client = redis.from_url(redis_url, decode_responses=True)
        redis_client.ping()
        logger.info("Redis client initialized")
        
    except Exception as e:
        logger.error(f"Error initializing clients: {e}")

async def initialize_milvus_collection():
    """Initialize Milvus connection and create collection if needed"""
    global milvus_connected
    
    try:
        # Connect to Milvus
        connections.connect(
            alias="default",
            host=os.getenv("MILVUS_HOST", "milvus-standalone"),
            port=int(os.getenv("MILVUS_PORT", "19530"))
        )
        milvus_connected = True
        logger.info("Connected to Milvus")
        
        # Check if collection exists
        collection_name = "legal_documents"
        if not utility.has_collection(collection_name):
            # Create collection schema
            fields = [
                FieldSchema(name="id", dtype=DataType.INT64, is_primary=True, auto_id=True),
                FieldSchema(name="embedding", dtype=DataType.FLOAT_VECTOR, dim=1536),
                FieldSchema(name="content", dtype=DataType.VARCHAR, max_length=65535),
                FieldSchema(name="title", dtype=DataType.VARCHAR, max_length=512),
                FieldSchema(name="source", dtype=DataType.VARCHAR, max_length=512),
                FieldSchema(name="chunk_index", dtype=DataType.INT64),
                FieldSchema(name="created_at", dtype=DataType.INT64)
            ]
            
            schema = CollectionSchema(
                fields=fields,
                description="Legal documents for RAG"
            )
            
            collection = Collection(
                name=collection_name,
                schema=schema
            )
            
            # Create index for vector field
            index_params = {
                "metric_type": "L2",
                "index_type": "IVF_FLAT",
                "params": {"nlist": 128}
            }
            collection.create_index(
                field_name="embedding",
                index_params=index_params
            )
            
            collection.load()
            logger.info(f"Created and loaded collection: {collection_name}")
        else:
            collection = Collection(collection_name)
            collection.load()
            logger.info(f"Loaded existing collection: {collection_name}")
            
    except Exception as e:
        logger.error(f"Error initializing Milvus: {e}")
        milvus_connected = False

# ==================== OpenRouter Integration ====================

async def generate_embedding_openrouter(text: str) -> List[float]:
    """Generate embeddings using OpenRouter API"""
    try:
        # Check cache first
        cache_key = f"embed:{hashlib.md5(text.encode()).hexdigest()}"
        if redis_client:
            cached = redis_client.get(cache_key)
            if cached:
                return json.loads(cached)
        
        # Generate embedding via OpenRouter
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{OPENROUTER_API_URL}/embeddings",
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "HTTP-Referer": OPENROUTER_SITE_URL,
                    "X-Title": OPENROUTER_APP_NAME,
                    "Content-Type": "application/json"
                },
                json={
                    "input": text,
                    "model": OPENROUTER_EMBEDDING_MODEL
                }
            )
            
            if response.status_code != 200:
                logger.error(f"OpenRouter embedding error: {response.text}")
                raise HTTPException(status_code=response.status_code, detail=f"Embedding generation failed: {response.text}")
            
            data = response.json()
            embedding = data["data"][0]["embedding"]
            
            # Cache the result
            if redis_client:
                redis_client.setex(cache_key, 3600, json.dumps(embedding))
            
            return embedding
            
    except httpx.TimeoutException:
        logger.error("OpenRouter API timeout")
        raise HTTPException(status_code=504, detail="Embedding API timeout")
    except Exception as e:
        logger.error(f"Error generating embedding: {e}")
        raise HTTPException(status_code=500, detail=f"Embedding generation failed: {str(e)}")

async def generate_chat_response_openrouter(query: str, context: str, language: str = "es", model: Optional[str] = None) -> tuple[str, str]:
    """Generate response using OpenRouter Chat API"""
    try:
        system_prompt = {
            "es": """Eres un asistente legal experto en derecho mexicano. 
                     Usa el contexto proporcionado para responder preguntas de manera precisa y profesional.
                     Si el contexto no contiene información relevante, indícalo claramente.
                     Cita las fuentes cuando sea posible.""",
            "en": """You are a legal assistant expert in Mexican law. 
                     Use the provided context to answer questions accurately and professionally.
                     If the context doesn't contain relevant information, clearly indicate this.
                     Cite sources when possible."""
        }
        
        # Use provided model or default
        chat_model = model or OPENROUTER_CHAT_MODEL
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{OPENROUTER_API_URL}/chat/completions",
                headers={
                    "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                    "HTTP-Referer": OPENROUTER_SITE_URL,
                    "X-Title": OPENROUTER_APP_NAME,
                    "Content-Type": "application/json"
                },
                json={
                    "model": chat_model,
                    "messages": [
                        {"role": "system", "content": system_prompt.get(language, system_prompt["es"])},
                        {"role": "user", "content": f"Contexto:\n{context}\n\nPregunta: {query}"}
                    ],
                    "temperature": 0.7,
                    "max_tokens": 2000,
                    "top_p": 0.9,
                    "frequency_penalty": 0.1
                }
            )
            
            if response.status_code != 200:
                logger.error(f"OpenRouter chat error: {response.text}")
                raise HTTPException(status_code=response.status_code, detail=f"Chat generation failed: {response.text}")
            
            data = response.json()
            return data["choices"][0]["message"]["content"], chat_model
            
    except httpx.TimeoutException:
        logger.error("OpenRouter API timeout")
        raise HTTPException(status_code=504, detail="Chat API timeout")
    except Exception as e:
        logger.error(f"Error generating chat response: {e}")
        raise HTTPException(status_code=500, detail=f"Chat generation failed: {str(e)}")

async def search_similar_documents(embedding: List[float], top_k: int = 5) -> List[Dict]:
    """Search for similar documents in Milvus"""
    if not milvus_connected:
        logger.warning("Milvus not connected, returning empty results")
        return []
    
    try:
        collection = Collection("legal_documents")
        
        search_params = {
            "metric_type": "L2",
            "params": {"nprobe": 10}
        }
        
        results = collection.search(
            data=[embedding],
            anns_field="embedding",
            param=search_params,
            limit=top_k,
            output_fields=["content", "title", "source", "chunk_index"]
        )
        
        documents = []
        for hits in results:
            for hit in hits:
                documents.append({
                    "content": hit.entity.get("content"),
                    "title": hit.entity.get("title"),
                    "source": hit.entity.get("source"),
                    "chunk_index": hit.entity.get("chunk_index"),
                    "score": float(hit.score)
                })
        
        return documents
        
    except Exception as e:
        logger.error(f"Error searching documents: {e}")
        return []

def chunk_text(text: str, chunk_size: int = 1000, overlap: int = 200) -> List[str]:
    """Split text into overlapping chunks"""
    chunks = []
    start = 0
    text_length = len(text)
    
    while start < text_length:
        end = start + chunk_size
        chunk = text[start:end]
        
        # Try to break at sentence boundary
        if end < text_length:
            last_period = chunk.rfind('.')
            if last_period > chunk_size * 0.8:
                end = start + last_period + 1
                chunk = text[start:end]
        
        chunks.append(chunk.strip())
        start = end - overlap if end < text_length else text_length
    
    return chunks

# ==================== API Endpoints ====================

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "LegalTracking RAG API",
        "version": "1.0.0",
        "status": "online",
        "llm_provider": "OpenRouter",
        "embedding_model": OPENROUTER_EMBEDDING_MODEL,
        "chat_model": OPENROUTER_CHAT_MODEL,
        "endpoints": {
            "health": "/health",
            "chat": "/api/chat",
            "upload": "/api/documents/upload",
            "search": "/api/search",
            "models": "/api/models"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "llm_provider": "OpenRouter",
        "services": {
            "openrouter": OPENROUTER_API_KEY is not None,
            "milvus": milvus_connected,
            "redis": redis_client.ping() if redis_client else False,
            "supabase": supabase_client is not None
        }
    }
    
    # Check if all critical services are healthy
    critical_services = ["openrouter", "milvus"]
    all_critical_healthy = all(health_status["services"][s] for s in critical_services)
    
    if not all_critical_healthy:
        health_status["status"] = "degraded"
    
    return health_status

@app.get("/api/models")
async def list_models():
    """List available models from OpenRouter"""
    return {
        "embedding_models": [
            {"id": "openai/text-embedding-3-small", "name": "OpenAI Embedding Small", "cost": "$0.00002/1k tokens"},
            {"id": "openai/text-embedding-3-large", "name": "OpenAI Embedding Large", "cost": "$0.00013/1k tokens"},
            {"id": "voyage/voyage-2", "name": "Voyage 2", "cost": "$0.00012/1k tokens"}
        ],
        "chat_models": [
            {"id": "deepseek/deepseek-chat", "name": "DeepSeek Chat", "cost": "$0.0001/1k tokens"},
            {"id": "anthropic/claude-3-haiku", "name": "Claude 3 Haiku", "cost": "$0.00025/1k tokens"},
            {"id": "meta-llama/llama-3-70b-instruct", "name": "Llama 3 70B", "cost": "Free tier available"},
            {"id": "mistralai/mistral-7b-instruct", "name": "Mistral 7B", "cost": "$0.00007/1k tokens"},
            {"id": "google/gemini-pro", "name": "Gemini Pro", "cost": "$0.000125/1k tokens"},
            {"id": "openai/gpt-3.5-turbo", "name": "GPT-3.5 Turbo", "cost": "$0.0005/1k tokens"}
        ],
        "current_embedding_model": OPENROUTER_EMBEDDING_MODEL,
        "current_chat_model": OPENROUTER_CHAT_MODEL
    }

@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest, background_tasks: BackgroundTasks):
    """RAG-powered chat endpoint using OpenRouter"""
    try:
        logger.info(f"Chat request from user {request.user_id}: {request.message[:100]}...")
        
        # Generate embedding for the query
        query_embedding = await generate_embedding_openrouter(request.message)
        
        # Search for relevant documents
        relevant_docs = await search_similar_documents(query_embedding, top_k=5)
        
        # Build context from relevant documents
        context = "\n\n".join([
            f"[{doc['title']}]:\n{doc['content']}"
            for doc in relevant_docs
        ])
        
        # Limit context length to avoid token limits
        max_context_length = 6000
        if len(context) > max_context_length:
            context = context[:max_context_length] + "..."
        
        # Generate response using OpenRouter
        response_text, model_used = await generate_chat_response_openrouter(
            request.message,
            context,
            request.language,
            request.model
        )
        
        # Generate context ID if not provided
        context_id = request.context_id or hashlib.md5(
            f"{request.user_id}{datetime.utcnow().isoformat()}".encode()
        ).hexdigest()
        
        # Store in Supabase asynchronously
        if supabase_client:
            background_tasks.add_task(
                store_chat_history,
                request.user_id,
                request.message,
                response_text,
                relevant_docs,
                context_id,
                model_used
            )
        
        return ChatResponse(
            response=response_text,
            sources=relevant_docs,
            context_id=context_id,
            model_used=model_used
        )
        
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/documents/upload", response_model=DocumentUploadResponse)
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    user_id: str = None,
    title: Optional[str] = None
):
    """Upload and process a document"""
    try:
        # Validate file type
        allowed_types = ['.pdf', '.txt', '.docx', '.md']
        file_ext = os.path.splitext(file.filename)[1].lower()
        if file_ext not in allowed_types:
            raise HTTPException(
                status_code=400,
                detail=f"File type {file_ext} not supported. Allowed: {allowed_types}"
            )
        
        # Read file content
        content = await file.read()
        
        # Extract text based on file type
        if file_ext == '.txt' or file_ext == '.md':
            text = content.decode('utf-8')
        else:
            # For PDF and DOCX, you would implement proper extraction
            # For now, returning a placeholder
            text = f"Document content from {file.filename}"
        
        # Chunk the document
        chunks = chunk_text(text)
        
        # Generate document ID
        doc_id = hashlib.md5(
            f"{file.filename}{datetime.utcnow().isoformat()}".encode()
        ).hexdigest()
        
        # Process chunks asynchronously
        background_tasks.add_task(
            process_document_chunks,
            chunks,
            doc_id,
            title or file.filename,
            file.filename,
            user_id
        )
        
        return DocumentUploadResponse(
            success=True,
            document_id=doc_id,
            chunks_processed=len(chunks),
            message=f"Document queued for processing: {len(chunks)} chunks"
        )
        
    except Exception as e:
        logger.error(f"Upload error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/search", response_model=List[SearchResult])
async def search(request: SearchRequest):
    """Search for documents using OpenRouter embeddings"""
    try:
        # Generate embedding for search query
        query_embedding = await generate_embedding_openrouter(request.query)
        
        # Search in Milvus
        results = await search_similar_documents(query_embedding, top_k=request.limit)
        
        # Format results
        search_results = [
            SearchResult(
                content=doc["content"],
                title=doc["title"],
                source=doc["source"],
                score=doc["score"]
            )
            for doc in results
        ]
        
        return search_results
        
    except Exception as e:
        logger.error(f"Search error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== Background Tasks ====================

async def store_chat_history(
    user_id: str,
    message: str,
    response: str,
    sources: List[Dict],
    context_id: str,
    model_used: str
):
    """Store chat history in Supabase"""
    try:
        if not supabase_client:
            return
        
        supabase_client.table("chat_history").insert({
            "user_id": user_id,
            "message": message,
            "response": response,
            "sources": json.dumps(sources),
            "context_id": context_id,
            "model_used": model_used,
            "created_at": datetime.utcnow().isoformat()
        }).execute()
        
        logger.info(f"Stored chat history for context {context_id}")
        
    except Exception as e:
        logger.error(f"Error storing chat history: {e}")

async def process_document_chunks(
    chunks: List[str],
    doc_id: str,
    title: str,
    source: str,
    user_id: Optional[str]
):
    """Process and store document chunks in Milvus"""
    try:
        if not milvus_connected:
            logger.error("Cannot process document: Milvus not connected")
            return
        
        collection = Collection("legal_documents")
        
        # Prepare data for insertion
        embeddings = []
        contents = []
        titles = []
        sources = []
        chunk_indices = []
        timestamps = []
        
        for i, chunk in enumerate(chunks):
            # Generate embedding using OpenRouter
            embedding = await generate_embedding_openrouter(chunk)
            
            embeddings.append(embedding)
            contents.append(chunk[:65535])  # Truncate to max length
            titles.append(title[:512])
            sources.append(source[:512])
            chunk_indices.append(i)
            timestamps.append(int(datetime.utcnow().timestamp()))
        
        # Insert into Milvus
        collection.insert([
            embeddings,
            contents,
            titles,
            sources,
            chunk_indices,
            timestamps
        ])
        
        collection.flush()
        
        # Store metadata in Supabase
        if supabase_client and user_id:
            supabase_client.table("documents").insert({
                "document_id": doc_id,
                "user_id": user_id,
                "title": title,
                "source": source,
                "chunks_count": len(chunks),
                "created_at": datetime.utcnow().isoformat()
            }).execute()
        
        logger.info(f"Processed document {doc_id}: {len(chunks)} chunks")
        
    except Exception as e:
        logger.error(f"Error processing document chunks: {e}")

# ==================== Error Handlers ====================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "status_code": exc.status_code,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "status_code": 500,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level=os.getenv("LOG_LEVEL", "info").lower()
    )