using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;
using Microsoft.UI.Xaml.Media.Imaging;

namespace Oasis.WinUI.Core.Converters;

public sealed class ImageUrlConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        if (value is not string url || string.IsNullOrWhiteSpace(url)) return null;
        try
        {
            return new BitmapImage(new Uri(url));
        }
        catch
        {
            return null;
        }
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}

public sealed class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => string.IsNullOrWhiteSpace(value as string) ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}

public sealed class DateTimeToStringConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        if (value is not DateTime dt) return "";
        if (parameter is string format && format.Length > 0) return dt.ToString(format);
        return dt.ToString("MMM d, yyyy HH:mm");
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}

public sealed class PositiveNumberToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        long n = 0;
        switch (value)
        {
            case long l: n = l; break;
            case int i: n = i; break;
            case string s when long.TryParse(s, out var parsed): n = parsed; break;
        }
        return n > 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}

public sealed class BoolToTextConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        var parts = (parameter as string)?.Split('|') ?? new[] { "On", "Off" };
        return value is bool b && b ? (parts.Length > 0 ? parts[0] : "On") : (parts.Length > 1 ? parts[1] : "Off");
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
