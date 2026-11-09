namespace PCL;

public sealed class WpfLogFilter : ILogFilter
{
    public string FilterUserName(string raw, char filterChar)
    {
        return McLogFilter.FilterUserName(raw, filterChar);
    }

    public string FilterAccessToken(string raw, char filterChar)
    {
        return McLogFilter.FilterAccessToken(raw, filterChar);
    }
}

public sealed class WpfRestrictedFeatures : IRestrictedFeatures
{
    // 本 fork 不实行地区功能限制：桩实现令所有检查恒不放行。
    public bool IsRestricted => false;

    public bool Check(string feature)
    {
        return false;
    }

    public void ThrowIfRestricted(string feature)
    {
    }
}
