#!/usr/bin/env python3
from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, Notification

class Command(BaseCommand):
    help = 'List notifications for a specific tenant'

    def add_arguments(self, parser):
        parser.add_argument('--schema', type=str, required=True, help='Tenant schema name')
        parser.add_argument('--all', action='store_true', help='List all notifications (including read)')

    def handle(self, *args, **options):
        schema = options['schema']
        try:
            tenant = SchoolClient.objects.get(schema_name=schema)
        except SchoolClient.DoesNotExist:
            self.stderr.write(self.style.ERROR(f"Tenant '{schema}' not found"))
            return

        with schema_context(schema):
            qs = Notification.objects.all()
            if not options['all']:
                qs = qs.filter(is_read=False)
            count = qs.count()
            self.stdout.write(self.style.SUCCESS(f"Notifications for {schema} (unread: {count})"))
            for n in qs:
                self.stdout.write(f"  {n.id}: {n.message} | Link: {n.link} | Read: {n.is_read} | Created: {n.created_at}")
