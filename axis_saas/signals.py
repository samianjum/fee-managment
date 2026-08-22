from django.dispatch import receiver
from django_tenants.signals import post_schema_sync
from django_tenants.utils import schema_context
from django.contrib.auth import get_user_model
from axis_saas.models import SchoolClient
from django.db.models.signals import post_save

@receiver(post_schema_sync)
def provision_secure_tenant_admin(sender, tenant, **kwargs):
    if tenant.schema_name == 'public':
        return

    User = get_user_model()
    
    u_name = tenant.admin_username
    u_pass = tenant.admin_password
    u_email = f"{u_name}@{tenant.schema_name}.com"
    
    if not u_name or not u_pass:
        return

    raw_pw = getattr(tenant, '_raw_password', None)
    if not raw_pw:
        print(f"⚠️ Raw password not available for {tenant.schema_name}, cannot provision superuser.")
        return

    with schema_context(tenant.schema_name):
        if not User.objects.filter(username=u_name).exists():
            User.objects.create_superuser(
                username=u_name,
                email=u_email,
                password=raw_pw
            )
            print(f"🚀 [DYNAMIC SYNC] Operational superuser '{u_name}' provisioned into tenant schema '{tenant.schema_name}' successfully.")
@receiver(post_save, sender=SchoolClient)
def sync_tenant_admin_password(sender, instance, created, **kwargs):
    if instance.schema_name == 'public' or created:
        return
        
    u_name = instance.admin_username
    raw_pw = getattr(instance, '_raw_password', None)
    if u_name and raw_pw:
        with schema_context(instance.schema_name):
            User = get_user_model()
            user = User.objects.filter(username=u_name).first()
            if user:
                user.set_password(raw_pw)
                user.save()
                print(f"🔄 [AXIS AUTH] Password safely synchronized for '{u_name}' in schema '{instance.schema_name}'.")
    elif u_name and not raw_pw:
        print(f"⚠️ Raw password not available for {instance.schema_name}, cannot sync password.")