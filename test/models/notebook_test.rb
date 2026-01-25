require "test_helper"

class NotebookTest < ActiveSupport::TestCase
  def setup
    FileUtils.mkdir_p(Notebook.workspace_dir)
    FileUtils.mkdir_p(Notebook.unsaved_dir)
    @created_files = []
  end

  def teardown
    @created_files.each { |p| FileUtils.rm_f(p) }
  end

  test "workspace_dir returns storage/notebooks path" do
    assert_equal Rails.root.join("storage", "notebooks"), Notebook.workspace_dir
  end

  test "autosave_dir returns storage/autosave path" do
    assert_equal Rails.root.join("storage", "autosave"), Notebook.autosave_dir
  end

  test "unsaved_dir returns storage/autosave/unsaved path" do
    assert_equal Rails.root.join("storage", "autosave", "unsaved"), Notebook.unsaved_dir
  end

  test "create_blank! writes a file and record" do
    notebook = Notebook.create_blank!
    @created_files << notebook.file_path

    assert notebook.persisted?, "notebook should be saved"
    assert_equal "runemd", notebook.format
    assert_equal false, notebook.dirty
    assert_match %r{storage/autosave/unsaved/untitled-\d{8}-\d{6}-[a-z0-9]{4}\.runemd\z}, notebook.file_path
    assert File.exist?(notebook.file_path), "backing file should exist"

    content = File.read(notebook.file_path)
    assert_includes content, "# #{notebook.title}", "file should start with notebook title"
    assert_includes content, "## Section", "file should include an initial section heading"
  end

  test "from_id_or_blank finds existing notebook when id present" do
    notebook = notebooks(:notebook_one)
    result = Notebook.from_id_or_blank(notebook.id)

    assert_equal notebook, result
  end

  test "from_id_or_blank creates blank notebook when id nil" do
    result = Notebook.from_id_or_blank(nil)
    @created_files << result.file_path

    assert result.persisted?
    assert_equal "Untitled notebook", result.title
  end

  test "from_id_or_blank creates blank notebook when id empty string" do
    result = Notebook.from_id_or_blank("")
    @created_files << result.file_path

    assert result.persisted?
    assert_equal "Untitled notebook", result.title
  end

  test "open_session returns open session when one exists" do
    notebook = notebooks(:notebook_two)
    open_session = sessions(:open_one)

    assert_equal open_session, notebook.open_session
  end

  test "open_session returns nil when no open session exists" do
    notebook = notebooks(:notebook_one)

    assert_nil notebook.open_session
  end

  test "find_or_start_session returns existing open session" do
    notebook = notebooks(:notebook_two)
    open_session = sessions(:open_one)

    result = notebook.find_or_start_session

    assert_equal open_session, result
    assert_no_difference "Session.count" do
      notebook.find_or_start_session
    end
  end

  test "find_or_start_session creates new session when none open" do
    notebook = notebooks(:notebook_one)

    assert_difference "Session.count", 1 do
      result = notebook.find_or_start_session

      assert result.persisted?
      assert_equal notebook, result.notebook
      assert_equal "open", result.status
      assert_not_nil result.started_at
    end
  end

  test "parsed_content returns parsed data when file exists" do
    notebook = Notebook.new(file_path: Rails.root.join("test/fixtures/files/hello_world.runemd").to_s)

    result = notebook.parsed_content

    assert_not_nil result
    assert_equal "Hello World!", result.title
  end

  test "parsed_content returns nil when file_path blank" do
    notebook = Notebook.new(file_path: nil)

    assert_nil notebook.parsed_content
  end

  test "parsed_content returns nil when file does not exist" do
    notebook = Notebook.new(file_path: "/nonexistent/path.runemd")

    assert_nil notebook.parsed_content
  end

  test "persisted_to_user_path? returns false for auto-generated paths" do
    notebook = Notebook.new(file_path: "/path/untitled-20240101-120000-abcd.runemd")

    assert_not notebook.persisted_to_user_path?
  end

  test "persisted_to_user_path? returns true for user-chosen paths" do
    notebook = Notebook.new(file_path: "/path/my_notebook.runemd")

    assert notebook.persisted_to_user_path?
  end

  test "persisted_to_user_path? returns false for blank path" do
    notebook = Notebook.new(file_path: nil)

    assert_not notebook.persisted_to_user_path?
  end

  test "create_from_content! creates notebook from runemd content" do
    content = File.read(Rails.root.join("test/fixtures/files/hello_world.runemd"))

    notebook = Notebook.create_from_content!(content)
    @created_files << notebook.file_path

    assert notebook.persisted?
    assert_equal "Hello World!", notebook.title
    assert_equal "runemd", notebook.format
    assert File.exist?(notebook.file_path)
  end

  test "find_or_create_from_path! returns existing notebook" do
    existing = notebooks(:notebook_one)

    result = Notebook.find_or_create_from_path!(existing.file_path)

    assert_equal existing, result
  end

  test "find_or_create_from_path! raises for non-existent file" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Notebook.find_or_create_from_path!("/nonexistent/file.runemd")
    end
  end

  test "file_path validation requires .runemd extension" do
    notebook = Notebook.new(title: "Test", format: "runemd", version: 1, file_path: "/path/file.txt")

    assert_not notebook.valid?
    assert_includes notebook.errors[:file_path], "must end with .runemd"
  end

  test "file_path validation allows .runemd extension" do
    notebook = Notebook.new(title: "Test", format: "runemd", version: 1, file_path: "/path/file.runemd")

    notebook.valid?
    assert_empty notebook.errors[:file_path]
  end
end
