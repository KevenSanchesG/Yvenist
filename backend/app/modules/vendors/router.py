import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.api.deps import AdminUser, CurrentUser, DbSession, get_admin_user
from app.modules.catalog.models import ListingStatus
from app.modules.vendors.models import VendorStatus
from app.modules.vendors.schemas import (
    AdminListingResponse,
    AdminListingsResponse,
    AdminVendorResponse,
    AdminVendorsResponse,
    ApproveVendorRequest,
    OnboardingRequest,
    OnboardingResponse,
    RejectRequest,
    VendorListingResponse,
    VendorListingsResponse,
    VendorResponse,
)
from app.modules.vendors.service import VendorService

router = APIRouter(prefix="/vendors", tags=["Fornecedores"])
# Toda rota de administração exige usuário administrador.
admin_router = APIRouter(
    prefix="/admin",
    tags=["Administração"],
    dependencies=[Depends(get_admin_user)],
)


def get_vendor_service(db: DbSession) -> VendorService:
    return VendorService(db)


VendorServiceDep = Annotated[VendorService, Depends(get_vendor_service)]


@router.get("/me", summary="Cadastro de fornecedor do usuário")
def get_my_vendor_profile(user: CurrentUser, service: VendorServiceDep) -> VendorResponse:
    return VendorResponse.from_profile(service.get_profile(user))


@router.get("/me/listings", summary="Anúncios do fornecedor, em qualquer status")
def list_my_listings(user: CurrentUser, service: VendorServiceDep) -> VendorListingsResponse:
    return VendorListingsResponse(
        items=[
            VendorListingResponse.from_listing(listing)
            for listing in service.list_own_listings(user)
        ]
    )


@router.post(
    "/onboarding",
    status_code=status.HTTP_201_CREATED,
    summary="Envia o cadastro de fornecedor e um anúncio para análise",
)
def submit_onboarding(
    data: OnboardingRequest,
    user: CurrentUser,
    service: VendorServiceDep,
) -> OnboardingResponse:
    profile, listing = service.submit_onboarding(user, data)
    return OnboardingResponse(
        vendor=VendorResponse.from_profile(profile),
        listing=VendorListingResponse.from_listing(listing),
    )


@admin_router.get("/vendors", summary="Cadastros de fornecedor por status")
def list_vendors(
    service: VendorServiceDep,
    vendor_status: Annotated[VendorStatus, Query(alias="status")] = VendorStatus.PENDING_REVIEW,
) -> AdminVendorsResponse:
    return AdminVendorsResponse(
        items=[
            AdminVendorResponse.from_profile(profile)
            for profile in service.list_vendors_by_status(vendor_status)
        ]
    )


@admin_router.post("/vendors/{vendor_id}/approve", summary="Aprova um cadastro de fornecedor")
def approve_vendor(
    vendor_id: uuid.UUID,
    admin: AdminUser,
    service: VendorServiceDep,
    data: ApproveVendorRequest | None = None,
) -> AdminVendorResponse:
    options = data or ApproveVendorRequest()
    profile = service.approve_vendor(
        admin, vendor_id, publish_pending_listings=options.publish_pending_listings
    )
    return AdminVendorResponse.from_profile(profile)


@admin_router.post(
    "/vendors/{vendor_id}/reject",
    summary="Recusa um cadastro de fornecedor e os anúncios que aguardavam com ele",
)
def reject_vendor(
    vendor_id: uuid.UUID,
    data: RejectRequest,
    admin: AdminUser,
    service: VendorServiceDep,
) -> AdminVendorResponse:
    return AdminVendorResponse.from_profile(
        service.reject_vendor(admin, vendor_id, reason=data.reason)
    )


@admin_router.get("/listings", summary="Anúncios por status, com o fornecedor de cada um")
def list_listings(
    service: VendorServiceDep,
    listing_status: Annotated[ListingStatus, Query(alias="status")] = ListingStatus.PENDING_REVIEW,
) -> AdminListingsResponse:
    return AdminListingsResponse(
        items=[
            AdminListingResponse.from_review(listing, vendor)
            for listing, vendor in service.list_listings_by_status(listing_status)
        ]
    )


@admin_router.post("/listings/{listing_id}/approve", summary="Publica um anúncio")
def approve_listing(listing_id: uuid.UUID, service: VendorServiceDep) -> AdminListingResponse:
    return AdminListingResponse.from_review(*service.approve_listing(listing_id))


@admin_router.post("/listings/{listing_id}/reject", summary="Recusa um anúncio")
def reject_listing(
    listing_id: uuid.UUID,
    data: RejectRequest,
    service: VendorServiceDep,
) -> AdminListingResponse:
    return AdminListingResponse.from_review(*service.reject_listing(listing_id, reason=data.reason))
