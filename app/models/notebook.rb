require "runebook/runemd"

class Notebook < ApplicationRecord
  DEFAULT_TITLE = "Untitled notebook".freeze
  DEFAULT_AUTOSAVE_INTERVAL = 30_000
  DEFAULT_SETUP_CONTENT = <<~RUBY.strip
    # Install gems for this notebook
    # Example:
    # gem "faker", "~> 3.0"
    # gem "httparty"
  RUBY

  has_many :sessions, dependent: :destroy

  validate :validate_file_path_extension

  scope :user_persisted, -> do
    where.not("file_path GLOB '*untitled-????????-??????-????.runemd'")
  end

  def self.from_id_or_blank(id)
    id.present? ? find(id) : create_blank!
  end

  def self.create_from_content!(content, title: nil)
    parsed = Runebook::Runemd.parse(content)
    notebook_title = title || parsed.title || DEFAULT_TITLE

    FileUtils.mkdir_p(unsaved_dir)

    timestamp = Time.now.utc.strftime("%Y%m%d-%H%M%S")
    unique = SecureRandom.alphanumeric(4).downcase
    basename = "untitled-#{timestamp}-#{unique}.runemd"
    path = unsaved_dir.join(basename)

    Tempfile.create([ "import-", ".runemd" ], unsaved_dir.to_s) do |tmp|
      tmp.write(content)
      tmp.flush
      FileUtils.mv(tmp.path, path)
    end

    create!(
      title: notebook_title,
      format: "runemd",
      version: parsed.version || 1,
      dirty: false,
      file_path: path.to_s
    )
  end

  def self.find_or_create_from_path!(file_path)
    expanded_path = Pathname.new(file_path).expand_path.to_s

    existing = find_by(file_path: expanded_path)
    return existing if existing

    unless File.exist?(expanded_path)
      raise ActiveRecord::RecordNotFound, "File not found: #{expanded_path}"
    end

    content = File.read(expanded_path)
    parsed = Runebook::Runemd.parse(content)

    create!(
      title: parsed.title || DEFAULT_TITLE,
      format: "runemd",
      version: parsed.version || 1,
      dirty: false,
      file_path: expanded_path
    )
  end

  def self.create_at_path!(directory:, filename:)
    file_name = filename.to_s.strip
    file_name = "#{file_name}.runemd" unless file_name.end_with?(".runemd")

    raise ArgumentError, "Filename is required" if file_name == ".runemd"
    raise ArgumentError, "Invalid filename" unless file_name.match?(/\A[\w\-. ]+\.runemd\z/)

    parent_dir = Pathname.new(directory).expand_path
    new_file = parent_dir.join(file_name)

    raise "File already exists" if new_file.exist?

    initial_content = Runebook::Runemd.export({
      version: 1,
      autosave_interval: DEFAULT_AUTOSAVE_INTERVAL,
      title: File.basename(file_name, ".runemd"),
      setup_cell: { type: :setup, content: DEFAULT_SETUP_CONTENT },
      sections: [ { title: "Section", cells: [ { type: :ruby, content: "" } ] } ]
    })

    FileUtils.mkdir_p(parent_dir)
    File.write(new_file, initial_content)

    create!(
      title: File.basename(file_name, ".runemd"),
      format: "runemd",
      version: 1,
      dirty: false,
      file_path: new_file.to_s
    )
  rescue Errno::ENOENT, Errno::EACCES => e
    raise "Failed to create notebook: #{e.message}"
  end

  def self.workspace_dir
    Rails.root.join("storage", "notebooks")
  end

  def self.autosave_dir
    Rails.root.join("storage", "autosave")
  end

  def self.unsaved_dir
    Rails.root.join("storage", "autosave", "unsaved")
  end

  def self.create_blank!(title: DEFAULT_TITLE)
    FileUtils.mkdir_p(unsaved_dir)

    timestamp = Time.now.utc.strftime("%Y%m%d-%H%M%S")
    unique = SecureRandom.alphanumeric(4).downcase
    basename = "untitled-#{timestamp}-#{unique}.runemd"
    path = unsaved_dir.join(basename)

    initial = Runebook::Runemd.export({
      version: 1,
      autosave_interval: DEFAULT_AUTOSAVE_INTERVAL,
      title: title,
      setup_cell: { type: :setup, content: DEFAULT_SETUP_CONTENT },
      sections: [ { title: "Section", cells: [ { type: :ruby, content: "" } ] } ]
    })

    Tempfile.create([ "new-", ".runemd" ], unsaved_dir.to_s) do |tmp|
      tmp.write(initial)
      tmp.flush
      FileUtils.mv(tmp.path, path)
    end

    create!(
      title: title,
      format: "runemd",
      version: 1,
      dirty: false,
      file_path: path.to_s
    )
  end

  def mark_dirty!
    return if dirty?

    update!(dirty: true)
    broadcast_dirty_state
  end

  def mark_clean!
    return unless dirty?

    update!(dirty: false, last_saved_at: Time.current)
    broadcast_dirty_state
  end

  def autosave_path(session_token)
    date_dir = Date.current.strftime("%Y_%m_%d")
    dir = self.class.autosave_dir.join(date_dir, session_token)
    dir.join("notebook.runemd")
  end

  def broadcast_dirty_state
    ActionCable.server.broadcast(
      "notebook_#{id}",
      { type: "dirty_state", dirty: dirty? }
    )
  end

  def effective_autosave_interval
    autosave_interval || DEFAULT_AUTOSAVE_INTERVAL
  end

  def open_session
    sessions.find_by(status: :open)
  end

  def find_or_start_session
    open_session || sessions.create!(started_at: Time.current)
  end

  def parsed_content
    return nil unless file_path.present? && File.exist?(file_path)

    Runebook::Runemd.parse(File.read(file_path))
  rescue => e
    Rails.logger.error("Failed to parse .runemd: #{e.message}")
    nil
  end

  # Returns true if the file_path was user-chosen (not auto-generated)
  # Auto-generated paths match: untitled-YYYYMMDD-HHMMSS-XXXX.runemd
  def persisted_to_user_path?
    return false if file_path.blank?

    basename = File.basename(file_path)
    !basename.match?(/\Auntitled-\d{8}-\d{6}-[a-z0-9]{4}\.runemd\z/)
  end

  def cleanup_if_autogenerated!
    return false if persisted_to_user_path?

    FileUtils.rm_f(file_path) if file_path.present?
    destroy
    true
  end

  private

  def validate_file_path_extension
    return if file_path.blank?
    return if file_path.end_with?(".runemd")

    errors.add(:file_path, "must end with .runemd")
  end
end
