using System;
using System.CommandLine;
using System.CommandLine.Parsing;
using SkiaSharp;

namespace ArchiveAutomation.CoverGenerator;

public class Program
{
  public static async Task<int> Main (string[] args)
  {
    var coverTemplateOption = new Option<FileInfo>(
        name: "--cover-template",
        description: "The image used as a template for the cover. Must be a PNG or JPG image with a dimension of 800x1280 pixels.");
    coverTemplateOption.AddAlias("-c");
    coverTemplateOption.IsRequired = true;
    coverTemplateOption.AddValidator(ValidateSourceFile);

    var fontPathOption = new Option<FileInfo>(
        name: "--font",
        description: "The font file containing the font to be used when rendering the title and author.");
    fontPathOption.AddAlias("-f");
    fontPathOption.IsRequired = true;
    fontPathOption.AddValidator(ValidateSourceFile);

    var outputFileOption = new Option<FileInfo>(
        name: "--output",
        description: "The location of the outfile.");
    outputFileOption.AddAlias("-o");
    outputFileOption.IsRequired = true;

    var titleOption = new Option<string>(
        name: "--title",
        description: "The title to be printed on the cover.");
    titleOption.AddAlias("-t");
    titleOption.IsRequired = true;

    var authorOption = new Option<string>(
        name: "--author",
        description: "The author to be printed on the cover.");
    authorOption.AddAlias("-a");
    authorOption.IsRequired = true;

    var publisherOption = new Option<string>(
        name: "--publisher",
        description: "The publisher to be printed on the cover.");
    publisherOption.AddAlias("-p");
    publisherOption.IsRequired = true;

    var fanartOption = new Option<FileInfo>(
        name: "--cover-art",
        description: "The cover art to be rendered onto the cover. Must be a PNG or JPG image with a dimension of 700x725 pixels.");
    fanartOption.AddAlias("-i");
    fanartOption.IsRequired = true;
    fanartOption.AddValidator(ValidateSourceFile);

    var rootCommand = new RootCommand("Sample app for System.CommandLine");
    rootCommand.AddOption(coverTemplateOption);
    rootCommand.AddOption(fontPathOption);
    rootCommand.AddOption(outputFileOption);
    rootCommand.AddOption(titleOption);
    rootCommand.AddOption(authorOption);
    rootCommand.AddOption(publisherOption);
    rootCommand.AddOption(fanartOption);

    rootCommand.SetHandler(
        (
            coverTemplate,
            fontFile,
            outputFile,
            title,
            author,
            publisher,
            coverArt) =>
        {
          var result = Process(
              coverTemplate: coverTemplate,
              fontFile: fontFile,
              outputFile: outputFile,
              title: title,
              author: author,
              publisher: publisher,
              coverArt: coverArt);
          return Task.FromResult(result);
        },
        coverTemplateOption,
        fontPathOption,
        outputFileOption,
        titleOption,
        authorOption,
        publisherOption,
        fanartOption);

    return await rootCommand.InvokeAsync(args);
  }

  private static void ValidateSourceFile (OptionResult optionResult)
  {
    var value = optionResult.GetValueOrDefault<FileInfo>();
    if (value is null)
      return;
    if (value.Exists)
      return;

    optionResult.ErrorMessage = $"Option '{optionResult.Option.Name}' specifies a file that does not not exist: {value.FullName}";
  }

  static int Process (
      FileInfo coverTemplate,
      FileInfo fontFile,
      FileInfo outputFile,
      string title,
      string author,
      string publisher,
      FileInfo coverArt)
  {
    var coverHeight = 1280;
    var coverWidth = 800;

    var bottomOffset = 10;
    var left = 50;
    var right = coverWidth - left;
    var bottom = coverHeight - bottomOffset;

    using var surface = SKSurface.Create(new SKImageInfo(width: coverWidth, height: coverHeight));
    var canvas = surface.Canvas;

    using var coverTemplateBitmap = SKBitmap.Decode(coverTemplate.OpenRead());
    if (coverTemplateBitmap.Height != coverHeight || coverTemplateBitmap.Width != coverWidth)
    {
      Console.Error.WriteLine(
          $"Expected the cover template to be {coverWidth}x{coverHeight} but was {coverTemplateBitmap.Width}x{coverTemplateBitmap.Height}");
      return 1;
    }

    canvas.DrawBitmap(coverTemplateBitmap, 0, 0);

    var fanartArea = new SKRect(left: left, right: right, top: 427, bottom: 427 + 525);
    using var fanartBitmap = SKBitmap.Decode(coverArt.OpenRead());
    if (fanartBitmap.Height != (int)fanartArea.Height || fanartBitmap.Width != (int)fanartArea.Width)
    {
      Console.Error.WriteLine(
          $"Expected the cover art to be {fanartArea.Width}x{fanartArea.Height} but was {fanartBitmap.Width}x{fanartBitmap.Height}");
      return 1;
    }

    canvas.DrawBitmap(fanartBitmap, fanartArea);
    if (fanartBitmap.GetPixel(0, 0).Alpha == 255)
    {
      canvas.DrawRect(
          new SKRect(left: fanartArea.Left - 1, right: fanartArea.Right + 1, top: fanartArea.Top - 1, bottom: fanartArea.Bottom + 1),
          new SKPaint { Color = new SKColor(47, 47, 47, alpha: 255), StrokeWidth = 2, Style = SKPaintStyle.Stroke });
    }

    using var typeface = SKTypeface.FromFile(fontFile.FullName);
    using SKFont fontTitle = new SKFont(typeface, size: 64);
    using SKFont fontAuthor = new SKFont(typeface, size: 36);
    using SKFont fontPublisher = new SKFont(typeface, size: 24);

    var colors = new[] { new SKColor(50, 80, 220), new SKColor(200, 200, 232) };

    var titleArea = new SKRect(left: left, right: right, top: fanartArea.Bottom + 1, bottom: bottom - fontAuthor.Spacing - fontPublisher.Spacing);
    var titleBottom = DrawWrappedText(canvas, title, titleArea, SKTextAlign.Center, fontTitle, colors);

    var authorArea = new SKRect(left: left, right: right, top: titleBottom + 1, bottom: titleBottom + fontAuthor.Spacing);
    DrawSingleLineText(canvas, author, authorArea, SKTextAlign.Center, fontAuthor, SKColors.White);

    var publisherArea = new SKRect(left: left, right: right, top: bottom + 1 - fontPublisher.Spacing, bottom: bottom);
    DrawSingleLineText(canvas, publisher, publisherArea, SKTextAlign.Center, fontPublisher, SKColors.White);

    using var image = surface.Snapshot();

    var imageFormat = outputFile.Extension.ToLower() switch
    {
        ".jpg" => SKEncodedImageFormat.Jpeg,
        ".png" => SKEncodedImageFormat.Png,
        _ => SKEncodedImageFormat.Png
    };
    using var data = image.Encode(imageFormat, 95);
    using var outputStream = outputFile.OpenWrite();
    data.SaveTo(outputStream);

    return 0;
  }

  private static void DrawSingleLineText (SKCanvas canvas, string text, SKRect rect, SKTextAlign textAlign, SKFont font, SKColor color)
  {
    var baseline = rect.Bottom - ((rect.Height - font.Metrics.XMax) / 2);

    using var paint = new SKPaint { IsAntialias = true, Color = color };
    canvas.DrawText(text, rect.MidX, baseline, textAlign, font, paint);
  }

  private static float DrawWrappedText (SKCanvas canvas, string text, SKRect rect, SKTextAlign textAlign, SKFont font, SKColor[] colors)
  {
    var maxWidth = rect.Size.Width * 0.8;
    var lines = new Queue<string>();
    const int c_maxLines = 3;

    for (int lineCount = 1; lineCount <= c_maxLines && lines.Count == 0; lineCount++)
    {
      var startIndexOfCurrentLine = 0;
      for (int i = 1; i <= lineCount; i++)
      {
        var startIndexForFirstWhitespaceAfterCurrentLine = startIndexOfCurrentLine + text.Length / lineCount;
        var firstWhiteSpaceAfterCurrentLine =
            startIndexForFirstWhitespaceAfterCurrentLine < text.Length ? text.IndexOf(' ', startIndexForFirstWhitespaceAfterCurrentLine) : -1;

        var currentLine = text.Substring(
            startIndexOfCurrentLine,
            (firstWhiteSpaceAfterCurrentLine >= 0 ? firstWhiteSpaceAfterCurrentLine : text.Length) - startIndexOfCurrentLine);

        var isLastChance = lineCount == c_maxLines;
        var isFirstLine = lines.Count == 0;
        if (!isLastChance && isFirstLine && font.MeasureText(currentLine) > maxWidth)
          break;

        lines.Enqueue(currentLine);
        startIndexOfCurrentLine = firstWhiteSpaceAfterCurrentLine + 1;
      }
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