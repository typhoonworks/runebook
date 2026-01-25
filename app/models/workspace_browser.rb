# frozen_string_literal: true

# WorkspaceBrowser is a read-only service for browsing directories and files.
# File and directory creation should be handled by Notebook.create_at_path! and
# Notebooks::DirectoriesController respectively.
class WorkspaceBrowser
  Result = Struct.new(:success?, :current_path, :parent_path, :workspace_root, :entries, :error, keyword_init: true)
  Entry = Struct.new(:name, :path, :type, keyword_init: true)

  def initialize(workspace_dir: nil, restrict_to_workspace: true)
    @workspace_dir = workspace_dir || Notebook.workspace_dir
    @restrict_to_workspace = restrict_to_workspace
  end

  def browse(path = nil)
    requested_path = path.presence || @workspace_dir.to_s

    begin
      resolved_path = Pathname.new(requested_path).expand_path

      if @restrict_to_workspace && !within_workspace?(resolved_path)
        return Result.new(success?: false, error: "Path outside workspace")
      end
    rescue ArgumentError
      return Result.new(success?: false, error: "Invalid path")
    end

    unless resolved_path.directory?
      return Result.new(success?: false, error: "Directory not found")
    end

    entries = build_entries(resolved_path)
    parent_path = calculate_parent_path(resolved_path)

    Result.new(
      success?: true,
      current_path: resolved_path.to_s,
      parent_path: parent_path,
      workspace_root: @workspace_dir.to_s,
      entries: entries
    )
  end

  def within_workspace?(path)
    expanded = Pathname.new(path).expand_path
    workspace = Pathname.new(@workspace_dir).expand_path
    expanded.to_s.start_with?(workspace.to_s)
  end

  private

  def build_entries(resolved_path)
    entries = []

    resolved_path.children.sort_by { |p| [ p.directory? ? 0 : 1, p.basename.to_s.downcase ] }.each do |child|
      next if child.basename.to_s.start_with?(".")

      if child.directory?
        entries << Entry.new(name: child.basename.to_s, path: child.to_s, type: "directory")
      elsif child.extname == ".runemd"
        entries << Entry.new(name: child.basename.to_s, path: child.to_s, type: "file")
      end
    end

    entries
  rescue Errno::EACCES
    []
  end

  def calculate_parent_path(resolved_path)
    if @restrict_to_workspace
      workspace = Pathname.new(@workspace_dir).expand_path
      return nil if resolved_path == workspace
      return nil unless within_workspace?(resolved_path.parent)
    else
      return nil if resolved_path.root?
    end

    resolved_path.parent.to_s
  end
end
