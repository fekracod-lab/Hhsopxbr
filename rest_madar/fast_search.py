import os

search_terms = ["التقارير التحليلية", "مفتوح للطلبات", "المحل مغلق", "لوحة التاجر", "اسم المطعم", "مطبخ عربي"]
workspace = r"c:\Users\omar muthana hamid\Desktop\dalal_Alqaim"

results = []

ignore_dirs = {
    "build", ".dart_tool", ".git", ".idea", "ios", "android", "windows", "macos", "linux", "web", "node_modules"
}

for root, dirs, files in os.walk(workspace):
    # Modifying dirs in-place will prevent os.walk from descending into ignored directories
    dirs[:] = [d for d in dirs if d not in ignore_dirs]
    
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    content = f.read()
                    matched = [term for term in search_terms if term in content]
                    if matched:
                        results.append((path, matched))
            except Exception:
                pass

output_path = r"C:\Users\omar muthana hamid\.gemini\antigravity\brain\76226760-a9f3-432f-8dcb-699b3d2feb4d\scratch\search_fast_results.txt"
with open(output_path, "w", encoding="utf-8") as f:
    f.write(f"Found {len(results)} matches:\n")
    for path, terms in results:
        f.write(f"- {path} matches {terms}\n")
