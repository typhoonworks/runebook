require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "POST /sessions creates a blank notebook and redirects" do
    assert_difference [ "Notebook.count", "Session.count" ], +1 do
      post sessions_path
    end
    assert_response :redirect

    session = Session.order(:created_at).last
    follow_redirect!
    assert_response :success
    assert_includes @response.body, session.notebook.title
  end

  test "POST /sessions with notebook_id opens existing notebook" do
    notebook = notebooks(:notebook_one)
    assert_no_difference "Notebook.count" do
      post sessions_path, params: { notebook_id: notebook.id }
    end
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes @response.body, notebook.title
  end

  test "GET /sessions/:token shows the session page" do
    s = sessions(:open_one)
    get session_path(s.token)
    assert_response :success
    assert_includes @response.body, s.notebook.title
    assert_includes @response.body, s.token
    assert_includes @response.body, 'data-controller="cells"'
    assert_includes @response.body, 'data-controller="markdown-cell"'
  end
end
