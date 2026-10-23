
from fastapi import FastAPI

app = FastAPI(title="EKS Platform API")


@app.get("/")
def home():
    return {"message": "Hello from our EKS Platform!"}


@app.get("/health")
def health():
    return {"status": "healthy"}
