"""
AXIS views – search module.
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
def global_search_api(request, schema_name):
    mobile = request.GET.get('mobile') == '1'
    'API endpoint for global search across students, fees, payments, products, categories.'
    from django.db.models import Q
    from ..models import Student, FeeRecord, PaymentTransaction, Product, ProductCategory
    q = request.GET.get('q', '').strip()
    if len(q) < 2:
        return JsonResponse({'error': 'Query too short'}, status=400)
    results = {}
    students = Student.objects.filter(Q(name__icontains=q) | Q(roll_number__icontains=q) | Q(father_name__icontains=q) | Q(father_cnic__icontains=q) | Q(parent_mobile__icontains=q))[:10]
    results['students'] = [{'title': s.name, 'subtitle': f'Roll: {s.roll_number} | {s.grade} - {s.section}', 'type': 'Student', 'url': f"/portal/{schema_name}/students/{('mobile/' if mobile else '')}{s.id}/"} for s in students]
    fees = FeeRecord.objects.filter(Q(student__name__icontains=q) | Q(month__icontains=q) | Q(year__icontains=q))[:10]
    results['fees'] = [{'title': f'{fr.student.name} - {fr.month}/{fr.year}', 'subtitle': f'Amount: ₹{fr.total_amount} | Status: {fr.get_status_display()}', 'type': 'Fee', 'url': f"/portal/{schema_name}/students/{('mobile/' if mobile else '')}{fr.student.id}/"} for fr in fees]
    payments = PaymentTransaction.objects.filter(Q(receipt_number__icontains=q) | Q(student__name__icontains=q))[:10]
    results['payments'] = [{'title': p.receipt_number, 'subtitle': f'{p.student.name} - ₹{p.amount} on {p.payment_date}', 'type': 'Payment', 'url': f"/portal/{schema_name}/fee/receipt/{('mobile/' if mobile else '')}{p.id}/"} for p in payments]
    products = Product.objects.filter(Q(name__icontains=q) | Q(sku__icontains=q))[:10]
    results['products'] = [{'title': p.name, 'subtitle': f'SKU: {p.sku} | Price: ₹{p.selling_price} | Stock: {p.quantity}', 'type': 'Product', 'url': f"/portal/{schema_name}/stock/product/{p.id}/{('mobile/' if mobile else '')}"} for p in products]
    categories = ProductCategory.objects.filter(name__icontains=q)[:10]
    results['categories'] = [{'title': c.name, 'subtitle': c.description or '', 'type': 'Category', 'url': f"/portal/{schema_name}/stock/{('mobile/' if mobile else '')}?category={c.id}"} for c in categories]
    return JsonResponse(results)
