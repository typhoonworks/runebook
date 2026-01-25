require "test_helper"

module Notebooks
  class DirectoriesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @test_workspace = Rails.root.join("tmp", "test_workspace_#{SecureRandom.hex(4)}")
      FileUtils.mkdir_p(@test_workspace)
      FileUtils.mkdir_p(@test_workspace.join("subdir"))
    end

    teardown do
      FileUtils.rm_rf(@test_workspace) if @test_workspace&.exist?
    end

    test "POST /notebooks/directories creates a new directory" do
      post directories_path, params: {
        path: @test_workspace.to_s,
        name: "new_folder"
      }
      assert_response :success

      json = JSON.parse(@response.body)
      assert json["ok"]
      assert_equal "new_folder", json["name"]
      assert @test_workspace.join("new_folder").directory?
    end

    test "POST /notebooks/directories with blank name returns error" do
      post directories_path, params: {
        path: @test_workspace.to_s,
        name: ""
      }
      assert_response :bad_request

      json = JSON.parse(@response.body)
      assert_not json["ok"]
      assert_equal "Directory name is required", json["error"]
    end

    test "POST /notebooks/directories with invalid name returns error" do
      post directories_path, params: {
        path: @test_workspace.to_s,
        name: "../escape"
      }
      assert_response :bad_request

      json = JSON.parse(@response.body)
      assert_not json["ok"]
      assert_equal "Invalid directory name", json["error"]
    end

    test "POST /notebooks/directories for existing directory returns conflict" do
      post directories_path, params: {
        path: @test_workspace.to_s,
        name: "subdir"
      }
      assert_response :conflict

      json = JSON.parse(@response.body)
      assert_not json["ok"]
      assert_equal "Directory already exists", json["error"]
    end

    test "route helpers are available" do
      assert_equal "/notebooks/directories", directories_path
    end
  end
end
