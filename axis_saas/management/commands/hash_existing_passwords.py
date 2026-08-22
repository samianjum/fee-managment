from django.core.management.base import BaseCommand
from django.contrib.auth.hashers import make_password
from axis_saas.models import SchoolClient

class Command(BaseCommand):
    help = 'Hash all plaintext admin passwords for SchoolClient'

    def handle(self, *args, **options):
        tenants = SchoolClient.objects.all()
        updated = 0
        for t in tenants:
            if not t.admin_password.startswith(('pbkdf2_sha256', 'bcrypt', 'argon2')):
                t.admin_password = make_password(t.admin_password)
                t.save(update_fields=['admin_password'])
                updated += 1
                self.stdout.write(f"✅ Hashed password for {t.name}")
        self.stdout.write(self.style.SUCCESS(f"Done! Updated {updated} tenants."))
