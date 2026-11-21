#if os(iOS)
import KernelCore
import LumiUI
import SwiftUI

/// iOS 插件管理页。
///
/// 交互遵循系统设置页的习惯：导航栏搜索、`insetGrouped` 分组列表、
/// 工具栏批量操作、左滑直接启停。宿主负责把它放进自己的导航栈，
/// 因此这里不额外创建导航容器。
struct PluginManagementIOSView: View {
    @ObservedObject private var viewModel: PluginManagementViewModel
    @State private var isConfirmingDisableAll = false

    init(viewModel: PluginManagementViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        content
            .navigationTitle(PluginPluginManagerText.plugins)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    moreActionsMenu
                }
            }
            .confirmationDialog(
                PluginPluginManagerText.disableAllConfirmationTitle,
                isPresented: $isConfirmingDisableAll,
                titleVisibility: .visible
            ) {
                Button(PluginPluginManagerText.disableAll, role: .destructive) {
                    viewModel.disableAllPlugins()
                }
                Button(PluginPluginManagerText.cancel, role: .cancel) {}
            } message: {
                Text(PluginPluginManagerText.disableAllConfirmationMessage)
            }
            .alert(
                PluginPluginManagerText.errorTitle,
                isPresented: errorAlertBinding
            ) {
                Button(PluginPluginManagerText.okButton, role: .cancel) {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onAppear {
                viewModel.normalizeSelection()
            }
            .onChange(of: viewModel.filteredPlugins.map(\.id)) { _, _ in
                viewModel.normalizeSelection()
            }
    }

    // MARK: - 列表

    @ViewBuilder
    private var content: some View {
        if viewModel.showsSearchBar {
            pluginList
                .searchable(
                    text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(PluginPluginManagerText.searchPlugins)
                )
        } else {
            pluginList
        }
    }

    private var pluginList: some View {
        List {
            if !viewModel.plugins.isEmpty {
                filterSection
            }

            pluginSection
        }
        .listStyle(.insetGrouped)
    }

    private var filterSection: some View {
        Section {
            Picker(selection: $viewModel.statusFilter) {
                ForEach(PluginManagementFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            } label: {
                Text(PluginPluginManagerText.statusFilterLabel)
            }
            .pickerStyle(.segmented)

            if viewModel.availableCategories.count > 1 {
                categoryMenu
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    String(
                        format: PluginPluginManagerText.pluginsSummary,
                        viewModel.plugins.count,
                        viewModel.enabledCount
                    )
                )

                if viewModel.hasActiveFilters {
                    Button(PluginPluginManagerText.clearFilters) {
                        viewModel.resetFilters()
                    }
                    .font(.footnote)
                }
            }
        }
    }

    private var categoryMenu: some View {
        Picker(
            selection: $viewModel.selectedCategory
        ) {
            Text(PluginPluginManagerText.allCategories)
                .tag(PluginCategory?.none)

            ForEach(viewModel.availableCategories, id: \.self) { category in
                Text(category.displayName)
                    .tag(Optional(category))
            }
        } label: {
            Text(PluginPluginManagerText.categoryFilterLabel)
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var pluginSection: some View {
        if viewModel.filteredPlugins.isEmpty {
            Section {
                emptyState
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("plugin-management.empty")
            }
        } else {
            Section {
                ForEach(viewModel.filteredPlugins) { plugin in
                    pluginRow(plugin)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView {
                Label(PluginPluginManagerText.noPluginsFound, systemImage: "puzzlepiece.extension")
            } description: {
                Text(PluginPluginManagerText.noPluginsFilteredHint)
            }
        } else {
            ContentUnavailableView.search(text: viewModel.searchText)
        }
    }

    // MARK: - 行

    private func pluginRow(_ plugin: PluginManagementItem) -> some View {
        NavigationLink {
            PluginSettingsDetailIOSView(viewModel: viewModel, pluginID: plugin.id)
        } label: {
            PluginManagementIOSRow(plugin: plugin)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !plugin.isEnabled {
                Button {
                    viewModel.setEnabled(true, for: plugin.id)
                } label: {
                    Label(PluginPluginManagerText.enable, systemImage: "checkmark.circle")
                }
                .tint(.green)
                .disabled(viewModel.isUpdating(pluginID: plugin.id))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if plugin.isEnabled {
                Button(role: .destructive) {
                    viewModel.setEnabled(false, for: plugin.id)
                } label: {
                    Label(PluginPluginManagerText.disable, systemImage: "xmark.circle")
                }
                .disabled(viewModel.isUpdating(pluginID: plugin.id))
            }
        }
        .accessibilityIdentifier("plugin-management.row.\(plugin.id)")
    }

    // MARK: - 工具栏

    private var moreActionsMenu: some View {
        Menu {
            Button(role: .destructive) {
                isConfirmingDisableAll = true
            } label: {
                Label(
                    viewModel.isDisablingAll
                        ? PluginPluginManagerText.disablingAll
                        : PluginPluginManagerText.disableAll,
                    systemImage: "xmark.circle"
                )
            }
            .disabled(viewModel.isDisablingAll || viewModel.enabledCount == 0)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(Text(PluginPluginManagerText.moreActions))
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )
    }
}

/// iOS 列表行：分类图标 + 名称/描述 + 启用状态。
struct PluginManagementIOSRow: View {
    @LumiTheme private var theme

    let plugin: PluginManagementItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: plugin.metadata.category.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.primary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.metadata.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(
                    plugin.metadata.description.isEmpty
                        ? plugin.id
                        : plugin.metadata.description
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(plugin.isEnabled ? PluginPluginManagerText.enabled : PluginPluginManagerText.disabled)
                .font(.caption.weight(.medium))
                .foregroundStyle(plugin.isEnabled ? theme.success : Color.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// iOS 插件详情页：原生分组列表承载头部、启停开关与元数据。
struct PluginSettingsDetailIOSView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: PluginManagementViewModel

    let pluginID: String

    init(viewModel: PluginManagementViewModel, pluginID: String) {
        self.viewModel = viewModel
        self.pluginID = pluginID
    }

    var body: some View {
        List {
            Section {
                header
            }

            Section {
                Toggle(isOn: Binding(
                    get: { plugin.isEnabled },
                    set: { viewModel.setEnabled($0, for: pluginID) }
                )) {
                    Text(PluginPluginManagerText.enable)
                        .font(.body)
                }
                .disabled(viewModel.isUpdating(pluginID: pluginID))
            }

            Section {
                infoRow(title: PluginPluginManagerText.categoryLabel, value: plugin.metadata.category.displayName)
                infoRow(title: PluginPluginManagerText.versionLabel, value: plugin.metadata.version)
                infoRow(
                    title: PluginPluginManagerText.policyLabel,
                    value: plugin.metadata.policy.policyName
                )
                infoRow(title: PluginPluginManagerText.identifierLabel, value: plugin.id, monospaced: true)
            } header: {
                Text(PluginPluginManagerText.informationSectionTitle)
            }

            if !plugin.metadata.permissions.isEmpty {
                Section {
                    ForEach(plugin.metadata.permissions, id: \.id) { permission in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(permission.id)
                                .font(.subheadline.weight(.medium))
                            Text(permission.reason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(PluginPluginManagerText.permissionsTitle)
                }
            }

            if !viewModel.isDefaultAbout(pluginID: plugin.id),
               let aboutEntry = viewModel.aboutEntry(for: plugin.id) {
                Section {
                    aboutEntry.makeView()
                        .padding(.vertical, 4)
                } header: {
                    Text(PluginPluginManagerText.aboutSectionTitle)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(plugin.metadata.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectPlugin(id: pluginID)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: plugin.metadata.category.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.primary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(plugin.metadata.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    if plugin.metadata.stage != .stable {
                        AppTag(plugin.metadata.stage.displayName, style: .subtle)
                    }
                }

                if !plugin.metadata.description.isEmpty {
                    Text(plugin.metadata.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func infoRow(title: String, value: String, monospaced: Bool = false) -> some View {
        LabeledContent {
            Text(value)
                .font(monospaced ? .footnote.monospaced() : .body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(title)
                .foregroundStyle(.primary)
        }
    }

    private var plugin: PluginManagementItem {
        guard let plugin = viewModel.plugins.first(where: { $0.id == pluginID }) else {
            preconditionFailure("PluginSettingsDetailIOSView requires a valid plugin id")
        }
        return plugin
    }
}
#endif