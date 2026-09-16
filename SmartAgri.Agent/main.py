from fastapi import FastAPI
from pydantic import BaseModel


app = FastAPI(
    title="SmartAgri Agent Service",
    description="Internal service for the Smart Basket workflow.",
    version="0.1.0",
)


class HealthResponse(BaseModel):
    status: str
    service: str


@app.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="SmartAgri.Agent",
    )