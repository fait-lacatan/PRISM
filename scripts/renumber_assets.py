import json
import os

content_dir = "assets/content"
flow_path = os.path.join(content_dir, "narrative_flow.json")

def process():
    if not os.path.exists(flow_path):
        print(f"Error: Could not find {flow_path}")
        return

    with open(flow_path, "r") as f:
        data = json.load(f)

    for index, chapter_data in enumerate(data.get("chapters", [])):
        new_num = index + 1
        new_id = f"chap_{new_num:02d}"
        
        old_file = chapter_data["file"]
        
        parts = old_file.split("_", 1)
        if len(parts) == 2 and parts[0].isdigit():
            base_name = parts[1]
        else:
            base_name = old_file
            
        new_file = f"{new_num:02d}_{base_name}"
        
        old_path = os.path.join(content_dir, old_file)
        new_path = os.path.join(content_dir, new_file)
        
        print(f"[{old_path}] -> [{new_path}]")
        
        if os.path.exists(old_path) and old_path != new_path:
            os.rename(old_path, new_path)
            
        chapter_data["id"] = new_id
        chapter_data["file"] = new_file

    with open(flow_path, "w") as f:
        json.dump(data, f, indent=2)

    print("Renumbering complete.")

if __name__ == "__main__":
    process()
