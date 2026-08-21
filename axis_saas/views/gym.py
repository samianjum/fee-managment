"""
AXIS views – gym module.
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

def gym_generate_subscription(request, schema_name, customer_id):
    """Generate a new subscription for a gym customer (multi-month)."""
    from django.http import JsonResponse
    from django.utils import timezone
    from decimal import Decimal
    from ..models import GymCustomer, GymSubscription, GymSettings
    from datetime import date, timedelta
    from calendar import monthrange
    import json
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        try:
            customer = GymCustomer.objects.get(id=customer_id)
        except GymCustomer.DoesNotExist:
            return JsonResponse({'error': 'Customer not found'}, status=404)
        if request.method != 'POST':
            return JsonResponse({'error': 'Only POST allowed'}, status=405)
        try:
            data = json.loads(request.body)
            months = int(data.get('months', 1))
            monthly_fee = Decimal(str(data.get('fee', customer.monthly_fee)))
        except (ValueError, TypeError, json.JSONDecodeError):
            return JsonResponse({'error': 'Invalid data. Provide months and fee.'}, status=400)
        if months < 1 or months > 12:
            return JsonResponse({'error': 'Months must be between 1 and 12'}, status=400)
        today = date.today()
        settings = GymSettings.objects.first()
        if not settings:
            settings = GymSettings.objects.create()
        due_offset = settings.due_date_offset
        created = []
        for i in range(months):
            target_month = today.month + i
            target_year = today.year
            while target_month > 12:
                target_month -= 12
                target_year += 1
            due_day = customer.membership_start.day if customer.membership_start else 1
            max_day = monthrange(target_year, target_month)[1]
            due_day = min(due_day, max_day)
            due_date = date(target_year, target_month, due_day) + timedelta(days=due_offset)
            existing = GymSubscription.objects.filter(customer=customer, month=target_month, year=target_year).first()
            if existing:
                if existing.is_cancelled:
                    existing.amount = monthly_fee
                    existing.paid_amount = Decimal('0')
                    existing.due_date = due_date
                    existing.status = 'pending'
                    existing.is_cancelled = False
                    existing.cancelled_on = None
                    existing.save()
                    created.append(existing)
                else:
                    continue
            else:
                sub = GymSubscription.objects.create(customer=customer, month=target_month, year=target_year, amount=monthly_fee, due_date=due_date, status='pending')
                created.append(sub)
        if created:
            return JsonResponse({'message': f'Generated {len(created)} subscription(s).'})
        else:
            return JsonResponse({'message': 'No new subscriptions created (already exist).'})

@require_tenant_type(['gym'])
def gym_cancel_subscription(request, schema_name, subscription_id):
    """Cancel a gym subscription with partial refund calculation."""
    from django.http import JsonResponse
    from django.utils import timezone
    from decimal import Decimal
    from ..models import GymSubscription
    from datetime import date
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        try:
            sub = GymSubscription.objects.get(id=subscription_id)
        except GymSubscription.DoesNotExist:
            return JsonResponse({'error': 'Subscription not found'}, status=404)
        if sub.is_cancelled:
            return JsonResponse({'error': 'Already cancelled'}, status=400)
        if request.method != 'POST':
            return JsonResponse({'error': 'Only POST allowed'}, status=405)
        today = date.today()
        month_start = date(sub.year, sub.month, 1)
        if sub.month == 12:
            next_month = date(sub.year + 1, 1, 1)
        else:
            next_month = date(sub.year, sub.month + 1, 1)
        days_in_month = (next_month - month_start).days
        days_used = max(0, (today - month_start).days)
        if days_used >= days_in_month:
            refund = Decimal('0')
        else:
            daily_rate = sub.amount / Decimal(days_in_month)
            remaining_days = days_in_month - days_used
            refund = daily_rate * Decimal(remaining_days)
        sub.status = 'cancelled'
        sub.is_cancelled = True
        sub.cancelled_on = today
        sub.save()
        return JsonResponse({'message': f'Subscription cancelled. Refund amount (estimated): ₹{refund:.2f}', 'refund': float(refund)})

@require_tenant_type(['gym'])
def gym_update_subscription(request, schema_name, subscription_id):
    """Update amount of an existing unpaid subscription."""
    from django.http import JsonResponse
    from django_tenants.utils import schema_context
    from ..models import GymSubscription
    import json
    from decimal import Decimal
    with schema_context(schema_name):
        try:
            sub = GymSubscription.objects.get(id=subscription_id)
        except GymSubscription.DoesNotExist:
            return JsonResponse({'error': 'Subscription not found'}, status=404)
        if sub.paid_amount > 0:
            return JsonResponse({'error': 'Cannot edit a subscription that already has payments'}, status=400)
        if sub.is_cancelled:
            return JsonResponse({'error': 'Cancelled subscriptions cannot be edited'}, status=400)
        if request.method != 'POST':
            return JsonResponse({'error': 'Only POST allowed'}, status=405)
        try:
            data = json.loads(request.body)
            new_amount = Decimal(str(data.get('amount')))
            if new_amount <= 0:
                raise ValueError
        except (ValueError, TypeError, json.JSONDecodeError):
            return JsonResponse({'error': 'Invalid amount'}, status=400)
        sub.amount = new_amount
        sub.save()
        return JsonResponse({'message': f'Subscription amount updated to ₹{new_amount}'})

def gym_edit_attendance(request, schema_name, attendance_id):
    """Edit an existing attendance record (within 7 hours of check-in)."""
    from django.http import JsonResponse
    from django.utils import timezone
    from ..models import GymAttendance
    from django_tenants.utils import schema_context
    import json
    from datetime import datetime
    with schema_context(schema_name):
        try:
            att = GymAttendance.objects.get(id=attendance_id)
        except GymAttendance.DoesNotExist:
            return JsonResponse({'error': 'Attendance not found'}, status=404)
        if request.method == 'GET':
            return JsonResponse({'id': att.id, 'check_in': att.check_in.isoformat() if att.check_in else '', 'check_out': att.check_out.isoformat() if att.check_out else '', 'notes': att.notes or ''})
        if request.method == 'POST':
            if not att.is_editable():
                return JsonResponse({'error': 'Edit window expired (7 hours after check-in).'}, status=403)
            try:
                data = request.POST
                check_in_str = data.get('check_in')
                check_out_str = data.get('check_out')
                notes = data.get('notes', '')
                if check_in_str:
                    att.check_in = datetime.fromisoformat(check_in_str)
                if check_out_str:
                    att.check_out = datetime.fromisoformat(check_out_str)
                att.notes = notes
                if att.check_out:
                    att.duration_minutes = int((att.check_out - att.check_in).total_seconds() / 60)
                else:
                    att.duration_minutes = None
                att.save()
                return JsonResponse({'message': 'Attendance updated successfully.'})
            except Exception as e:
                return JsonResponse({'error': str(e)}, status=400)
        return JsonResponse({'error': 'Method not allowed'}, status=405)

@require_tenant_type(['gym'])
def gym_dashboard(request, schema_name):
    """Gym dashboard view."""
    from django.shortcuts import render
    from django.utils import timezone
    from django.db.models import Sum, Count
    from ..models import GymCustomer, GymPayment, GymAttendance, GymSubscription
    from datetime import date, timedelta
    from decimal import Decimal
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        today = timezone.localdate()
        today_checkins = GymAttendance.objects.filter(date=today).count()
        active_customers = GymCustomer.objects.filter(status='active').count()
        first_day_month = today.replace(day=1)
        month_revenue = GymPayment.objects.filter(payment_date__gte=first_day_month).aggregate(Sum('amount'))['amount__sum'] or Decimal(0)
        expiring_soon = GymCustomer.objects.filter(status='active', membership_end__gte=today, membership_end__lte=today + timedelta(days=7)).count()
        recent_payments = list(GymPayment.objects.select_related('customer').order_by('-payment_date')[:5])
        months_labels = []
        months_amounts = []
        for i in range(5, -1, -1):
            m = today.month - i
            y = today.year
            if m <= 0:
                m += 12
                y -= 1
            total = GymPayment.objects.filter(payment_date__year=y, payment_date__month=m).aggregate(Sum('amount'))['amount__sum'] or 0
            months_labels.append(f'{m}/{y}')
            months_amounts.append(float(total))
        context = {'tenant': get_tenant(request, schema_name), 'today_checkins': today_checkins, 'active_customers': active_customers, 'month_revenue': month_revenue, 'expiring_soon': expiring_soon, 'recent_payments': recent_payments, 'months_labels': months_labels, 'months_amounts': months_amounts, 'today': today, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_dashboard.html', context)

@require_tenant_type(['gym'])
def gym_customer_list(request, schema_name):
    """List all gym customers."""
    from django.shortcuts import render
    from django.db.models import Sum
    from ..models import GymCustomer, GymSubscription
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        q = request.GET.get('q', '')
        status_filter = request.GET.get('status', '')
        customers = GymCustomer.objects.all()
        if q:
            customers = customers.filter(name__icontains=q) | customers.filter(phone__icontains=q)
        if status_filter:
            customers = customers.filter(status=status_filter)
        for c in customers:
            pending = sum((s.remaining for s in c.subscriptions.filter(status__in=['pending', 'partial', 'overdue'])))
            c.pending_amount = pending
        status_choices = GymCustomer.STATUS_CHOICES
        context = {'tenant': get_tenant(request, schema_name), 'customers': customers, 'status_choices': status_choices, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_customer_list.html', context)

@require_tenant_type(['gym'])
def gym_customer_add(request, schema_name):
    """Add a new gym customer."""
    from django.shortcuts import render, redirect
    from ..forms import GymCustomerForm
    from django.contrib import messages
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        if request.method == 'POST':
            form = GymCustomerForm(request.POST, request.FILES)
            if form.is_valid():
                customer = form.save()
                messages.success(request, f'Customer {customer.name} added successfully.')
                return redirect('gym_customer_profile', schema_name=schema_name, customer_id=customer.id)
        else:
            form = GymCustomerForm()
        context = {'tenant': get_tenant(request, schema_name), 'form': form, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_customer_form.html', context)

@require_tenant_type(['gym'])
def gym_customer_edit(request, schema_name, customer_id):
    """Edit an existing gym customer."""
    from django.shortcuts import render, redirect, get_object_or_404
    from ..forms import GymCustomerForm
    from ..models import GymCustomer
    from django.contrib import messages
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        customer = get_object_or_404(GymCustomer, id=customer_id)
        if request.method == 'POST':
            form = GymCustomerForm(request.POST, request.FILES, instance=customer)
            if form.is_valid():
                form.save()
                messages.success(request, f'Customer {customer.name} updated.')
                return redirect('gym_customer_profile', schema_name=schema_name, customer_id=customer.id)
        else:
            form = GymCustomerForm(instance=customer)
        context = {'tenant': get_tenant(request, schema_name), 'form': form, 'customer': customer, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_customer_form.html', context)

@require_tenant_type(['gym'])
def gym_customer_profile(request, schema_name, customer_id):
    """Display customer profile with subscriptions and payments."""
    from django.shortcuts import render, get_object_or_404
    from ..models import GymCustomer, GymSubscription, GymPayment, GymAttendance
    from django_tenants.utils import schema_context
    from django.utils import timezone
    with schema_context(schema_name):
        customer = get_object_or_404(GymCustomer, id=customer_id)
        subscriptions = customer.subscriptions.all().order_by('-year', '-month')
        payments = customer.payments.all().order_by('-payment_date')
        attendances = customer.attendances.all().order_by('-date')
        for a in attendances:
            a.can_edit = a.is_editable()
        total_fee = subscriptions.aggregate(Sum('amount'))['amount__sum'] or 0
        total_paid = payments.aggregate(Sum('amount'))['amount__sum'] or 0
        pending_total = total_fee - total_paid
        context = {'tenant': get_tenant(request, schema_name), 'customer': customer, 'subscriptions': subscriptions, 'payments': payments, 'attendances': attendances, 'total_fee': total_fee, 'total_paid': total_paid, 'pending_total': pending_total, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_customer_profile.html', context)

@require_tenant_type(['gym'])
def gym_payment(request, schema_name, customer_id=None):
    """Collect payment for gym customer."""
    from django.shortcuts import render, redirect, get_object_or_404
    from django.contrib import messages
    from decimal import Decimal
    from ..models import GymCustomer, GymSubscription, GymPayment
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        customers_with_pending = []
        for c in GymCustomer.objects.filter(status='active'):
            pending = sum((s.remaining for s in c.subscriptions.filter(status__in=['pending', 'partial', 'overdue'])))
            if pending > 0:
                c.pending_amount = pending
                customers_with_pending.append(c)
        customers_with_pending.sort(key=lambda x: x.pending_amount, reverse=True)
        selected_customer = None
        total_pending = 0
        pending_subs = []
        if customer_id:
            selected_customer = get_object_or_404(GymCustomer, id=customer_id)
            pending_subs = selected_customer.subscriptions.filter(status__in=['pending', 'partial', 'overdue']).order_by('due_date')
            total_pending = sum((s.remaining for s in pending_subs))
        if request.method == 'POST':
            cust_id = request.POST.get('customer_id')
            amount = request.POST.get('amount')
            payment_mode = request.POST.get('payment_mode')
            remarks = request.POST.get('remarks', '')
            if cust_id and amount:
                try:
                    customer = GymCustomer.objects.get(id=cust_id)
                    amount = Decimal(amount)
                    pending_subs_list = customer.subscriptions.filter(status__in=['pending', 'partial', 'overdue']).order_by('due_date')
                    total_pending_sum = sum((s.remaining for s in pending_subs_list))
                    if amount > total_pending_sum:
                        messages.error(request, f'Amount exceeds total pending (₹{total_pending_sum})')
                        return redirect('gym_payment', schema_name=schema_name, customer_id=customer.id)
                    remaining = amount
                    paid_subs = []
                    for sub in pending_subs_list:
                        if remaining <= 0:
                            break
                        due = sub.remaining_total
                        if remaining >= due:
                            sub.paid_amount = sub.total_amount
                            remaining -= due
                        else:
                            sub.paid_amount += remaining
                            remaining = 0
                        sub.save()
                        paid_subs.append(sub)
                    payment = GymPayment.objects.create(customer=customer, amount=amount, payment_mode=payment_mode, payment_type='full' if remaining == 0 else 'partial', remarks=remarks, created_by=request.session.get('school_admin_username', 'admin'))
                    payment.subscriptions.set(paid_subs)
                    messages.success(request, f'Payment of ₹{amount} received. Receipt: {payment.receipt_number}')
                    return redirect('gym_receipt', schema_name=schema_name, receipt_id=payment.id)
                except Exception as e:
                    messages.error(request, f'Error processing payment: {str(e)}')
            else:
                messages.error(request, 'Invalid payment data')
            return redirect('gym_payment', schema_name=schema_name)
        recent_payments = list(GymPayment.objects.select_related('customer').order_by('-payment_date')[:5])
        context = {'tenant': get_tenant(request, schema_name), 'customers': customers_with_pending, 'selected_customer': selected_customer, 'total_pending': total_pending, 'pending_subs': pending_subs, 'recent_payments': recent_payments, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_payment.html', context)

@require_tenant_type(['gym'])
def gym_receipt(request, schema_name, receipt_id):
    """Display gym payment receipt."""
    from django.shortcuts import render, get_object_or_404
    from ..models import GymPayment
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        payment = get_object_or_404(GymPayment, id=receipt_id)
        subscriptions = list(payment.subscriptions.all())
        context = {'tenant': get_tenant(request, schema_name), 'payment': payment, 'subscriptions': subscriptions, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None, 'payment_type_display': payment.payment_type}
        return render(request, 'tenant/gym_receipt.html', context)

def gym_reports(request, schema_name):
    """Gym reports and analytics page."""
    from django.shortcuts import render
    from django.db.models import Sum
    from ..models import GymCustomer, GymSubscription, GymPayment, GymAttendance
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        total_revenue_all = GymPayment.objects.aggregate(Sum('amount'))['amount__sum'] or 0
        total_checkins_all = GymAttendance.objects.count()
        active_customers = GymCustomer.objects.filter(status='active').count()
        active_subs = GymSubscription.objects.filter(status__in=['pending', 'partial']).count()
        from datetime import date, timedelta
        today = date.today()
        expiring_soon = GymCustomer.objects.filter(status='active', membership_end__gte=today, membership_end__lte=today + timedelta(days=7)).count()
        context = {'tenant': get_tenant(request, schema_name), 'total_revenue_all': total_revenue_all, 'total_checkins_all': total_checkins_all, 'active_customers': active_customers, 'active_subs': active_subs, 'expiring_soon': expiring_soon, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_reports.html', context)

@require_tenant_type(['gym'])
def gym_settings(request, schema_name):
    """Gym settings view."""
    from django.shortcuts import render, redirect
    from ..forms import GymSettingsForm
    from ..models import GymSettings
    from django.contrib import messages
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        settings_obj, created = GymSettings.objects.get_or_create(pk=1)
        if request.method == 'POST':
            form = GymSettingsForm(request.POST, instance=settings_obj)
            if form.is_valid():
                form.save()
                messages.success(request, 'Gym settings updated.')
                return redirect('gym_settings', schema_name=schema_name)
        else:
            form = GymSettingsForm(instance=settings_obj)
        context = {'tenant': get_tenant(request, schema_name), 'form': form, 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_settings.html', context)

@require_tenant_type(['gym'])
def gym_attendance(request, schema_name):
    """Attendance management page."""
    from django.shortcuts import render
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        context = {'tenant': get_tenant(request, schema_name), 'logo_url': get_tenant(request, schema_name).school_logo.url if get_tenant(request, schema_name).school_logo else None}
        return render(request, 'tenant/gym_attendance.html', context)

def gym_checkin_api(request):
    """API: Check in a gym customer (barcode or ID)."""
    from django.http import JsonResponse
    from django.utils import timezone
    from ..models import GymCustomer, GymAttendance
    import json
    if not request.session.get('school_admin_authenticated'):
        return JsonResponse({'error': 'Unauthorized'}, status=401)
    schema_name = request.session.get('school_admin_schema')
    if not schema_name:
        return JsonResponse({'error': 'No tenant schema'}, status=400)
    try:
        tenant = SchoolClient.objects.get(schema_name=schema_name)
    except SchoolClient.DoesNotExist:
        return JsonResponse({'error': 'Tenant not found'}, status=404)
    customer_id = request.POST.get('customer_id')
    if not customer_id:
        return JsonResponse({'error': 'customer_id required'}, status=400)
    with schema_context(schema_name):
        try:
            customer = GymCustomer.objects.get(id=customer_id, status='active')
        except GymCustomer.DoesNotExist:
            return JsonResponse({'error': 'Customer not found or inactive'}, status=404)
        today = timezone.localdate()
        existing = GymAttendance.objects.filter(customer=customer, date=today, check_out__isnull=True).first()
        if existing:
            return JsonResponse({'error': f"{customer.name} is already checked in today at {existing.check_in.strftime('%H:%M')}"}, status=400)
        now = timezone.now()
        attendance = GymAttendance.objects.create(customer=customer, date=today, check_in=now, notes=f"Checked in via API at {now.strftime('%H:%M')}")
        return JsonResponse({'message': f'{customer.name} checked in successfully', 'customer_name': customer.name, 'attendance_id': attendance.id, 'check_in_time': now.isoformat()})

@csrf_exempt
@require_http_methods(['POST'])
def gym_checkout_api(request):
    """API: Check out a gym customer."""
    from django.http import JsonResponse
    from django.utils import timezone
    from ..models import GymCustomer, GymAttendance
    if not request.session.get('school_admin_authenticated'):
        return JsonResponse({'error': 'Unauthorized'}, status=401)
    schema_name = request.session.get('school_admin_schema')
    if not schema_name:
        return JsonResponse({'error': 'No tenant schema'}, status=400)
    try:
        tenant = SchoolClient.objects.get(schema_name=schema_name)
    except SchoolClient.DoesNotExist:
        return JsonResponse({'error': 'Tenant not found'}, status=404)
    customer_id = request.POST.get('customer_id')
    if not customer_id:
        return JsonResponse({'error': 'customer_id required'}, status=400)
    with schema_context(schema_name):
        try:
            customer = GymCustomer.objects.get(id=customer_id)
        except GymCustomer.DoesNotExist:
            return JsonResponse({'error': 'Customer not found'}, status=404)
        today = timezone.localdate()
        attendance = GymAttendance.objects.filter(customer=customer, date=today, check_out__isnull=True).first()
        if not attendance:
            return JsonResponse({'error': f'{customer.name} is not checked in today'}, status=400)
        now = timezone.now()
        attendance.check_out = now
        duration = (now - attendance.check_in).total_seconds() / 60
        attendance.duration_minutes = int(duration)
        attendance.notes = (attendance.notes or '') + f" Checked out at {now.strftime('%H:%M')}"
        attendance.save()
        return JsonResponse({'message': f'{customer.name} checked out', 'customer_name': customer.name, 'duration_minutes': attendance.duration_minutes})

def gym_revenue_stats_api(request, schema_name):
    """API: Revenue statistics for gym."""
    from django.http import JsonResponse
    from django.db.models import Sum, Count
    from ..models import GymPayment
    from django_tenants.utils import schema_context
    from datetime import date, timedelta
    from collections import defaultdict
    from decimal import Decimal
    start_str = request.GET.get('start')
    end_str = request.GET.get('end')
    group_by = request.GET.get('group_by', 'month')
    with schema_context(schema_name):
        qs = GymPayment.objects.all()
        if start_str:
            qs = qs.filter(payment_date__gte=date.fromisoformat(start_str))
        if end_str:
            qs = qs.filter(payment_date__lte=date.fromisoformat(end_str))
        total_revenue = qs.aggregate(Sum('amount'))['amount__sum'] or Decimal('0')
        transaction_count = qs.count()
        mode_totals = defaultdict(Decimal)
        for p in qs:
            mode_totals[p.get_payment_mode_display()] += p.amount
        mode_distribution = [{'name': k, 'amount': float(v)} for k, v in mode_totals.items()]
        top_spenders = []
        customer_totals = defaultdict(Decimal)
        for p in qs.select_related('customer'):
            customer_totals[p.customer.name] += p.amount
        for name, total in sorted(customer_totals.items(), key=lambda x: x[1], reverse=True)[:5]:
            top_spenders.append({'name': name, 'total': float(total)})
        labels = []
        amounts = []
        if group_by == 'month':
            monthly = {}
            for p in qs:
                key = f'{p.payment_date.year}-{p.payment_date.month:02d}'
                monthly[key] = monthly.get(key, Decimal('0')) + p.amount
            for key in sorted(monthly.keys()):
                labels.append(key)
                amounts.append(float(monthly[key]))
        else:
            daily = {}
            for p in qs:
                key = p.payment_date.isoformat()
                daily[key] = daily.get(key, Decimal('0')) + p.amount
            for key in sorted(daily.keys()):
                labels.append(key)
                amounts.append(float(daily[key]))
        return JsonResponse({'total_revenue': float(total_revenue), 'transaction_count': transaction_count, 'mode_distribution': mode_distribution, 'top_spenders': top_spenders, 'labels': labels, 'amounts': amounts})

def gym_attendance_stats_api(request, schema_name):
    """API: Attendance statistics for gym."""
    from django.http import JsonResponse
    from django.db.models import Count
    from ..models import GymAttendance
    from django_tenants.utils import schema_context
    from datetime import date, timedelta
    from collections import defaultdict
    start_str = request.GET.get('start')
    end_str = request.GET.get('end')
    with schema_context(schema_name):
        qs = GymAttendance.objects.all()
        if start_str:
            qs = qs.filter(date__gte=date.fromisoformat(start_str))
        if end_str:
            qs = qs.filter(date__lte=date.fromisoformat(end_str))
        total_checkins = qs.count()
        unique_customers = qs.values('customer').distinct().count()
        avg_per_day = 0
        if start_str and end_str:
            days = (date.fromisoformat(end_str) - date.fromisoformat(start_str)).days + 1
            if days > 0:
                avg_per_day = round(total_checkins / days, 1)
        daily_counts = defaultdict(int)
        for a in qs:
            daily_counts[a.date.isoformat()] += 1
        labels = sorted(daily_counts.keys())
        counts = [daily_counts[d] for d in labels]
        hour_counts = defaultdict(int)
        for a in qs:
            hour = a.check_in.hour
            hour_counts[hour] += 1
        hour_labels = list(range(24))
        hour_counts_list = [hour_counts[h] for h in hour_labels]
        return JsonResponse({'total_checkins': total_checkins, 'unique_customers': unique_customers, 'avg_per_day': avg_per_day, 'labels': labels, 'counts': counts, 'hour_labels': hour_labels, 'hour_counts': hour_counts_list})

def gym_customers_list_api(request, schema_name):
    """API: List customers with optional search and status filter."""
    from django.http import JsonResponse
    from django.db.models import Sum
    from ..models import GymCustomer, GymSubscription, GymPayment, GymAttendance
    from django_tenants.utils import schema_context
    search = request.GET.get('search', '')
    status = request.GET.get('status', '')
    with schema_context(schema_name):
        qs = GymCustomer.objects.all()
        if search:
            qs = qs.filter(name__icontains=search) | qs.filter(phone__icontains=search)
        if status:
            qs = qs.filter(status=status)
        customers = []
        for c in qs:
            total_paid = c.payments.aggregate(Sum('amount'))['amount__sum'] or 0
            total_billed = c.subscriptions.aggregate(Sum('amount'))['amount__sum'] or 0
            pending = total_billed - total_paid
            attendance_count = c.attendances.count()
            customers.append({'id': c.id, 'name': c.name, 'phone': c.phone, 'status': c.status, 'membership_end': c.membership_end.isoformat() if c.membership_end else None, 'total_paid': float(total_paid), 'pending': float(pending), 'attendance_count': attendance_count})
        return JsonResponse(customers, safe=False)

def gym_customer_detail_api(request, schema_name, customer_id):
    """API: Detailed customer data for modal."""
    from django.http import JsonResponse
    from django.db.models import Sum
    from ..models import GymCustomer, GymSubscription, GymPayment, GymAttendance
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        try:
            c = GymCustomer.objects.get(id=customer_id)
        except GymCustomer.DoesNotExist:
            return JsonResponse({'error': 'Customer not found'}, status=404)
        total_paid = c.payments.aggregate(Sum('amount'))['amount__sum'] or 0
        total_billed = c.subscriptions.aggregate(Sum('amount'))['amount__sum'] or 0
        pending = total_billed - total_paid
        payments = [{'receipt': p.receipt_number, 'amount': float(p.amount), 'date': p.payment_date.isoformat(), 'mode': p.get_payment_mode_display()} for p in c.payments.order_by('-payment_date')]
        subscriptions = [{'month': f'{s.month}/{s.year}', 'amount': float(s.amount), 'paid': float(s.paid_amount), 'status': s.get_status_display(), 'cancelled': s.is_cancelled} for s in c.subscriptions.order_by('-year', '-month')]
        attendances = [{'date': a.date.isoformat(), 'check_in': a.check_in.isoformat(), 'check_out': a.check_out.isoformat() if a.check_out else None} for a in c.attendances.order_by('-date')]
        return JsonResponse({'id': c.id, 'name': c.name, 'phone': c.phone, 'email': c.email, 'status': c.status, 'membership_start': c.membership_start.isoformat(), 'membership_end': c.membership_end.isoformat() if c.membership_end else None, 'monthly_fee': float(c.monthly_fee), 'total_paid': float(total_paid), 'pending': float(pending), 'payments': payments, 'subscriptions': subscriptions, 'attendances': attendances})

def gym_subscription_status_api(request, schema_name):
    """API: Subscription status counts and expiring lists."""
    from django.http import JsonResponse
    from ..models import GymCustomer, GymSubscription
    from django_tenants.utils import schema_context
    from datetime import date, timedelta
    with schema_context(schema_name):
        today = date.today()
        current_month = today.month
        current_year = today.year
        active_subs = GymSubscription.objects.filter(month=current_month, year=current_year, status__in=['pending', 'partial'])
        active_count = active_subs.count()
        active_subscriptions = [{'customer': s.customer.name, 'amount': float(s.amount)} for s in active_subs]
        expiring_customers = GymCustomer.objects.filter(status='active', membership_end__gte=today, membership_end__lte=today + timedelta(days=7))
        expiring_count = expiring_customers.count()
        expiring_soon = [{'name': c.name, 'phone': c.phone, 'end_date': c.membership_end.isoformat()} for c in expiring_customers]
        expired_customers = GymCustomer.objects.filter(status='expired') | GymCustomer.objects.filter(membership_end__lt=today, status='active')
        expired_count = expired_customers.count()
        expired_list = [{'name': c.name, 'phone': c.phone, 'end_date': c.membership_end.isoformat() if c.membership_end else 'Unknown'} for c in expired_customers]
        return JsonResponse({'active_count': active_count, 'active_subscriptions': active_subscriptions, 'expiring_count': expiring_count, 'expiring_soon': expiring_soon, 'expired_count': expired_count, 'expired_customers': expired_list})

def gym_attendance_data_api(request, schema_name):
    """API: Get active check-ins and today's history for attendance page."""
    from django.http import JsonResponse
    from ..models import GymAttendance, GymCustomer
    from django.utils import timezone
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        today = timezone.localdate()
        active = GymAttendance.objects.filter(date=today, check_out__isnull=True).select_related('customer')
        active_data = []
        for a in active:
            active_data.append({'id': a.id, 'customer_id': a.customer.id, 'customer_name': a.customer.name, 'customer_phone': a.customer.phone, 'check_in_time': a.check_in.strftime('%H:%M:%S'), 'check_in_raw': a.check_in.isoformat()})
        history = GymAttendance.objects.filter(date=today, check_out__isnull=False).select_related('customer')
        history_data = []
        for a in history:
            duration = None
            if a.duration_minutes:
                duration = f'{a.duration_minutes // 60}h {a.duration_minutes % 60}m'
            history_data.append({'id': a.id, 'customer_name': a.customer.name, 'customer_phone': a.customer.phone, 'check_in_time': a.check_in.strftime('%H:%M:%S'), 'check_out_time': a.check_out.strftime('%H:%M:%S') if a.check_out else None, 'duration': duration, 'notes': a.notes})
        today_stats = {'total': GymAttendance.objects.filter(date=today).count(), 'active': active.count(), 'unique': GymAttendance.objects.filter(date=today).values('customer').distinct().count()}
        return JsonResponse({'active': active_data, 'history': history_data, 'today_stats': today_stats})

def gym_eligible_customers_api(request, schema_name):
    """API: Return customers eligible for check-in (active, not already checked in today)."""
    from django.http import JsonResponse
    from ..models import GymCustomer, GymAttendance
    from django.utils import timezone
    from django_tenants.utils import schema_context
    with schema_context(schema_name):
        today = timezone.localdate()
        checked_in_ids = set(GymAttendance.objects.filter(date=today).values_list('customer_id', flat=True))
        eligible = GymCustomer.objects.filter(status='active').exclude(id__in=checked_in_ids)
        data = [{'id': c.id, 'name': c.name, 'phone': c.phone} for c in eligible]
        return JsonResponse(data, safe=False)

def gym_search_customer_api(request, schema_name):
    """API: Search customers by query (phone, name, barcode)."""
    from django.http import JsonResponse
    from django.db.models import Q
    from ..models import GymCustomer
    from django_tenants.utils import schema_context
    q = request.GET.get('q', '')
    with schema_context(schema_name):
        customers = GymCustomer.objects.filter(Q(name__icontains=q) | Q(phone__icontains=q) | Q(barcode__icontains=q))[:10]
        data = [{'id': c.id, 'name': c.name, 'phone': c.phone} for c in customers]
        return JsonResponse(data, safe=False)

def gym_export_attendance_api(request, schema_name):
    """API: Export attendance for a given date as CSV."""
    from django.http import HttpResponse
    from ..models import GymAttendance
    from django.utils import timezone
    from django_tenants.utils import schema_context
    import csv
    date_str = request.GET.get('date', 'today')
    if date_str == 'today':
        target_date = timezone.localdate()
    else:
        target_date = date.fromisoformat(date_str)
    with schema_context(schema_name):
        attendances = GymAttendance.objects.filter(date=target_date).select_related('customer')
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="attendance_{target_date}.csv"'
        writer = csv.writer(response)
        writer.writerow(['Customer Name', 'Phone', 'Check In', 'Check Out', 'Duration (min)', 'Notes'])
        for a in attendances:
            duration = a.duration_minutes if a.duration_minutes else ''
            writer.writerow([a.customer.name, a.customer.phone, a.check_in.strftime('%Y-%m-%d %H:%M:%S'), a.check_out.strftime('%Y-%m-%d %H:%M:%S') if a.check_out else '', duration, a.notes or ''])
        return response
