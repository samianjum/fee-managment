#!/usr/bin/env python3
"""
Merge the two save() methods in SchoolClient so that password hashing
is preserved and domain creation still runs.
Run: python3 fix_save.py
"""

import re
from pathlib import Path

MODELS_PATH = Path("axis_saas/models.py")

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def merge_saves(content):
    # We'll locate the SchoolClient class and combine the two save methods.
    # Find the start of the class
    class_start = re.search(r'class SchoolClient\(TenantMixin\):', content)
    if not class_start:
        print("❌ Could not find class SchoolClient")
        return content

    # Find the end of the class by indentation (look for next class or end of file)
    class_body_start = class_start.end()
    # Find the indentation level of the class
    indent = len(class_start.group(0)) - len(class_start.group(0).lstrip())
    # We'll find the end of the class by scanning for a line with same or less indentation that is not a method.
    lines = content.splitlines()
    # Find the index of class_start line
    class_line_idx = None
    for i, line in enumerate(lines):
        if line.strip().startswith('class SchoolClient(TenantMixin):'):
            class_line_idx = i
            break
    if class_line_idx is None:
        return content

    # Now we need to get the entire class body from lines[class_line_idx+1:]
    class_body_lines = []
    for j in range(class_line_idx+1, len(lines)):
        line = lines[j]
        if line.strip() == '':
            class_body_lines.append(line)
            continue
        # If line starts with a word that is not indented more than class indent, it's outside class
        current_indent = len(line) - len(line.lstrip())
        if current_indent <= indent and line.strip():
            # End of class
            break
        class_body_lines.append(line)

    class_body = '\n'.join(class_body_lines)

    # Find the first save method (the hashing one)
    save1_pattern = r'def save\(self, \*args, \*\*kwargs\):.*?(?=\n\s+def |\n\s+class |\Z)'
    save1_match = re.search(save1_pattern, class_body, re.DOTALL)
    if not save1_match:
        print("❌ Could not find first save method")
        return content

    save1 = save1_match.group(0)

    # Find the second save method (the domain creation one)
    # After the first save, there may be other methods. We'll find the second save.
    # We'll search from after the first save's end.
    rest_of_body = class_body[save1_match.end():]
    save2_pattern = r'def save\(self, \*args, \*\*kwargs\):.*?(?=\n\s+def |\n\s+class |\Z)'
    save2_match = re.search(save2_pattern, rest_of_body, re.DOTALL)
    if not save2_match:
        print("❌ Could not find second save method")
        return content

    save2 = save2_match.group(0)

    # Combine them: keep the hashing logic, then add the domain logic at the end of the first save.
    # We'll extract the body of save2 (the part after the def line) and put it after the super().save() call in save1.
    # But easier: we can replace the entire class body with a version that has only one save method.
    # We'll reconstruct: we'll take class_body, remove save2, and replace save1 with a merged version.

    # Build merged save:
    # - Start with save1's definition line and the body up to the last line before the 'super().save()'?
    # Actually save1's body: it does hashing and then super().save()
    # save2's body: it does some logic and then super().save()
    # We want to do hashing, then domain logic, then super().save() once.
    # So we'll extract the logic of save2 (excluding the def line and the super().save() line? But it also has super().save() at the end.
    # We'll remove the super().save() from save2 and insert its logic before the super().save() of save1.

    # Extract save2 body without the def line.
    save2_lines = save2.splitlines()
    # Find the first line that is not blank and not the def line
    body_start_idx = 1
    while body_start_idx < len(save2_lines) and (save2_lines[body_start_idx].strip() == '' or save2_lines[body_start_idx].strip().startswith('def ')):
        body_start_idx += 1
    # Extract body lines (keeping indentation)
    save2_body = '\n'.join(save2_lines[body_start_idx:])

    # Extract save1 body without its def line and without its super().save() call.
    save1_lines = save1.splitlines()
    # Find the super().save() call line (the last line usually)
    # We'll find the line containing 'super().save('
    super_line_idx = -1
    for idx, line in enumerate(save1_lines):
        if 'super().save(' in line:
            super_line_idx = idx
            break
    if super_line_idx == -1:
        print("❌ Could not find super().save() in save1")
        return content

    # Build new save method: def line, then body of save1 up to (but not including) the super().save() line,
    # then insert the save2 body (without its own super().save() call if any), then the super().save() line.
    # But save2 also has a super().save() call; we should remove that to avoid double save.
    # We'll strip any super().save() from save2_body.
    save2_body_lines = save2_body.splitlines()
    filtered_save2_body = []
    for line in save2_body_lines:
        if 'super().save(' in line:
            continue
        filtered_save2_body.append(line)
    save2_body = '\n'.join(filtered_save2_body)

    # Build new save method:
    def_line = save1_lines[0]  # "def save(self, *args, **kwargs):"
    # Lines before super().save() in save1 (including hashing logic)
    before_super = save1_lines[1:super_line_idx]  # skip the def line
    # Combine
    new_save_lines = [def_line] + before_super
    # Add save2 body (with correct indentation? It already has indentation from class body, but we need to ensure it's at the same level)
    # We'll keep the indentation as is; they are already indented correctly.
    if save2_body:
        new_save_lines.extend(save2_body.splitlines())
    # Add the super().save() line
    new_save_lines.append(save1_lines[super_line_idx])  # the super().save()

    new_save = '\n'.join(new_save_lines)

    # Now replace save1 with new_save and remove save2 from class_body
    # We'll replace the whole class_body by removing save2 and replacing save1.
    # We'll do string replacement: find save1 and save2 in class_body.
    # Since they are unique, we can replace.
    new_class_body = class_body.replace(save1, new_save)
    # Remove save2 completely (replace with empty string)
    new_class_body = new_class_body.replace(save2, '')
    # Clean up any extra blank lines
    # Reconstruct full file content: everything before class, then new_class_body, then everything after class.
    # Find the end of class in the original file? We'll replace the class body in the original content.

    # We'll locate the class in the original content and replace the body.
    # We'll find the position of the class definition and the end position.
    class_start_pos = content.find('class SchoolClient(TenantMixin):')
    # Find the end of the class by scanning for a line with less indentation than the class.
    # We'll use the same logic as before but now we know the start and end indices in original content.
    # Easier: we'll replace the entire class from class_start to the end of the class (determined by indentation).
    # We'll reconstruct the whole class with the new body.

    # We'll get the class definition line and then the new class body (without the class line).
    # We'll create a new class definition:
    new_class = 'class SchoolClient(TenantMixin):\n' + new_class_body

    # Find where the class ends in the original file.
    # We'll scan after the class_start to find a line that is not indented more than the class.
    # But we already have the class_body_lines from earlier; we can just use the original lines up to the end of class.
    # Let's reconstruct the file by replacing the lines from class_line_idx to end_class_idx.
    # We have class_line_idx, and we found end of class by scanning.
    # In the earlier scan, we broke when we encountered a line with current_indent <= indent and line.strip().
    # That line is the start of the next class or something else.
    # We'll use that logic to find the end index.
    end_class_idx = class_line_idx + 1
    for j in range(class_line_idx+1, len(lines)):
        line = lines[j]
        if line.strip() == '':
            continue
        current_indent = len(line) - len(line.lstrip())
        if current_indent <= indent:
            end_class_idx = j
            break
    else:
        end_class_idx = len(lines)  # end of file

    # Now replace the lines from class_line_idx to end_class_idx-1 with new_class lines.
    new_lines = lines[:class_line_idx]
    new_lines.append(new_class)
    new_lines.extend(lines[end_class_idx:])

    new_content = '\n'.join(new_lines)
    return new_content

def main():
    if not MODELS_PATH.exists():
        print(f"❌ {MODELS_PATH} not found. Are you in the project root?")
        return

    original = read_file(MODELS_PATH)
    new_content = merge_saves(original)

    if new_content == original:
        print("✅ No changes needed (or already fixed).")
    else:
        write_file(MODELS_PATH, new_content)
        print("✅ Successfully merged the two save() methods in models.py")
        print("🔄 Now run: python3 manage.py hash_existing_passwords")
        print("   This will hash the plaintext password for the new tenant.")
        print("   Then try logging in again.")

if __name__ == '__main__':
    main()
