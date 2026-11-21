import ProviderDocsView

/// Plugin Manager 需要的最小文档能力边界。
///
/// ViewModel 只按插件 ID 读取 About 条目，不需要注册 / 移除 / 事件订阅能力
/// （注册与移除由插件入口负责）。
@MainActor
protocol PluginManagerDocsCapability: AnyObject {
    /// 查询指定插件的 About 条目；未注册时返回 `nil`。
    func aboutEntry(for pluginID: String) -> DocsEntry?

    /// 该插件的 About 是否由插件管理器自动生成的兜底页。
    ///
    /// iOS 详情页用元数据原生分区展示分类、版本、策略、权限，兜底页的内容
    /// 与之重复，因此只在插件贡献了自己的 About 时才展示「关于」分区。
    func isDefaultAbout(pluginID: String) -> Bool
}

extension PluginManagerDocsCapability {
    func isDefaultAbout(pluginID: String) -> Bool { false }
}

/// 将内核的 `DocsViewProviding` 收窄为 Plugin Manager 的文档查询能力。
@MainActor
final class PluginManagerDocsCapabilityAdapter: PluginManagerDocsCapability {
    private let docs: (any DocsViewProviding)?
    private let isDefaultAboutProvider: @MainActor (String) -> Bool

    init(
        docs: (any DocsViewProviding)?,
        isDefaultAbout: @escaping @MainActor (String) -> Bool = { _ in false }
    ) {
        self.docs = docs
        self.isDefaultAboutProvider = isDefaultAbout
    }

    func aboutEntry(for pluginID: String) -> DocsEntry? {
        docs?.aboutEntries.first { $0.id == pluginID }
    }

    func isDefaultAbout(pluginID: String) -> Bool {
        isDefaultAboutProvider(pluginID)
    }
}
