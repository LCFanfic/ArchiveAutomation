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
    var title = args[3];
    var author = args[4]; 
    var publisher = args[5];

    using var inputStream = File.OpenRead(imagePath);
    using var bitmap = SKBitmap.Decode(inputStream);
    using var surface = SKSurface.Create(new SKImageInfo(bitmap.Width, bitmap.Height));
    var canvas = surface.Canvas;

    canvas.DrawBitmap(bitmap, 0, 0);

    using var typeface = SKTypeface.FromFile(fontPath);
    using SKFont fontTitle = new SKFont(typeface, size: 64);
    using SKFont fontAuthor = new SKFont(typeface, size: 36);
    using SKFont fontPublisher = new SKFont(typeface, size: 24);

    var colors = new[] { new SKColor(50, 80, 220), new SKColor (200, 200, 232)};

    var titleArea = new SKRect(left: 50, top: 980, right: 750, bottom: 1158);
    DrawWrappedText (canvas,  title, titleArea, SKTextAlign.Center, fontTitle, colors);

    var authorArea = new SKRect(left: 50, top: 1166, right: 750, bottom: 1206);
    DrawSingleLineText(canvas, author, authorArea, SKTextAlign.Center, fontAuthor, SKColors.White);

    var publisherArea = new SKRect(left: 50, top: 1230, right: 750, bottom: 1280);
    DrawSingleLineText(canvas, publisher, publisherArea, SKTextAlign.Center, fontPublisher, SKColors.White);

    using var image = surface.Snapshot();
    using var data = image.Encode(SKEncodedImageFormat.Png, 100);
    using var outputStream = File.OpenWrite(outputPath);
    data.SaveTo(outputStream);
  }

  private static void DrawSingleLineText (SKCanvas canvas, string text, SKRect rect, SKTextAlign textAlign, SKFont font, SKColor color)
  {
    var baseline = rect.Bottom - ((rect.Height - font.Metrics.XMax) / 2);

    using var paint = new SKPaint { IsAntialias = true, Color = color };
    canvas.DrawText(text, rect.MidX, baseline, SKTextAlign.Center, font, paint);
  }

  private static void DrawWrappedText (SKCanvas canvas, string text, SKRect rect, SKTextAlign textAlign, SKFont font, SKColor[] colors)
  {
    var lines = new Queue<string>();

    // float lineLength = 0;
    // float spaceWidth = font.MeasureText(" ");
    // var words = new Queue<string>();
    // foreach (var word in text.Split(' '))
    // {
    //   float wordWidth = font.MeasureText(word);
    //   lineLength += spaceWidth;
    //   lineLength += wordWidth;
    //   if (lineLength > rect.Size.Width)
    //   {
    //     lines.Enqueue(string.Join(" ", words));
    //     lineLength = 0;
    //     words.Clear();
    //   }
    //
    //   words.Enqueue(word);
    // }
    //
    // lines.Enqueue(string.Join(" ", words));

    float textWidth = font.MeasureText(text);
    if (textWidth < rect.Size.Width * 0.8)
    {
      lines.Enqueue(text);
    }
    else
    {
      var halfwayPoint = text.Length / 2;
      var firstWhitespaceAfterHalfwayPoint = text.IndexOf(' ', halfwayPoint);
      var firstWhitespaceBeforeHalfwayPoint = text.LastIndexOf(' ', halfwayPoint);
      var firstLine = text.Substring(0, firstWhitespaceAfterHalfwayPoint);
      var secondLine = text.Substring(firstWhitespaceAfterHalfwayPoint + 1);
      lines.Enqueue(firstLine);
      lines.Enqueue(secondLine);
    }

    float wordY = rect.Top + font.Metrics.XMax;
    if (lines.Count == 1)
      wordY += font.Metrics.XMax;

    foreach (var line in lines)
    {
      for (int i = 1; i <= 1; i++)
      {
        using var shadowFilter = SKImageFilter.CreateDropShadowOnly(
            dx: (float)(Math.Floor(font.Metrics.XMax * 0.01f) + i),
            dy: (float)(Math.Floor(font.Metrics.XMax * 0.01f) + i),
            sigmaX: 0,
            sigmaY: 0,
            color: SKColors.White,
            input: null
            );
        using var shadowPaint = new SKPaint { IsAntialias = true, ImageFilter = shadowFilter };
        canvas.DrawText(line, rect.MidX, wordY, textAlign, font, shadowPaint);
      }

      using var shader = SKShader.CreateLinearGradient(
          start: new SKPoint(0, wordY - font.Metrics.XMax),
          end: new SKPoint(0, wordY + font.Metrics.Bottom),
          colors,
          null,
          SKShaderTileMode.Clamp);
      using var paint = new SKPaint { IsAntialias = true, Shader = shader };
      canvas.DrawText(line, rect.MidX, wordY, textAlign, font, paint);
      wordY += font.Spacing;
    }
  }

}