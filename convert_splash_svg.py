#!/usr/bin/env python3
"""
Converte splash1.svg para PNG em alta resolução para splash screen
Usa svglib + reportlab (mais compatível com Windows)
"""
import os

INPUT_SVG = "assets/images/splash1.svg"
OUTPUT_PNG = "assets/images/splash_icon.png"

# Resolução recomendada: 3x do tamanho base (1080px para telas HD)
TARGET_SIZE = 1080

def convert_svg_to_png():
    """Converte SVG para PNG mantendo transparência"""
    
    if not os.path.exists(INPUT_SVG):
        print(f"❌ Arquivo não encontrado: {INPUT_SVG}")
        return False
    
    # Tentar método 1: svglib + reportlab
    try:
        from svglib.svglib import svg2rlg
        from reportlab.graphics import renderPM
        
        print(f"🔄 Convertendo {INPUT_SVG} para PNG (método svglib)...")
        print(f"📐 Resolução: {TARGET_SIZE}x{TARGET_SIZE}px")
        
        drawing = svg2rlg(INPUT_SVG)
        
        # Calcular escala para atingir tamanho desejado
        scale = TARGET_SIZE / max(drawing.width, drawing.height)
        drawing.width *= scale
        drawing.height *= scale
        drawing.scale(scale, scale)
        
        renderPM.drawToFile(drawing, OUTPUT_PNG, fmt='PNG', dpi=72)
        
        print(f"✅ Conversão concluída!")
        print(f"📁 Arquivo salvo em: {OUTPUT_PNG}")
        print(f"📊 Tamanho: {os.path.getsize(OUTPUT_PNG) / 1024:.2f} KB")
        
        return True
        
    except ImportError:
        print("\n⚠️ svglib não instalado, tentando método alternativo...")
    
    # Tentar método 2: Pillow + svg (limitado)
    try:
        from PIL import Image
        from io import BytesIO
        import cairosvg
        
        print(f"🔄 Convertendo {INPUT_SVG} para PNG (método cairosvg)...")
        
        png_data = cairosvg.svg2png(
            url=INPUT_SVG,
            output_width=TARGET_SIZE,
            output_height=TARGET_SIZE
        )
        
        with open(OUTPUT_PNG, 'wb') as f:
            f.write(png_data)
        
        print(f"✅ Conversão concluída!")
        print(f"📁 Arquivo salvo em: {OUTPUT_PNG}")
        
        return True
        
    except ImportError:
        pass
    
    # Se nenhum método funcionar
    print("\n❌ Nenhuma biblioteca de conversão SVG encontrada!")
    print("\n📦 Opções de instalação:")
    print("   Opção 1: pip install svglib reportlab")
    print("   Opção 2: pip install cairosvg")
    
    return False

if __name__ == "__main__":
    print("=" * 60)
    print("🎨 CONVERSOR DE SPLASH SVG → PNG")
    print("=" * 60)
    
    success = convert_svg_to_png()
    
    if success:
        print("\n" + "=" * 60)
        print("✅ PRÓXIMOS PASSOS:")
        print("=" * 60)
        print("1. Execute: flutter pub run flutter_native_splash:create")
        print("2. Teste no simulador/emulador")
        print("3. Commit e push das alterações")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("📝 ALTERNATIVA (SEM PYTHON):")
        print("=" * 60)
        print("1. Abra splash1.svg no Inkscape/Illustrator/Figma")
        print("2. Exporte como PNG 1080x1080px")
        print("3. Salve em: assets/images/splash_icon.png")
        print("4. Execute: flutter pub run flutter_native_splash:create")
        print("=" * 60)
