from django.core.management.base import BaseCommand
from django_tenants.utils import schema_context
from axis_saas.models import SchoolClient, SchoolClass, Subject

class Command(BaseCommand):
    help = 'Normalize existing class and subject names (title case, uppercase section)'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.exclude(schema_name='public')
        for tenant in tenants:
            self.stdout.write(f"Normalizing tenant: {tenant.schema_name}")
            with schema_context(tenant.schema_name):
                # Normalize classes
                classes = SchoolClass.objects.all()
                updated = 0
                for cls in classes:
                    original_name = cls.name
                    original_section = cls.section
                    cls.normalize_fields()
                    if cls.name != original_name or cls.section != original_section:
                        cls.save(update_fields=['name', 'section'])
                        updated += 1
                        self.stdout.write(f"  Updated class: {original_name} -> {cls.name}, section: {original_section} -> {cls.section}")
                self.stdout.write(f"  Updated {updated} classes.")

                # Normalize subjects
                subjects = Subject.objects.all()
                updated_subj = 0
                for subj in subjects:
                    original = subj.name
                    subj.normalize_fields()
                    if subj.name != original:
                        subj.save(update_fields=['name'])
                        updated_subj += 1
                        self.stdout.write(f"  Updated subject: {original} -> {subj.name}")
                self.stdout.write(f"  Updated {updated_subj} subjects.")
        self.stdout.write(self.style.SUCCESS("Normalization complete."))
