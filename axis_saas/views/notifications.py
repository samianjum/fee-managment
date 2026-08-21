"""
AXIS views – notifications module.
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
def dismiss_notification(request, schema_name):
    from django.http import JsonResponse
    from ..models import FeeRecord
    from django.db.models import Max
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        current_max_id = FeeRecord.objects.aggregate(Max('id'))['id__max'] or 0
        request.session['last_fee_record_id'] = current_max_id
        return JsonResponse({'status': 'ok'})

@require_tenant_type(['school'])
def notifications_list_api(request, schema_name):
    """Return list of notifications for the tenant, with unread count."""
    from django.http import JsonResponse
    from ..models import Notification
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        notifs = Notification.objects.all()[:50]
        unread_count = Notification.objects.filter(is_read=False).count()
        data = [{'id': n.id, 'message': n.message, 'link': n.link, 'is_read': n.is_read, 'created_at': n.created_at.isoformat()} for n in notifs]
        return JsonResponse({'notifications': data, 'unread_count': unread_count})

@csrf_exempt
@require_tenant_type(['school'])
def mark_notification_read_api(request, schema_name):
    """Mark a single notification as read."""
    from django.http import JsonResponse
    from ..models import Notification
    from django_tenants.utils import schema_context
    import json
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    try:
        data = json.loads(request.body)
        notif_id = data.get('id')
        if not notif_id:
            return JsonResponse({'error': 'Missing id'}, status=400)
        with schema_context(schema_name):
            notif = Notification.objects.get(id=notif_id)
            notif.is_read = True
            notif.save()
            return JsonResponse({'success': True})
    except Notification.DoesNotExist:
        return JsonResponse({'error': 'Notification not found'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=400)

@csrf_exempt
@require_tenant_type(['school'])
def mark_all_notifications_read_api(request, schema_name):
    """Mark all notifications as read for the tenant."""
    from django.http import JsonResponse
    from ..models import Notification
    from django_tenants.utils import schema_context
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    with schema_context(schema_name):
        updated = Notification.objects.filter(is_read=False).update(is_read=True)
        return JsonResponse({'success': True, 'updated': updated})
