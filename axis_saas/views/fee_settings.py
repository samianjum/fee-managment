"""
AXIS views – fee_settings module.
"""

import re
from django.shortcuts import render, redirect, get_object_or_404
from django.http import JsonResponse, Http404
from django.contrib import messages
from django.db.models import Sum, Q, Exists, OuterRef, Max
from django.db.models.functions import TruncMonth, TruncDay
from django.db.models import Count
from django.core.paginator import Paginator
from django.db import connection
from django_tenants.utils import schema_context
from decimal import Decimal
from datetime import date, timedelta, datetime
from collections import defaultdict
import json
import re
from functools import wraps
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.views.decorators.http import require_http_methods
from ..models import SchoolClient, Student, FeeStructure, FeeRecord, PaymentTransaction, SchoolFeeSettings, Product, ProductCategory
from ..forms import StudentForm, FeeCollectionForm, FeeSettingsForm, FeeStructureForm, FamilyPaymentForm
from django.http import JsonResponse, HttpResponse
from django.db import transaction
from ..models import ManualGenerationLog

from .helpers import *

@require_tenant_type(['school'])
@require_school_feature('fee_settings')
def fee_settings(request, schema_name, force_mobile=False):
    """Fee settings page with automation controls and extra charges."""
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        settings, created = SchoolFeeSettings.objects.get_or_create(pk=1)
        if request.method == 'POST':
            if 'toggle_automation' in request.POST:
                settings.automation_enabled = not settings.automation_enabled
                settings.save(update_fields=['automation_enabled'])
                messages.success(request, f"Automation {('enabled' if settings.automation_enabled else 'disabled')}.")
                return redirect('fee_settings', schema_name=schema_name)
            form = FeeSettingsForm(request.POST, instance=settings)
            if form.is_valid():
                form.save()
                extra_charges_json = request.POST.get('extra_charges_json', '[]')
                try:
                    import json
                    extra_charges = json.loads(extra_charges_json)
                    if isinstance(extra_charges, list):
                        settings.default_extra_charges = extra_charges
                        settings.save(update_fields=['default_extra_charges'])
                except Exception as e:
                    messages.error(request, f'Error saving extra charges: {e}')
                messages.success(request, 'Fee settings updated successfully.')
                return redirect('fee_settings', schema_name=schema_name)
        else:
            form = FeeSettingsForm(instance=settings)
        extra_charges = settings.default_extra_charges or []
        total_extra = sum((ch.get('amount', 0) for ch in extra_charges), 0)
        context = {'tenant': tenant, 'form': form, 'settings': settings, 'extra_charges': extra_charges, 'total_extra': total_extra, 'automation_enabled': settings.automation_enabled, 'logo_url': tenant.school_logo.url if tenant.school_logo else None}
        template = 'mobile/fee_settings.html' if force_mobile else 'tenant/fee_settings.html'
        return render(request, template, context)

@require_tenant_type(['school'])
@require_school_feature('fee_settings')
def mobile_fee_settings(request, schema_name):
    """Mobile version of fee settings page."""
    return fee_settings(request, schema_name, force_mobile=True)
