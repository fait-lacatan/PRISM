import os
import re

dir_path = "/Users/Apollo/Inter/prism/lib/"
templates_dir = os.path.join(dir_path, "shared/templates")

def replace_back(match):
    full_str = match.group(0)
    
    # Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7) -> Colors.white70
    m = re.search(r'Theme\.of\(context\)\.colorScheme\.onSurface\.withValues\(alpha:\s*([\d.]+)\)', full_str)
    if m:
        alpha_val = float(m.group(1))
        # Known constants mapping back to Colors.whiteXX
        if alpha_val == 0.7: return 'Colors.white70'
        if alpha_val == 0.6: return 'Colors.white60'
        if alpha_val == 0.54: return 'Colors.white54'
        if alpha_val == 0.38: return 'Colors.white38'
        if alpha_val == 0.24: return 'Colors.white24'
        if alpha_val == 0.12: return 'Colors.white12'
        if alpha_val == 0.1: return 'Colors.white10'
        
        return f'Colors.white.withValues(alpha: {m.group(1)})'
        
    if full_str == 'Theme.of(context).colorScheme.onSurface':
        return 'Colors.white'
        
    return full_str

for root, _, files in os.walk(templates_dir):
    for f in files:
        if not f.endswith('.dart'): continue
        path = os.path.join(root, f)
        
        with open(path, 'r') as file:
            content = file.read()
            
        # Pattern to match the exact string injected previously
        pattern1 = r'Theme\.of\(context\)\.colorScheme\.onSurface(?:\.withValues\(alpha:\s*[\d.]+\))?'
        new_content = re.sub(pattern1, replace_back, content)
        
        if new_content != content:
            with open(path, 'w') as file:
                file.write(new_content)

print("Revert script completed.")
