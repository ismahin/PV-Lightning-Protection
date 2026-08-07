"""Verify the browser-rendered PDF using its actual parsed content."""
import json
import sys
from pathlib import Path
from pypdf import PdfReader

pdf_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
reader = PdfReader(str(pdf_path))
text = "\n".join((page.extract_text() or "") for page in reader.pages)
titles = ["PV Lightning and Surge Protection", "PV validation", "Fair paired comparisons", "Solver convergence", "Limitations"]
image_count = sum(len(page.images) for page in reader.pages)
result = {
    "page_count": len(reader.pages),
    "image_count": image_count,
    "required_titles": titles,
    "required_titles_found": [title.lower() in text.lower() for title in titles],
    "extracted_text_characters": len(text),
    "pdf_header_valid": pdf_path.read_bytes()[:5] == b"%PDF-",
    "file_size_bytes": pdf_path.stat().st_size,
}
if not result["pdf_header_valid"] or result["page_count"] <= 1 or result["extracted_text_characters"] < 500:
    raise SystemExit("PDF structural/content verification failed")
output_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result))
