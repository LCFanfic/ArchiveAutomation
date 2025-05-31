using System;
using SkiaSharp;


namespace ArchiveAutomation.CoverGenerator;

public class Program
{
  static void Main (string[] args)
  {
    var imagePath = args[0];
    var fontPath = args[1];
    var outputPath = args[2];
    var text = args[3];

    using var inputStream = File.OpenRead(imagePath);
    using var bitmap = SKBitmap.Decode(inputStream);
    using var surface = SKSurface.Create(new SKImageInfo(bitmap.Width, bitmap.Height));
    var canvas = surface.Canvas;

    canvas.DrawBitmap(bitmap, 0, 0);

    using var typeface = SKTypeface.FromFile(fontPath);
    using SKFont font = new SKFont(typeface, size: 64);

    var colors = new[] { new SKColor(50, 80, 220), new SKColor (200, 200, 232)};

    var textArea = new SKRect(left: 50, top: 600, right: 600-50, bottom: 200);
    DrawWrappedText (canvas, text, textArea, SKTextAlign.Center, font, colors);
    
    using var image = surface.Snapshot();
    using var data = image.Encode(SKEncodedImageFormat.Png, 100);
    using var outputStream = File.OpenWrite(outputPath);
    data.SaveTo(outputStream);
  }
  
  private static void DrawWrappedText(SKCanvas canvas, string text, SKRect rect, SKTextAlign textAlign, SKFont font, SKColor[] colors)
  {
    float spaceWidth = font.MeasureText(" ");
    float lineLength = 0;
    var words = new Queue<string>();
    var lines = new Queue<string>();
    foreach (var word in text.Split(' '))
    {
      float wordWidth = font.MeasureText(word);
      lineLength += spaceWidth;
      lineLength += wordWidth;
      if (lineLength > rect.Size.Width)
      {
        lines.Enqueue(string.Join(" ", words));
        lineLength = 0;
        words.Clear();
      }
      words.Enqueue(word);
    }
    lines.Enqueue(string.Join(" ", words));

    float wordY = rect.Top + font.Size;
    foreach (var line in lines)
    {
      using var shader = SKShader.CreateLinearGradient(
          start: new SKPoint(0, wordY - font.Metrics.XHeight),
          end: new SKPoint(0, wordY + font.Metrics.Bottom),
          colors,
          null,
          SKShaderTileMode.Clamp);

      for (int i = 1; i <= 10; i++)
      {
        using var shadowFilter = SKImageFilter.CreateDropShadowOnly(
            dx: font.Metrics.XHeight * 0.01f * i,
            dy: font.Metrics.XHeight * 0.01f * i,
            sigmaX: 0,
            sigmaY: 0,
            color: SKColors.Black,
            input: null
            );
        using var shadowPaint = new SKPaint { IsAntialias = true, ImageFilter = shadowFilter};
        canvas.DrawText(line, rect.MidX, wordY, textAlign, font, shadowPaint);
      }

      using var paint = new SKPaint { IsAntialias = true, Shader = shader};
      canvas.DrawText(line, rect.MidX, wordY, textAlign, font, paint);
      wordY += font.Spacing;
    }
  }

}