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

    public bool Check(string feature)
    {
    }

    public void ThrowIfRestricted(string feature)
    {
    }
}
