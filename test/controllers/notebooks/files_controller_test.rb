require "test_helper"

module Notebooks
  class FilesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @test_workspace = Rails.root.join("tmp", "test_workspace_#{SecureRandom.hex(4)}")
      FileUtils.mkdir_p(@test_workspace)
      FileUtils.mkdir_p(@test_workspace.join("subdir"))
      File.write(@test_workspace.join("test.runemd"), "# Test")
    end

    teardown do
      FileUtils.rm_rf(@test_workspace) if @test_workspace&.exist?
    end

    test "GET /notebooks/files returns directory listing" do
      get files_path, params: { path: @test_workspace.to_s }
      assert_response :success

      json = JSON.parse(@response.body)
      assert json["ok"]
      assert_equal @test_workspace.to_s, json["current_path"]
      assert json["entries"].any? { |e| e["name"] == "subdir" && e["type"] == "directory" }
      assert json["entries"].any? { |e| e["name"] == "test.runemd" && e["type"] == "file" }
    end

    test "GET /notebooks/files returns error for non-existent directory" do
      get files_path, params: { path: "/nonexistent/path/that/doesnt/exist" }
      assert_response :not_found

      json = JSON.parse(@response.body)
      assert_not json["ok"]
      assert_equal "Directory not found", json["error"]
    end

    test "POST /notebooks/files creates a new notebook file with Notebook record" do
      assert_difference "Notebook.count", 1 do
        post files_path, params: {
          path: @test_workspace.to_s,
          name: "my_notebook"
        }
      end
      assert_response :success

      json = JSON.parse(@response.body)
      assert json["ok"]
      assert_equal "my_notebook.runemd", json["name"]
      assert @test_workspace.join("my_notebook.runemd").file?

      content = File.read(@test_workspace.join("my_notebook.runemd"))
      assert_includes content, "# my_notebook"
      assert_includes content, "## Section"
    end

    test "POST /notebooks/files with blank name returns error" do
      post files_path, params: {
        path: @test_workspace.to_s,
        name: ""
      }
      assert_response :bad_request

      json = JSON.parse(@response.body)
      assert_not json["ok"]
      assert_equal "Filename is required", json["error"]
    end

    test "POST /notebooks/files for existing file returns conflict" do
      post files_path, params: {
        path: @test_workspace.to_s,
        name: "test"
      }
      assert_response :conflict

      json = JSON.parse(@response.body)
      assert_not json["ok"]
      assert_equal "File already exists", json["error"]
    end

    test "POST /notebooks/files appends .runemd extension if missing" do
      post files_path, params: {
        path: @test_workspace.to_s,
        name: "without_extension"
      }
      assert_response :success

      json = JSON.parse(@response.body)
      assert_equal "without_extension.runemd", json["name"]
    end

    test "route helpers are available" do
      assert_equal "/notebooks/files", files_path
    end
  end
end
