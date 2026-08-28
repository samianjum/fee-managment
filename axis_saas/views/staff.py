# axis_saas/views/staff.py
"""
AXIS views – staff module.
"""

import re
from django.shortcuts import render, redirect, get_object_or_404
from django.http import JsonResponse, Http404
from django.contrib import messages
from django.db.models import Q, Sum
from django.core.paginator import Paginator
from django.db import connection
from django_tenants.utils import schema_context
from decimal import Decimal
from datetime import date, timedelta, datetime
from collections import defaultdict
import json
from functools import wraps
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.views.decorators.http import require_http_methods

from ..models import SchoolClient, Staff
from ..forms import StaffForm
from .helpers import (
    get_tenant, is_mobile_user_agent, require_tenant_type, require_school_feature,
    MOBILE_AGENT_RE
)

# ========== STAFF LIST ==========

@require_tenant_type(['school'])
@require_school_feature('staff_management')
def staff_list(request, schema_name):
    """List all staff members."""
    print(f"[DEBUG] staff_list called for schema: {schema_name}")
    if is_mobile_user_agent(request):
        return redirect('mobile_staff_list', schema_name=schema_name)

    tenant = get_tenant(request, schema_name)
    context = get_staff_list_context(request, schema_name)
    return render(request, 'tenant/staff_list.html', context)

@require_tenant_type(['school'])
@require_school_feature('staff_management')
def mobile_staff_list(request, schema_name):
    """Mobile version of staff list."""
    print(f"[DEBUG] mobile_staff_list called for schema: {schema_name}")
    context = get_staff_list_context(request, schema_name)
    return render(request, 'mobile/staff_list.html', context)

def get_staff_list_context(request, schema_name):
    tenant = get_tenant(request, schema_name)
    query = request.GET.get('q', '')
    department = request.GET.get('department', '')
    status = request.GET.get('status', '')
    page_number = request.GET.get('page', 1)

    with schema_context(schema_name):
        staff_qs = Staff.objects.all()
        if query:
            staff_qs = staff_qs.filter(
                Q(full_name__icontains=query) |
                Q(staff_id__icontains=query) |
                Q(email__icontains=query) |
                Q(job_title__icontains=query) |
                Q(phone__icontains=query)
            )
        if department:
            staff_qs = staff_qs.filter(department=department)
        if status:
            staff_qs = staff_qs.filter(status=status)

        staff_qs = staff_qs.order_by('-created_on')
        paginator = Paginator(staff_qs, 20)
        page_obj = paginator.get_page(page_number)

        departments = list(Staff.objects.values_list('department', flat=True).distinct().order_by('department'))
        status_choices = Staff.STATUS_CHOICES
        total_active = Staff.objects.filter(status='active').count()

    return {
        'tenant': tenant,
        'staff': page_obj,
        'departments': departments,
        'status_choices': status_choices,
        'search_query': query,
        'total_active': total_active,
        'logo_url': tenant.school_logo.url if tenant.school_logo else None,
    }

# ========== STAFF PROFILE ==========

@require_tenant_type(['school'])
@require_school_feature('staff_management')
def staff_profile(request, schema_name, staff_id):
    if is_mobile_user_agent(request):
        return redirect('mobile_staff_profile', schema_name=schema_name, staff_id=staff_id)
    context = get_staff_profile_context(request, schema_name, staff_id)
    return render(request, 'tenant/staff_profile.html', context)

@require_tenant_type(['school'])
@require_school_feature('staff_management')
def mobile_staff_profile(request, schema_name, staff_id):
    context = get_staff_profile_context(request, schema_name, staff_id)
    return render(request, 'mobile/staff_profile.html', context)

def get_staff_profile_context(request, schema_name, staff_id):
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        staff = get_object_or_404(Staff, id=staff_id)
    return {
        'tenant': tenant,
        'staff': staff,
        'logo_url': tenant.school_logo.url if tenant.school_logo else None,
    }

# ========== ADD / EDIT STAFF ==========

@require_tenant_type(['school'])
@require_school_feature('staff_management')
def staff_add(request, schema_name):
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        if request.method == 'POST':
            form = StaffForm(request.POST, request.FILES)
            if form.is_valid():
                staff = form.save()
                messages.success(request, f"Staff {staff.full_name} added successfully. ID: {staff.staff_id}")
                return redirect('staff_list', schema_name=schema_name)
        else:
            form = StaffForm()
        departments = Staff.DEPARTMENT_CHOICES
    context = {
        'tenant': tenant,
        'form': form,
        'departments': departments,
        'logo_url': tenant.school_logo.url if tenant.school_logo else None,
    }
    return render(request, 'tenant/staff_form.html', context)

@require_tenant_type(['school'])
@require_school_feature('staff_management')
def staff_add_mobile(request, schema_name):
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        if request.method == 'POST':
            form = StaffForm(request.POST, request.FILES)
            if form.is_valid():
                staff = form.save()
                messages.success(request, f"Staff {staff.full_name} added successfully.")
                return redirect('mobile_staff_list', schema_name=schema_name)
        else:
            form = StaffForm()
        departments = Staff.DEPARTMENT_CHOICES
    context = {
        'tenant': tenant,
        'form': form,
        'departments': departments,
        'logo_url': tenant.school_logo.url if tenant.school_logo else None,
    }
    return render(request, 'mobile/staff_form.html', context)

@require_tenant_type(['school'])
@require_school_feature('staff_management')
def staff_edit(request, schema_name, staff_id):
    tenant = get_tenant(request, schema_name)
    with schema_context(schema_name):
        staff = get_object_or_404(Staff, id=staff_id)
        if request.method == 'POST':
            form = StaffForm(request.POST, request.FILES, instance=staff)
            if form.is_valid():
                form.save()
                messages.success(request, f"Staff {staff.full_name} updated successfully.")
                if is_mobile_user_agent(request):
                    return redirect('mobile_staff_profile', schema_name=schema_name, staff_id=staff.id)
                return redirect('staff_profile', schema_name=schema_name, staff_id=staff.id)
        else:
            form = StaffForm(instance=staff)
        departments = Staff.DEPARTMENT_CHOICES
    context = {
        'tenant': tenant,
        'form': form,
        'staff': staff,
        'departments': departments,
        'logo_url': tenant.school_logo.url if tenant.school_logo else None,
    }
    return render(request, 'tenant/staff_form.html', context)

# ========== STAFF SEARCH API ==========

@require_tenant_type(['school'])
@require_school_feature('staff_management')
def staff_search_api(request, schema_name):
    q = request.GET.get('q', '')
    with schema_context(schema_name):
        staff = Staff.objects.filter(
            Q(full_name__icontains=q) |
            Q(staff_id__icontains=q) |
            Q(email__icontains=q) |
            Q(phone__icontains=q)
        )[:10]
        data = [{'id': s.id, 'name': s.full_name, 'staff_id': s.staff_id, 'job_title': s.job_title} for s in staff]
    return JsonResponse(data, safe=False)
