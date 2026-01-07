import os
from pathlib import Path
try:
    from PIL import Image
except ImportError:
    print("Pillow is not installed. Please run: pip install Pillow")
    exit(1)

# List of files to convert relative to project root
files_to_convert = [
    'assets/images/map.png',
    'assets/images/doctor_header_pattern.png',
    'assets/images/two_factor.png',
    'assets/images/notes_banner.png',
    'assets/images/encrypted.png',
    'assets/images/account_banner.png',
    'assets/images/male-doc.png',
    'assets/images/female-doc.png',
    'assets/images/Chat-BG.png',
    'assets/images/messages_banner.png',
    'assets/images/document_banner.png',
    'assets/images/worker.png',
    'assets/images/health/allergy_3d.png',
    'assets/images/health/surgery_3d.png',
    'assets/images/health/vaccination_3d.png',
    'assets/images/health/family_history_3d.png',
    'assets/images/health/medication_3d.png',
    'assets/images/health/chronic_diseases_3d.png',
]

project_root = Path.cwd()

from rembg import remove
import io

def convert_to_webp():
    print("Starting WebP conversion with VS Quality background removal (rembg)...")
    count = 0
    for file_path in files_to_convert:
        full_path = project_root / file_path
        
        if not full_path.exists():
            print(f"⚠️ File not found: {file_path}")
            continue
            
        try:
            # Open image
            with open(full_path, 'rb') as i:
                input_data = i.read()
                
            # Remove background using rembg
            output_data = remove(input_data)
            
            # Convert to PIL Image
            img_transparent = Image.open(io.BytesIO(output_data))
                
            # Create new path with .webp extension
            new_path = full_path.with_suffix('.webp')
            
            # Save as WebP
            img_transparent.save(new_path, 'WEBP', quality=90)
            print(f"✅ Cleaned & Converted: {file_path} -> {new_path.name}")
            count += 1
                
        except Exception as e:
            print(f"❌ Error converting {file_path}: {e}")

    print(f"\nCompleted! Converted {count} images.")

if __name__ == "__main__":
    convert_to_webp()
