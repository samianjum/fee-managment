from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, SchoolClass, Subject, ClassSubject

class Command(BaseCommand):
    help = 'List all classes, subjects, and assignments for a given tenant'

    def add_arguments(self, parser):
        parser.add_argument('schema_name', type=str, help='Tenant schema name')

    def handle(self, *args, **options):
        schema_name = options['schema_name']
        try:
            tenant = SchoolClient.objects.get(schema_name=schema_name)
        except SchoolClient.DoesNotExist:
            self.stderr.write(self.style.ERROR(f"Tenant '{schema_name}' not found"))
            return

        with schema_context(schema_name):
            classes = SchoolClass.objects.all()
            subjects = Subject.objects.all()
            assignments = ClassSubject.objects.all()

            self.stdout.write(self.style.SUCCESS(f"=== Classes for {schema_name} ==="))
            for cls in classes:
                self.stdout.write(f"  {cls.id}: {cls.name} - {cls.section} (active: {cls.is_active})")
            self.stdout.write(f"Total: {classes.count()}")

            self.stdout.write(self.style.SUCCESS(f"\n=== Subjects for {schema_name} ==="))
            for subj in subjects:
                self.stdout.write(f"  {subj.id}: {subj.name} (active: {subj.is_active})")
            self.stdout.write(f"Total: {subjects.count()}")

            self.stdout.write(self.style.SUCCESS(f"\n=== Assignments for {schema_name} ==="))
            for ass in assignments:
                self.stdout.write(f"  {ass.id}: {ass.school_class} - {ass.subject} (active: {ass.is_active})")
            self.stdout.write(f"Total: {assignments.count()}")
