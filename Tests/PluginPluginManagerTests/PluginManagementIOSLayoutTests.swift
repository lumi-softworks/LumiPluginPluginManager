import Foundation
import Testing

/// 插件管理页的 iOS 布局守卫。
///
/// iOS 版本不摆 macOS 的面板/分栏，而是走系统设置页的形态：分组列表、
/// 导航栏搜索、原生工具栏与滑动操作。这套断言防止后续改动把 iOS 分支
/// 悄悄退回桌面样式，或让页面自带导航栈与宿主冲突。
@Suite("插件管理页 iOS 布局")
struct PluginManagementIOSLayoutTests {
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PluginPluginManagerTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // <pkg>
    }

    private static func source(_ relativePath: String) throws -> String {
        let url = Self.packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func iosView() throws -> String {
        try source("Sources/PluginPluginManager/Views/PluginManagementIOSView.swift")
    }

    @Test("iOS 入口与 macOS 分栏分离")
    func routesToIOSView() throws {
        let view = try Self.source("Sources/PluginPluginManager/Views/PluginManagementView.swift")
        #expect(
            view.contains("#if os(iOS)"),
            Comment(rawValue: "PluginManagementView 必须按平台分流")
        )
        #expect(
            view.contains("PluginManagementIOSView(viewModel: viewModel)"),
            Comment(rawValue: "iOS 分支必须交给 PluginManagementIOSView")
        )
    }

    @Test("iOS 使用系统分组列表与导航栏搜索")
    func usesNativeListAndSearch() throws {
        let ios = try Self.iosView()
        #expect(
            ios.contains(".listStyle(.insetGrouped)"),
            Comment(rawValue: "iOS 列表必须使用 insetGrouped，匹配系统设置页")
        )
        #expect(
            ios.contains(".searchable("),
            Comment(rawValue: "搜索必须挂在导航栏（.searchable），而不是塞进列表内容")
        )
        #expect(
            ios.contains("if viewModel.showsSearchBar"),
            Comment(rawValue: "搜索入口仍需遵守插件数量阈值")
        )
        #expect(
            ios.components(separatedBy: ".searchable(").count == 2,
            Comment(rawValue: ".searchable 只应出现一次，且位于数量阈值条件分支内")
        )
        #expect(
            ios.contains("ContentUnavailableView"),
            Comment(rawValue: "空态必须使用 iOS 原生 ContentUnavailableView")
        )
    }

    @Test("iOS 提供滑动启停与批量停用确认")
    func offersSwipeAndBatchActions() throws {
        let ios = try Self.iosView()
        #expect(
            ios.contains(".swipeActions(edge: .leading"),
            Comment(rawValue: "未启用的插件应支持左滑启用")
        )
        #expect(
            ios.contains(".swipeActions(edge: .trailing"),
            Comment(rawValue: "已启用的插件应支持右滑停用")
        )
        #expect(
            ios.contains(".confirmationDialog("),
            Comment(rawValue: "批量停用必须先确认，避免误触")
        )
    }

    @Test("iOS 详情使用原生信息行")
    func detailUsesNativeInformationRows() throws {
        let ios = try Self.iosView()
        #expect(
            ios.contains("struct PluginSettingsDetailIOSView"),
            Comment(rawValue: "iOS 详情页必须独立实现，不复用 macOS 的贴边面板")
        )
        #expect(
            ios.contains("LabeledContent"),
            Comment(rawValue: "分类/版本/策略/标识应使用 LabeledContent 原生信息行")
        )
        #expect(
            ios.contains("viewModel.isDefaultAbout(pluginID:"),
            Comment(rawValue: "自动生成的兜底关于页会与原生信息行重复，iOS 应跳过")
        )
        #expect(
            ios.contains(".navigationBarTitleDisplayMode(.inline)"),
            Comment(rawValue: "详情页标题应与 iOS 设置子页一致使用 inline")
        )
    }

    @Test("iOS 页面不自带导航栈且不复用桌面面板")
    func avoidsDesktopChrome() throws {
        let ios = try Self.iosView()
        #expect(
            !ios.contains("NavigationStack"),
            Comment(rawValue: "宿主已提供导航栈，页面自带会造成嵌套导航")
        )
        #expect(
            !ios.contains("AppSettingsContentScaffold"),
            Comment(rawValue: "iOS 不应复用 macOS 的设置内容 scaffold")
        )
        #expect(
            !ios.contains(".appSurface("),
            Comment(rawValue: "iOS 列表行由系统提供底色，不应再套桌面面板")
        )
    }
}