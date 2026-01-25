require "test_helper"

module Notebooks
  class ImportsControllerTest < ActionDispatch::IntegrationTest
    test "POST /notebooks/imports creates document from valid content" do
      valid_content = <<~RUNEMD
        # Imported Notebook

        ```ruby
        gem "faker"
        ```

        ## Section

        ```ruby
        puts "Hello"
        ```
      RUNEMD

      assert_difference [ "Notebook.count", "Session.count" ], 1 do
        post imports_path, params: { content: valid_content }
      end

      assert_response :redirect
      follow_redirect!
      assert_response :success
    end

    test "POST /notebooks/imports with empty content redirects with error" do
      post imports_path, params: { content: "" }
      assert_response :redirect
      assert_redirected_to notebooks_path
    end

    test "POST /notebooks/imports with blank content returns error" do
      post imports_path, params: { content: "   " }
      assert_response :redirect
      assert_redirected_to notebooks_path
    end

    test "route helpers are available" do
      assert_equal "/notebooks/imports", imports_path
    end
  end
end
