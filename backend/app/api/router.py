from fastapi import APIRouter

from app.modules.accounts.router import auth_router, users_router
from app.modules.catalog.router import router as catalog_router
from app.modules.favorites.router import router as favorites_router
from app.modules.parties.router import router as parties_router
from app.modules.vendors.router import admin_router
from app.modules.vendors.router import router as vendors_router

API_PREFIX = "/api/v1"

api_router = APIRouter(prefix=API_PREFIX)
api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(catalog_router)
api_router.include_router(favorites_router)
api_router.include_router(parties_router)
api_router.include_router(vendors_router)
api_router.include_router(admin_router)
