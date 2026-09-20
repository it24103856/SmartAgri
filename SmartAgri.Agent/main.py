import os
import secrets
import asyncio

from basket_agents import ProposalRequest, generate_proposal
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Annotated

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException

from basket_tools import validate_basket
from schemas import (
    BasketValidationRequest,
    BasketValidationResponse,
)


load_dotenv(Path(__file__).with_name(".env"))

INTERNAL_KEY = os.getenv("AGENT_INTERNAL_KEY", "").strip()


@asynccontextmanager
async def lifespan(app: FastAPI):
    if len(INTERNAL_KEY) < 32:
        raise RuntimeError(
            "AGENT_INTERNAL_KEY is missing or too short."
        )

    yield


app = FastAPI(
    title="SmartAgri Agent Service",
    version="0.2.0",
    lifespan=lifespan,
)


async def require_internal_key(
    supplied_key: Annotated[
        str | None,
        Header(alias="X-Agent-Key"),
    ] = None,
) -> None:
    if supplied_key is None:
        raise HTTPException(
            status_code=401,
            detail="Invalid service credentials.",
        )

    if not secrets.compare_digest(
        supplied_key.encode("utf-8"),
        INTERNAL_KEY.encode("utf-8"),
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid service credentials.",
        )


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "SmartAgri.Agent",
    }


@app.post(
    "/internal/validate-basket",
    response_model=BasketValidationResponse,
    dependencies=[Depends(require_internal_key)],
)
async def validate(
    request: BasketValidationRequest,
) -> BasketValidationResponse:
    return validate_basket(request)

proposal_lock = asyncio.Lock()


@app.post(
    "/internal/propose-basket",
    dependencies=[Depends(require_internal_key)],
)
async def propose_basket(request: ProposalRequest):
    try:
        await asyncio.wait_for(
            proposal_lock.acquire(),
            timeout=0.1,
        )
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=429,
            detail="Agent is busy. Please retry shortly.",
        )

    try:
        return await asyncio.wait_for(
            generate_proposal(request),
            timeout=360,
        )
    except asyncio.TimeoutError:
        raise HTTPException(
            status_code=504,
            detail="Proposal generation timed out.",
        )
    finally:
        proposal_lock.release()