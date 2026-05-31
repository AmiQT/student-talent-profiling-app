"""
Payment Router - Proxy for ToyyibPay API
This router handles payment-related operations and proxies requests to ToyyibPay
to bypass CORS restrictions for Flutter Web.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
import httpx
import os
from typing import Optional

router = APIRouter(prefix="/api/payment", tags=["payment"])

# ToyyibPay Configuration
TOYYIBPAY_BASE_URL = os.getenv("TOYYIBPAY_BASE_URL", "https://dev.toyyibpay.com")
TOYYIBPAY_SECRET_KEY = os.getenv("TOYYIBPAY_SECRET_KEY", "")
TOYYIBPAY_CATEGORY_CODE = os.getenv("TOYYIBPAY_CATEGORY_CODE", "")


class CreateBillRequest(BaseModel):
    """Request model for creating a ToyyibPay bill"""
    bill_name: str
    bill_description: str
    bill_amount: float  # Amount in RM
    user_email: EmailStr
    user_phone: str
    user_name: str
    reference_id: Optional[str] = None


class CreateBillResponse(BaseModel):
    """Response model for bill creation"""
    success: bool
    bill_code: Optional[str] = None
    payment_url: Optional[str] = None
    error: Optional[str] = None


@router.post("/create-bill", response_model=CreateBillResponse)
async def create_bill(request: CreateBillRequest):
    """
    Create a ToyyibPay bill and return the bill code with payment URL.
    This endpoint proxies the request to ToyyibPay API to bypass CORS.
    """
    try:
        # Validate configuration
        if not TOYYIBPAY_SECRET_KEY:
            raise HTTPException(
                status_code=500,
                detail="ToyyibPay secret key not configured"
            )
        if not TOYYIBPAY_CATEGORY_CODE:
            raise HTTPException(
                status_code=500,
                detail="ToyyibPay category code not configured"
            )
        
        # Truncate bill name to 30 chars (ToyyibPay limit)
        truncated_name = request.bill_name[:27] + "..." if len(request.bill_name) > 30 else request.bill_name
        
        # Validate phone - use default if empty
        valid_phone = request.user_phone if request.user_phone else "0123456789"
        
        # Generate reference ID if not provided
        import time
        reference_id = request.reference_id or str(int(time.time() * 1000))
        
        # Prepare ToyyibPay request
        form_data = {
            "userSecretKey": TOYYIBPAY_SECRET_KEY,
            "categoryCode": TOYYIBPAY_CATEGORY_CODE,
            "billName": truncated_name,
            "billDescription": request.bill_description,
            "billPriceSetting": "1",  # Fixed amount
            "billPayorInfo": "1",  # Valid payor info required
            "billAmount": str(int(request.bill_amount * 100)),  # Amount in cents
            "billReturnUrl": "https://toyyibpay.com",
            "billCallbackUrl": "https://toyyibpay.com",
            "billExternalReferenceNo": reference_id,
            "billTo": request.user_name,
            "billEmail": request.user_email,
            "billPhone": valid_phone,
            "billSplitPayment": "0",
            "billPaymentChannel": "0",  # 0 = FPX, 2 = Credit Card
            "billContentEmail": "Thank you for your payment!",
            "billChargeToCustomer": "1",  # Customer pays fee
        }
        
        # Make request to ToyyibPay
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{TOYYIBPAY_BASE_URL}/index.php/api/createBill",
                data=form_data,
                timeout=30.0
            )
        
        print(f"ToyyibPay Response Status: {response.status_code}")
        print(f"ToyyibPay Response Body: {response.text}")
        
        if response.status_code == 200:
            data = response.json()
            
            # ToyyibPay returns array with BillCode on success
            if isinstance(data, list) and len(data) > 0:
                first_item = data[0]
                if isinstance(first_item, dict) and "BillCode" in first_item:
                    bill_code = first_item["BillCode"]
                    return CreateBillResponse(
                        success=True,
                        bill_code=bill_code,
                        payment_url=f"{TOYYIBPAY_BASE_URL}/{bill_code}"
                    )
                else:
                    # Error response from ToyyibPay
                    return CreateBillResponse(
                        success=False,
                        error=f"ToyyibPay error: {first_item}"
                    )
            elif isinstance(data, dict) and "BillCode" in data:
                bill_code = data["BillCode"]
                return CreateBillResponse(
                    success=True,
                    bill_code=bill_code,
                    payment_url=f"{TOYYIBPAY_BASE_URL}/{bill_code}"
                )
            else:
                return CreateBillResponse(
                    success=False,
                    error="Invalid response format from ToyyibPay"
                )
        else:
            return CreateBillResponse(
                success=False,
                error=f"ToyyibPay API error: {response.status_code}"
            )
            
    except httpx.TimeoutException:
        return CreateBillResponse(
            success=False,
            error="Request to ToyyibPay timed out"
        )
    except Exception as e:
        print(f"Error creating bill: {e}")
        return CreateBillResponse(
            success=False,
            error=str(e)
        )


@router.get("/health")
async def payment_health():
    """Health check for payment service"""
    return {
        "status": "ok",
        "service": "payment",
        "toyyibpay_configured": bool(TOYYIBPAY_SECRET_KEY and TOYYIBPAY_CATEGORY_CODE)
    }
