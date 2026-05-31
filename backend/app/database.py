"""
Database configuration and connection setup
"""
import os
import logging
from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from databases import Database
from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("DATABASE_URL environment variable is not set")

# SQLAlchemy setup with transaction pooler configuration
engine = create_engine(
    DATABASE_URL,
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,  # Important for transaction pooler
    pool_recycle=3600,   # Recycle connections every hour
    connect_args={"sslmode": "require"}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Async database connection
database = Database(DATABASE_URL)

# Metadata for migrations
metadata = MetaData()

# Dependency to get database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Async database connection functions
async def connect_db():
    """Connect to the database"""
    await database.connect()
    logger.info("✅ Database connected successfully")

async def disconnect_db():
    """Disconnect from the database"""
    await database.disconnect()
    logger.info("❌ Database disconnected")