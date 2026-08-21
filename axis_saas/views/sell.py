"""
AXIS views – sell module.
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
def sell_separately(request, schema_name, mobile=False):
    """Page to search for a student and then redirect to fee collection for that student."""
    tenant = get_tenant(request, schema_name)
    search_query = request.GET.get('search', '').strip()
    grade_filter = request.GET.get('grade', '')
    section_filter = request.GET.get('section', '')
    search_results = []
    with schema_context(schema_name):
        students = Student.objects.all()
        if grade_filter:
            students = students.filter(grade=grade_filter)
        if section_filter:
            students = students.filter(section=section_filter)
        if search_query:
            students = students.filter(Q(name__icontains=search_query) | Q(roll_number__icontains=search_query) | Q(father_name__icontains=search_query) | Q(father_cnic__icontains=search_query) | Q(parent_mobile__icontains=search_query))
        if search_query or grade_filter or section_filter:
            search_results = list(students.order_by('name')[:20])
        else:
            search_results = []
        grades = list(Student.objects.values_list('grade', flat=True).distinct().order_by('grade'))
        sections = list(Student.objects.values_list('section', flat=True).distinct().order_by('section'))
    context = {'tenant': tenant, 'search_query': search_query, 'grade_filter': grade_filter, 'section_filter': section_filter, 'search_results': search_results, 'grades': grades, 'sections': sections, 'logo_url': tenant.school_logo.url if tenant.school_logo else None}
    template = 'mobile/sell_separately.html' if mobile else 'tenant/sell_separately.html'
    return render(request, template, context)

@require_tenant_type(['school'])
def mobile_sell_separately(request, schema_name):
    """Mobile version of sell separately page."""
    return sell_separately(request, schema_name, mobile=True)
