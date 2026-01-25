require "test_helper"

class MarkdownsControllerTest < ActionDispatch::IntegrationTest
  test "POST /markdown/preview renders markdown to html" do
    post markdown_preview_path, params: { text: "### Hello" }, as: :json
    assert_response :success
    assert_includes @response.body, "<h3>"
    assert_includes @response.content_type, "text/html"
  end

  test "POST /markdown/preview warns on h1/h2" do
    post markdown_preview_path, params: { text: "# Top" }, as: :json
    assert_response :success
    assert_includes @response.body, "heading levels 1 and 2 are reserved"
  end

  test "POST /markdown/preview sanitizes html" do
    post markdown_preview_path, params: { text: "<script>alert('x')</script>ok" }, as: :json
    assert_response :success
    # Ensure unsafe tags are stripped. CommonMark may treat
    # trailing text as part of the HTML block, so we only
    # assert that scripts are removed and response is valid.
    refute_includes @response.body, "<script"
  end
end
