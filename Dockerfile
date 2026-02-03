# Use official Python runtime as base image
FROM python:3.11-slim

# Set working directory in container
WORKDIR /docs

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy documentation source files
COPY . .

# Expose MkDocs development server port
EXPOSE 8000

# Default command to serve documentation
CMD ["mkdocs", "serve", "--dev-addr=0.0.0.0:8000"]
