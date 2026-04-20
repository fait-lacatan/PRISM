import os
import re

dir_path = "/Users/Apollo/Inter/prism/lib/"

def replace_color(match):
    col_str = match.group(0)
    
    # Handle pure Colors.white
    if col_str == 'Colors.white':
        return 'Theme.of(context).colorScheme.onSurface'
        
    # Handle Colors.white.withValues(...)
    if '.withValues' in col_str:
        return col_str.replace('Colors.white', 'Theme.of(context).colorScheme.onSurface')
        
    # Handle Colors.whiteXX
    m = re.search(r'Colors\.white(\d+)', col_str)
    if m:
        alpha_val = int(m.group(1)) / 100.0
        return f'Theme.of(context).colorScheme.onSurface.withValues(alpha: {alpha_val})'
        
    return col_str

# Only target lib/shared/templates/ for now
templates_dir = os.path.join(dir_path, "shared/templates")

for root, _, files in os.walk(templates_dir):
    for f in files:
        if not f.endswith('.dart'): continue
        path = os.path.join(root, f)
        
        with open(path, 'r') as file:
            content = file.read()
            
        # Pattern to match Colors.white, Colors.white70, Colors.white.withValues(...)
        pattern = r'Colors\.white(?:\d+|\.withValues\([^)]+\))?'
        
        # We only want to replace it where it follows "color: " or inside a text style but let's just 
        # replace all occurrences where it's not in a custom painter if possible. 
        # Since separating them by regex is hard, let's just replace all and then fix compile errors.
        new_content = re.sub(pattern, replace_color, content)
        
        if new_content != content:
            with open(path, 'w') as file:
                file.write(new_content)
print("Replacement script completed.")
