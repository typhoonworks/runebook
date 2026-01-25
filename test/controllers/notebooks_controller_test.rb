require "test_helper"

class NotebooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @test_workspace = Rails.root.join("tmp", "test_workspace_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(@test_workspace)
    FileUtils.mkdir_p(@test_workspace.join("subdir"))
    File.write(@test_workspace.join("test.runemd"), "# Test")
  end

  teardown do
    FileUtils.rm_rf(@test_workspace) if @test_workspace&.exist?
  end

  test "GET /notebooks renders the index page" do
    get notebooks_path
    assert_response :success
    assert_includes @response.body, "Open"
  end

  test "PATCH /notebooks/:id updates title" do
    notebook = notebooks(:notebook_one)

    patch notebook_path(notebook), params: { notebook: { title: "After" } }
    assert_response :redirect
    assert_equal "After", notebook.reload.title
  end

  test "PATCH /notebooks/:id with invalid title returns error" do
    notebook = notebooks(:notebook_one)

    patch notebook_path(notebook), params: { notebook: { title: "" } }
    assert_response :redirect
  end

  test "notebooks route helpers are available" do
    assert_equal "/notebooks", notebooks_path
  end
end
