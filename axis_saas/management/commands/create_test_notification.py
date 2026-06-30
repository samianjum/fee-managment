#!/usr/bin/env python3
from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, Notification
from datetime import date

class Command(BaseCommand):
    help = 'Create a test notification for a tenant'

    def add_arguments(self, parser):
        parser.add_argument('--schema', type=str, required=True, help='Tenant schema name')

    def handle(self, *args, **options):
        schema = options['schema']
        try:
            tenant = SchoolClient.objects.get(schema_name=schema)
        except SchoolClient.DoesNotExist:
            self.stderr.write(self.style.ERROR(f"Tenant '{schema}' not found"))
            return

        with schema_context(schema):
            today = date.today()
            notif = Notification.objects.create(
                message=f"Test notification for {today}",
                link=f"/portal/{schema}/vouchers/?month={today.month}&year={today.year}",
                is_read=False
            )
            self.stdout.write(self.style.SUCCESS(f"Created test notification ID: {notif.id}"))
