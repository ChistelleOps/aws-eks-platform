
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(title="EKS Platform API")

# Collect HTTP metrics and expose /metrics
Instrumentator().instrument(app).expose(app)

@app.get("/")
def home():
    return {"message": "Hello from our EKS Platform!"}


@app.get("/health")
def health():
    return {"status": "healthy"}
