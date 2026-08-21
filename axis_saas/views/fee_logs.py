"""
AXIS views – fee_logs module.
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

def fee_logs(request, schema_name):
    """Display fee generation logs with filters."""
    from django.shortcuts import render
    from django.core.paginator import Paginator
    from ..models import ManualGenerationLog
    from django_tenants.utils import schema_context
    tenant = get_tenant(request, schema_name)
    month = request.GET.get('month')
    year = request.GET.get('year')
    log_type = request.GET.get('log_type', '')
    page = request.GET.get('page', 1)
    with schema_context(schema_name):
        logs_qs = ManualGenerationLog.objects.all()
        if month:
            logs_qs = logs_qs.filter(month=month)
        if year:
            logs_qs = logs_qs.filter(year=year)
        if log_type:
            logs_qs = logs_qs.filter(log_type=log_type)
        logs_qs = logs_qs.order_by('-generated_at')
        paginator = Paginator(logs_qs, 20)
        logs_page = paginator.get_page(page)
        months = range(1, 13)
        years = list(range(2020, date.today().year + 2))
        log_types = ManualGenerationLog.LOG_TYPE_CHOICES
        for log in logs_page:
            log.voucher_url = f'/portal/{schema_name}/vouchers/mobile/?month={log.month}&year={log.year}&tab=pending'
        context = {'tenant': tenant, 'logs': logs_page, 'months': months, 'years': years, 'log_types': log_types, 'selected_month': month, 'selected_year': year, 'selected_log_type': log_type, 'logo_url': tenant.school_logo.url if tenant.school_logo else None}
        return render(request, 'tenant/fee_logs.html', context)

def mobile_fee_logs(request, schema_name):
    """Mobile version of fee logs."""
    from django.shortcuts import render
    from django.core.paginator import Paginator
    from ..models import ManualGenerationLog
    from datetime import date
    from django_tenants.utils import schema_context
    tenant = get_tenant(request, schema_name)
    month = request.GET.get('month')
    year = request.GET.get('year')
    log_type = request.GET.get('log_type', '')
    page = request.GET.get('page', 1)
    with schema_context(schema_name):
        logs_qs = ManualGenerationLog.objects.all()
        if month:
            logs_qs = logs_qs.filter(month=month)
        if year:
            logs_qs = logs_qs.filter(year=year)
        if log_type:
            logs_qs = logs_qs.filter(log_type=log_type)
        logs_qs = logs_qs.order_by('-generated_at')
        paginator = Paginator(logs_qs, 20)
        logs_page = paginator.get_page(page)
        months = range(1, 13)
        years = list(range(2020, date.today().year + 2))
        log_types = ManualGenerationLog.LOG_TYPE_CHOICES
        for log in logs_page:
            log.voucher_url = f'/portal/{schema_name}/vouchers/mobile/?month={log.month}&year={log.year}&tab=pending'
        context = {'tenant': tenant, 'logs': logs_page, 'months': months, 'years': years, 'log_types': log_types, 'selected_month': month, 'selected_year': year, 'selected_log_type': log_type, 'logo_url': tenant.school_logo.url if tenant.school_logo else None}
    return render(request, 'mobile/fee_logs.html', context)
