require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "GET / lists notebooks and running sessions" do
    get root_path
    assert_response :success
    assert_includes @response.body, "Notebooks"
    assert_includes @response.body, notebooks(:notebook_one).title
    assert_includes @response.body, notebooks(:notebook_two).title

    assert_includes @response.body, "Running sessions"
    assert_includes @response.body, notebooks(:notebook_two).file_path
  end
end
