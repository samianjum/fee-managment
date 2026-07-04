import shutil
from pathlib import Path

def patch_views():
    views_path = Path('axis_saas/views.py')
    if not views_path.exists():
        print("❌ axis_saas/views.py not found")
        return

    # Backup original file
    backup_path = views_path.with_suffix('.py.bak')
    shutil.copy2(views_path, backup_path)
    print(f"✅ Backup created: {backup_path}")

    with open(views_path, 'r') as f:
        content = f.read()

    # 1. Replace record.remaining with record.remaining_total in fee_collection & family_payment
    content = content.replace('due = record.remaining', 'due = record.remaining_total')

    # 2. Replace sub.remaining with sub.remaining_total in gym_payment
    content = content.replace('due = sub.remaining', 'due = sub.remaining_total')

    # 3. When a fee is fully paid, set paid_amount to total_amount (not just amount)
    content = content.replace('record.paid_amount = record.amount', 'record.paid_amount = record.total_amount')
    content = content.replace('sub.paid_amount = sub.amount', 'sub.paid_amount = sub.total_amount')

    with open(views_path, 'w') as f:
        f.write(content)

    print("✅ Patched axis_saas/views.py successfully. Please restart the server.")

if __name__ == '__main__':
    patch_views()
