"""
AXIS views – dashboard module.
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
@require_school_feature('dashboard')
def dashboard(request, schema_name):
    tenant = get_tenant(request, schema_name)
    context = get_dashboard_context(tenant, schema_name)
    return render(request, 'tenant/dashboard.html', context)

@require_tenant_type(['school'])
@require_school_feature('dashboard')
def mobile_dashboard(request, schema_name):
    tenant = get_tenant(request, schema_name)
    context = get_dashboard_context(tenant, schema_name)
    with schema_context(schema_name):
        from ..models import FeeRecord
        current_max_id = FeeRecord.objects.aggregate(Max('id'))['id__max'] or 0
        last_seen_id = request.session.get('last_fee_record_id')
        if last_seen_id is None:
            request.session['last_fee_record_id'] = current_max_id
            show_banner = False
            new_count = 0
        elif current_max_id > last_seen_id:
            show_banner = True
            new_count = current_max_id - last_seen_id
        else:
            show_banner = False
            new_count = 0
        if request.GET.get('dismiss_notification') == '1':
            request.session['last_fee_record_id'] = current_max_id
            show_banner = False
            new_count = 0
    context['show_notification_banner'] = show_banner
    context['new_vouchers_count'] = new_count
    with schema_context(schema_name):
        from ..models import FeeRecord
        latest_fee = FeeRecord.objects.order_by('-id').first()
        if latest_fee:
            context['voucher_month'] = latest_fee.month
            context['voucher_year'] = latest_fee.year
        else:
            context['voucher_month'] = None
            context['voucher_year'] = None
    return render(request, 'mobile/dashboard.html', context)

@require_tenant_type(['school'])
@require_school_feature('dashboard')
def mobile_more(request, schema_name):
    tenant = get_tenant(request, schema_name)
    return render(request, 'mobile/more.html', {'tenant': tenant})
