"""
Gera assets da Play Store a partir da logo PedeJá
- icon_512.png: 512x512 (ícone do app)
- feature_1024x500.png: 1024x500 (gráfico de destaque)
"""
from PIL import Image
import os

# Criar diretório se não existir
os.makedirs('assets/store', exist_ok=True)

# Dados da logo (base64 ou bytes direto do anexo)
# Como o anexo foi enviado, vou recriar a logo programaticamente
# baseado nas cores e formato da imagem PedeJá (xícara marrom/verde)

def create_transparent_canvas(width, height):
    """Cria um canvas transparente"""
    return Image.new('RGBA', (width, height), (0, 0, 0, 0))

def add_logo_to_canvas(canvas, logo, max_size_percent=0.9):
    """Adiciona logo centralizada no canvas com margem"""
    canvas_w, canvas_h = canvas.size
    logo_w, logo_h = logo.size
    
    # Calcular tamanho máximo mantendo proporção
    max_w = int(canvas_w * max_size_percent)
    max_h = int(canvas_h * max_size_percent)
    
    # Redimensionar mantendo aspect ratio
    logo_copy = logo.copy()
    logo_copy.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
    
    # Centralizar
    x = (canvas_w - logo_copy.width) // 2
    y = (canvas_h - logo_copy.height) // 2
    
    # Colar logo (usar a própria imagem como máscara se tiver alpha)
    canvas.paste(logo_copy, (x, y), logo_copy)
    return canvas

# Tentar carregar logo de vários locais possíveis
logo = None
possible_paths = [
    'C:/Users/nalbe/AppData/Local/Temp/tmp-14-image_1732896304952.png',
    'assets/logo.png',
]

# Adicionar arquivos temp recentes
import glob
temp_images = glob.glob('C:/Users/nalbe/AppData/Local/Temp/**/tmp-*-image_*.png', recursive=True)
temp_images.extend(glob.glob('C:/Users/nalbe/AppData/Local/Temp/tmp-*-image_*.png'))
possible_paths = temp_images + possible_paths

for path in possible_paths:
    try:
        if os.path.exists(path):
            logo = Image.open(path).convert('RGBA')
            print(f'✓ Logo carregada: {path}')
            print(f'  Dimensões originais: {logo.size}')
            break
    except Exception as e:
        continue

if logo is None:
    print('❌ Não foi possível encontrar a logo nos caminhos esperados.')
    print('   Caminhos tentados:')
    for p in possible_paths[:5]:
        print(f'   - {p}')
    exit(1)

# Gerar ícone 512x512
print('\n📦 Gerando icon_512.png...')
icon_canvas = create_transparent_canvas(512, 512)
icon_final = add_logo_to_canvas(icon_canvas, logo, max_size_percent=0.85)
icon_final.save('assets/store/icon_512.png', 'PNG', optimize=True)
size_kb = os.path.getsize('assets/store/icon_512.png') / 1024
print(f'✓ icon_512.png criado ({size_kb:.2f} KB)')

# Gerar feature graphic 1024x500
print('\n📦 Gerando feature_1024x500.png...')
feature_canvas = create_transparent_canvas(1024, 500)
feature_final = add_logo_to_canvas(feature_canvas, logo, max_size_percent=0.80)
feature_final.save('assets/store/feature_1024x500.png', 'PNG', optimize=True)
size_kb = os.path.getsize('assets/store/feature_1024x500.png') / 1024
print(f'✓ feature_1024x500.png criado ({size_kb:.2f} KB)')

print('\n✅ Assets da Play Store gerados com sucesso!')
print('   Localização: assets/store/')
print('   - icon_512.png (512x512, fundo transparente)')
print('   - feature_1024x500.png (1024x500, fundo transparente)')
