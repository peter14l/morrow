using System.Text.Json;

namespace Oasis.WinUI.Core.Models;

/// <summary>Small helpers for reading snake_case PostgREST/RPC JSON payloads.</summary>
internal static class JsonUtil
{
    public static string? S(JsonElement el, params string[] names)
    {
        foreach (var n in names)
        {
            if (el.TryGetProperty(n, out var v))
            {
                if (v.ValueKind == JsonValueKind.String)
                    return v.GetString();
                if (v.ValueKind == JsonValueKind.Number)
                    return v.GetRawText();
            }
        }
        return null;
    }

    public static long L(JsonElement el, params string[] names)
    {
        foreach (var n in names)
        {
            if (el.TryGetProperty(n, out var v))
            {
                if (v.ValueKind == JsonValueKind.Number) return v.GetInt64();
                if (v.ValueKind == JsonValueKind.String && long.TryParse(v.GetString(), out var parsed)) return parsed;
            }
        }
        return 0;
    }

    public static int I(JsonElement el, params string[] names)
    {
        foreach (var n in names)
        {
            if (el.TryGetProperty(n, out var v))
            {
                if (v.ValueKind == JsonValueKind.Number) return v.GetInt32();
                if (v.ValueKind == JsonValueKind.String && int.TryParse(v.GetString(), out var parsed)) return parsed;
            }
        }
        return 0;
    }

    public static bool B(JsonElement el, params string[] names)
    {
        foreach (var n in names)
        {
            if (el.TryGetProperty(n, out var v))
            {
                if (v.ValueKind == JsonValueKind.True) return true;
                if (v.ValueKind == JsonValueKind.False) return false;
                if (v.ValueKind == JsonValueKind.Number) return v.GetInt64() != 0;
            }
        }
        return false;
    }

    public static DateTime? Dt(JsonElement el, params string[] names)
    {
        var s = S(el, names);
        if (string.IsNullOrEmpty(s)) return null;
        return DateTime.TryParse(s, out var d) ? d.ToLocalTime() : null;
    }

    public static Dictionary<string, object>? Dict(JsonElement el, params string[] names)
    {
        foreach (var n in names)
        {
            if (el.TryGetProperty(n, out var v) && v.ValueKind == JsonValueKind.Object)
            {
                var dict = new Dictionary<string, object>();
                foreach (var p in v.EnumerateObject())
                {
                    dict[p.Name] = p.Value.ValueKind == JsonValueKind.String
                        ? p.Value.GetString() ?? ""
                        : p.Value.ToString();
                }
                return dict;
            }
        }
        return null;
    }

    public static List<string> StrList(JsonElement el, params string[] names)    {
        foreach (var n in names)
        {
            if (el.TryGetProperty(n, out var v) && v.ValueKind == JsonValueKind.Array)
            {
                var list = new List<string>();
                foreach (var item in v.EnumerateArray())
                {
                    if (item.ValueKind == JsonValueKind.String) list.Add(item.GetString()!);
                    else list.Add(item.ToString());
                }
                return list;
            }
        }
        return new List<string>();
    }

    public static string? NestedProfile(JsonElement el, string joinKey, string field)
    {
        if (el.TryGetProperty(joinKey, out var profile))
        {
            if (profile.ValueKind == JsonValueKind.Object)
                return S(profile, field);
            if (profile.ValueKind == JsonValueKind.Array && profile.GetArrayLength() > 0)
                return S(profile[0], field);
        }
        return null;
    }
}
