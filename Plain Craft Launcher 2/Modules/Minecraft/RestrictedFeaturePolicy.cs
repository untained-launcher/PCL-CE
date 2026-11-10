namespace PCL;

/// <summary>
/// 本 fork 不实行任何地区功能限制，所有检查恒放行。
/// 保留与上游一致的成员签名，使上游调用点无需改动，
/// 上游修改调用点也不会与本地改动产生冲突。
/// </summary>
internal static class RestrictedFeaturePolicy
{
    internal static bool IsRestricted => false;

    internal static bool Check(string feature, bool showHint = true) => true;

    internal static void ThrowIfRestricted(string feature)
    {
    }
}
