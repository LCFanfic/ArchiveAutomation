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

    var bottomOffset = 10;

    var left = 50;
    var right = 800 - left;
    var bottom = 1280 - bottomOffset;
    var fanart = new SKRect(left: left, right: right, top: 427, bottom: 427 + 525);

    var colors = new[] { new SKColor(50, 80, 220), new SKColor (200, 200, 232)};

    var titleArea = new SKRect(left: left, right: right, top: fanart.Bottom + 1, bottom: bottom - fontAuthor.Spacing - fontPublisher.Spacing);
    var titleBottom = DrawWrappedText (canvas,  title, titleArea, SKTextAlign.Center, fontTitle, colors);

    var authorArea = new SKRect(left: left, right: right, top: titleBottom + 1, bottom: titleBottom + fontAuthor.Spacing);
    DrawSingleLineText(canvas, author, authorArea, SKTextAlign.Center, fontAuthor, SKColors.White);

    var publisherArea = new SKRect(left: left, right: right, top: bottom + 1 - fontPublisher.Spacing, bottom: bottom);
    DrawSingleLineText(canvas, publisher, publisherArea, SKTextAlign.Center, fontPublisher, SKColors.White);

    using var image = surface.Snapshot();

    var imageFormat = Path.GetExtension(outputPath).ToLower() switch
    {
        ".jpg" => SKEncodedImageFormat.Jpeg,
        ".png" => SKEncodedImageFormat.Png,
        _ => SKEncodedImageFormat.Png
    };
    using var data = image.Encode(imageFormat, 95);
    using var outputStream = File.OpenWrite(outputPath);
    data.SaveTo(outputStream);
  }

  private static void DrawSingleLineText (SKCanvas canvas, string text, SKRect rect, SKTextAlign textAlign, SKFont font, SKColor color)
  {
    var baseline = rect.Bottom - ((rect.Height - font.Metrics.XMax) / 2);

    using var paint = new SKPaint { IsAntialias = true, Color = color };
    canvas.DrawText(text, rect.MidX, baseline, textAlign, font, paint);
  }

  private static float DrawWrappedText (SKCanvas canvas, string text, SKRect rect, SKTextAlign textAlign, SKFont font, SKColor[] colors)
  {
    var lines = new Queue<string>();

    if (font.MeasureText(text) < rect.Size.Width * 0.8)
    {
      lines.Enqueue(text);
    }

    if (lines.Count == 0)
    {
      var firstWhitespaceAfterHalfwayPoint = text.IndexOf(' ', text.Length / 2);
      var firstLine = text.Substring(0, firstWhitespaceAfterHalfwayPoint);
      var secondLine = text.Substring(firstWhitespaceAfterHalfwayPoint + 1);
      if (font.MeasureText(firstLine) < rect.Size.Width * 0.8)
      {
        lines.Enqueue(firstLine);
        lines.Enqueue(secondLine);
      }
    }

    if (lines.Count == 0)
    {
      var firstWhitespaceAfterFirstLine = text.IndexOf(' ', text.Length / 3);
      var firstLine = text.Substring(0, firstWhitespaceAfterFirstLine);
      var startIndexOfSecondLine = firstWhitespaceAfterFirstLine + 1;

      var firstWhitespaceAfterSecondLine = text.IndexOf(' ', startIndexOfSecondLine + text.Length / 3);
      var secondLine = text.Substring(startIndexOfSecondLine, firstWhitespaceAfterSecondLine);

      var thirdLine = text.Substring(firstWhitespaceAfterSecondLine + 1);

      lines.Enqueue(firstLine);
      lines.Enqueue(secondLine);
      lines.Enqueue(thirdLine);
    }

    var textHeight = font.Metrics.CapHeight + (lines.Count - 1) * font.Spacing;
    var remainingSpace = rect.Height - textHeight;
    var textTop = rect.Top + remainingSpace / 2;

    float baseline = textTop + font.Metrics.CapHeight;

    var shadowWith = (int) Math.Ceiling(font.Metrics.XMax * (5 / 100f));
    foreach (var line in lines)
    {
      for (int i = 1; i <= shadowWith; i++)
      {
        using var shadowFilter = SKImageFilter.CreateDropShadowOnly(
            dx: i,
            dy: i,
            sigmaX: 0,
            sigmaY: 0,
            color: SKColors.Black,
            input: null
            );
        using var shadowPaint = new SKPaint { IsAntialias = true, ImageFilter = shadowFilter };
        canvas.DrawText(line, rect.MidX, baseline, textAlign, font, shadowPaint);
      }

      using var shader = SKShader.CreateLinearGradient(
          start: new SKPoint(0, baseline - font.Metrics.CapHeight),
          end: new SKPoint(0, baseline + font.Metrics.Bottom),
          colors,
          null,
          SKShaderTileMode.Clamp);
      using var paint = new SKPaint { IsAntialias = true, Shader = shader };
      canvas.DrawText(line, rect.MidX, baseline, textAlign, font, paint);
      baseline += font.Spacing;
    }

    return baseline - font.Spacing + font.Metrics.Bottom;
  }

}