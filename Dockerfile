FROM python:3.13-slim

WORKDIR /app

# Install Node.js 22 (required by MongoDB MCP server)
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install MongoDB MCP server globally
RUN npm install -g @mongodb-js/mongodb-mcp-server

# Install Python dependencies
COPY agent/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source
COPY agent/ .

# Copy web UI (served at GET /)
COPY web/ ./web/

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
